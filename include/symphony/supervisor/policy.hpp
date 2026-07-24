#pragma once

#include <cstdint>
#include <optional>

#include "symphony/codex/codex.hpp"
#include "symphony/domain/domain.hpp"

namespace symphony::supervisor {

struct ContextBudgetConfig {
  std::uint32_t checkpoint_percent{50};
  std::uint32_t handoff_percent{60};
  std::uint32_t rollover_percent{65};
  std::uint32_t max_turns{4};
};

struct ProgressFailureEvidence {
  std::optional<domain::ProgressFingerprint> last_progress;
  std::optional<std::uint64_t> last_failure_signature;
  std::uint32_t unchanged_results{0};
  std::uint32_t consecutive_failures{0};

  friend bool operator==(const ProgressFailureEvidence&, const ProgressFailureEvidence&) = default;
};

struct ContextBudgetState {
  std::uint32_t turns_in_session{0};
  std::uint64_t total_turns{0};
  std::uint64_t compactions{0};
  ProgressFailureEvidence evidence;

  friend bool operator==(const ContextBudgetState&, const ContextBudgetState&) = default;
};

struct ContextBudgetObservation {
  std::optional<codex::TokenUsage> token_usage;
  std::uint32_t completed_turns{0};
  std::uint32_t compactions{0};
};

enum class ContextBudgetAction {
  continue_session,
  checkpoint_then_continue,
  finish_atomic_then_handoff,
  rollover_fresh_session,
  pause_needs_telemetry,
};

enum class ContextBudgetReason {
  below_checkpoint,
  checkpoint_threshold,
  handoff_threshold,
  rollover_threshold,
  compaction_observed,
  turn_cap,
  telemetry_unavailable,
};

struct ContextBudgetDecision {
  ContextBudgetAction action{ContextBudgetAction::continue_session};
  ContextBudgetReason reason{ContextBudgetReason::below_checkpoint};
  ContextBudgetState next_state;
};

[[nodiscard]] ContextBudgetDecision
decide_context_budget(const ContextBudgetConfig& config, const ContextBudgetState& current,
                      const ContextBudgetObservation& observation);

} // namespace symphony::supervisor
