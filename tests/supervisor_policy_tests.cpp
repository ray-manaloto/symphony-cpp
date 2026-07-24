#include <cstdint>
#include <initializer_list>
#include <limits>
#include <optional>

#include <ut/ut.hpp>

#include "symphony/supervisor/policy.hpp"

namespace {

using symphony::codex::TokenUsage;
using symphony::supervisor::ContextBudgetAction;
using symphony::supervisor::ContextBudgetObservation;
using symphony::supervisor::ContextBudgetReason;
using symphony::supervisor::ContextBudgetState;
using symphony::supervisor::decide_context_budget;

TokenUsage usage(const std::uint64_t total, const std::int64_t window) {
  TokenUsage result;
  result.input_tokens = total;
  result.total_tokens = total;
  result.model_context_window = window;
  return result;
}

ContextBudgetObservation observed(const std::uint64_t total, const std::int64_t window) {
  return {
      .token_usage = usage(total, window),
      .completed_turns = 1,
  };
}

} // namespace

static ut::suite supervisor_policy_tests = [] {
  ut::test("context budget applies the 50 60 and 65 percent boundaries") = [] {
    const auto below = decide_context_budget({}, {}, observed(49, 100));
    const auto checkpoint = decide_context_budget({}, {}, observed(50, 100));
    const auto handoff = decide_context_budget({}, {}, observed(60, 100));
    const auto rollover = decide_context_budget({}, {}, observed(65, 100));

    ut::expect(below.action == ContextBudgetAction::continue_session);
    ut::expect(below.reason == ContextBudgetReason::below_checkpoint);
    ut::expect(checkpoint.action == ContextBudgetAction::checkpoint_then_continue);
    ut::expect(checkpoint.reason == ContextBudgetReason::checkpoint_threshold);
    ut::expect(handoff.action == ContextBudgetAction::finish_atomic_then_handoff);
    ut::expect(handoff.reason == ContextBudgetReason::handoff_threshold);
    ut::expect(rollover.action == ContextBudgetAction::rollover_fresh_session);
    ut::expect(rollover.reason == ContextBudgetReason::rollover_threshold);
  };

  ut::test("only latest input tokens measure context pressure") = [] {
    auto output_heavy = usage(1, 100);
    output_heavy.cached_input_tokens = 90;
    output_heavy.output_tokens = 90;
    output_heavy.reasoning_output_tokens = 90;
    output_heavy.total_tokens = 271;

    const auto decision =
        decide_context_budget({}, {}, {.token_usage = output_heavy, .completed_turns = 1});

    ut::expect(decision.action == ContextBudgetAction::continue_session);
    ut::expect(decision.reason == ContextBudgetReason::below_checkpoint);
  };

  ut::test("reported compaction always requests a fresh session") = [] {
    const auto decision = decide_context_budget({}, {},
                                                {
                                                    .token_usage = usage(1, 100),
                                                    .completed_turns = 1,
                                                    .compactions = 1,
                                                });

    ut::expect(decision.action == ContextBudgetAction::rollover_fresh_session);
    ut::expect(decision.reason == ContextBudgetReason::compaction_observed);
    ut::expect(decision.next_state.compactions == std::uint64_t{1});
  };

  ut::test("missing or invalid context windows pause fail closed") = [] {
    ContextBudgetObservation missing;
    missing.completed_turns = 1;
    TokenUsage absent_window;
    absent_window.total_tokens = 99;
    ContextBudgetObservation absent{
        .token_usage = absent_window,
        .completed_turns = 1,
    };

    const auto missing_decision = decide_context_budget({}, {}, missing);
    const auto absent_decision = decide_context_budget({}, {}, absent);
    const auto zero_decision = decide_context_budget({}, {}, observed(99, 0));
    const auto negative_decision = decide_context_budget({}, {}, observed(99, -1));

    for (const auto* decision :
         {&missing_decision, &absent_decision, &zero_decision, &negative_decision}) {
      ut::expect(decision->action == ContextBudgetAction::pause_needs_telemetry);
      ut::expect(decision->reason == ContextBudgetReason::telemetry_unavailable);
    }
  };

  ut::test("four completed turns force a fresh session") = [] {
    ContextBudgetState state;
    state.turns_in_session = 3;

    const auto decision = decide_context_budget({}, state, observed(1, 100));

    ut::expect(decision.next_state.turns_in_session == std::uint32_t{4});
    ut::expect(decision.next_state.total_turns == std::uint64_t{1});
    ut::expect(decision.action == ContextBudgetAction::rollover_fresh_session);
    ut::expect(decision.reason == ContextBudgetReason::turn_cap);
  };

  ut::test("context thresholds and counters cannot overflow") = [] {
    ContextBudgetState state;
    state.turns_in_session = std::numeric_limits<std::uint32_t>::max();
    state.total_turns = std::numeric_limits<std::uint64_t>::max();
    state.compactions = std::numeric_limits<std::uint64_t>::max();

    const auto decision =
        decide_context_budget({}, state,
                              {
                                  .token_usage = usage(std::numeric_limits<std::uint64_t>::max(),
                                                       std::numeric_limits<std::int64_t>::max()),
                                  .completed_turns = std::numeric_limits<std::uint32_t>::max(),
                                  .compactions = std::numeric_limits<std::uint32_t>::max(),
                              });

    ut::expect(decision.next_state.turns_in_session == std::numeric_limits<std::uint32_t>::max());
    ut::expect(decision.next_state.total_turns == std::numeric_limits<std::uint64_t>::max());
    ut::expect(decision.next_state.compactions == std::numeric_limits<std::uint64_t>::max());
    ut::expect(decision.action == ContextBudgetAction::rollover_fresh_session);
  };

  ut::test("context decisions preserve progress and failure evidence") = [] {
    ContextBudgetState state;
    state.evidence.last_progress = symphony::domain::ProgressFingerprint{"progress-v1"};
    state.evidence.last_failure_signature = std::uint64_t{42};
    state.evidence.unchanged_results = 2;
    state.evidence.consecutive_failures = 3;
    const auto expected = state.evidence;

    const auto decision = decide_context_budget({}, state,
                                                {
                                                    .token_usage = usage(1, 100),
                                                    .completed_turns = 1,
                                                    .compactions = 1,
                                                });

    ut::expect(decision.next_state.evidence == expected);
  };
};
