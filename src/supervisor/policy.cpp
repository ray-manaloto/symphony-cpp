#include "symphony/supervisor/policy.hpp"

#include <limits>
#include <stdexcept>
#include <utility>

namespace symphony::supervisor {
namespace {

template <typename Result, typename Increment>
void saturating_add(Result& result, const Increment increment) noexcept {
  const auto maximum = std::numeric_limits<Result>::max();
  const auto value = static_cast<Result>(increment);
  result = value > maximum - result ? maximum : result + value;
}

void validate(const ContextBudgetConfig& config) {
  if (config.max_turns == 0) {
    throw std::invalid_argument("supervisor max_turns must be positive");
  }
  if (config.checkpoint_percent == 0 || config.checkpoint_percent >= config.handoff_percent ||
      config.handoff_percent >= config.rollover_percent || config.rollover_percent >= 100) {
    throw std::invalid_argument("supervisor context thresholds must satisfy "
                                "0 < checkpoint < handoff < rollover < 100");
  }
}

bool threshold_reached(const codex::TokenUsage& usage, const std::uint32_t percent) noexcept {
  if (!usage.model_context_window || *usage.model_context_window <= 0 || !usage.last_input_tokens) {
    return false;
  }

  const auto window = static_cast<std::uint64_t>(*usage.model_context_window);
  const auto whole = (window / 100U) * percent;
  const auto remainder = ((window % 100U) * percent + 99U) / 100U;
  return *usage.last_input_tokens >= whole + remainder;
}

bool usable_telemetry(const codex::TokenUsage& usage) noexcept {
  return usage.model_context_window && *usage.model_context_window > 0 &&
         usage.last_input_tokens.has_value();
}

} // namespace

ContextBudgetDecision decide_context_budget(const ContextBudgetConfig& config,
                                            const ContextBudgetState& current,
                                            const ContextBudgetObservation& observation) {
  validate(config);

  auto next = current;
  saturating_add(next.turns_in_session, observation.completed_turns);
  saturating_add(next.total_turns, observation.completed_turns);
  saturating_add(next.compactions, observation.compactions);

  const auto decision = [&](const ContextBudgetAction action, const ContextBudgetReason reason) {
    return ContextBudgetDecision{
        .action = action,
        .reason = reason,
        .next_state = std::move(next),
    };
  };

  if (observation.compactions > 0) {
    return decision(ContextBudgetAction::rollover_fresh_session,
                    ContextBudgetReason::compaction_observed);
  }
  if (next.turns_in_session >= config.max_turns) {
    return decision(ContextBudgetAction::rollover_fresh_session, ContextBudgetReason::turn_cap);
  }
  if (!observation.token_usage || !usable_telemetry(*observation.token_usage)) {
    return decision(ContextBudgetAction::pause_needs_telemetry,
                    ContextBudgetReason::telemetry_unavailable);
  }
  if (threshold_reached(*observation.token_usage, config.rollover_percent)) {
    return decision(ContextBudgetAction::rollover_fresh_session,
                    ContextBudgetReason::rollover_threshold);
  }
  if (threshold_reached(*observation.token_usage, config.handoff_percent)) {
    return decision(ContextBudgetAction::finish_atomic_then_handoff,
                    ContextBudgetReason::handoff_threshold);
  }
  if (threshold_reached(*observation.token_usage, config.checkpoint_percent)) {
    return decision(ContextBudgetAction::checkpoint_then_continue,
                    ContextBudgetReason::checkpoint_threshold);
  }
  return decision(ContextBudgetAction::continue_session, ContextBudgetReason::below_checkpoint);
}

} // namespace symphony::supervisor
