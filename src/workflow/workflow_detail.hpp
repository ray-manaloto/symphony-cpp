#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

#include <glaze/json/generic.hpp>

namespace symphony::workflow::detail {

struct RawPolling {
  std::optional<std::uint64_t> interval_ms;
};

struct RawWorkspace {
  std::optional<std::string> root;
};

struct RawAgent {
  std::optional<std::uint64_t> max_concurrent_agents;
  std::optional<std::uint64_t> max_turns;
  std::optional<std::uint64_t> max_retry_backoff_ms;
  std::optional<glz::generic_u64> max_concurrent_agents_by_state;
};

struct RawHooks {
  std::optional<std::uint64_t> timeout_ms;
  std::optional<std::string> after_create;
  std::optional<std::string> before_run;
  std::optional<std::string> after_run;
  std::optional<std::string> before_remove;
};

struct RawCodex {
  std::optional<std::string> command;
  std::optional<std::string> model;
  std::optional<std::string> reasoning_effort;
  std::optional<std::string> escalation_model;
  std::optional<std::string> escalation_reasoning_effort;
  std::optional<std::string> repeated_failure_reasoning_effort;
  std::optional<std::uint64_t> context_rollover_percent;
  std::optional<std::string> approval_policy;
  std::optional<std::string> thread_sandbox;
  std::optional<std::string> turn_sandbox_policy;
  std::optional<std::uint64_t> turn_timeout_ms;
  std::optional<std::uint64_t> read_timeout_ms;
  std::optional<std::int64_t> stall_timeout_ms;
};

struct RawTracker {
  std::optional<std::string> kind;
  std::optional<glz::generic_u64> provider;
  std::optional<std::vector<std::string>> required_labels;
  std::optional<std::vector<std::string>> active_states;
  std::optional<std::vector<std::string>> terminal_states;
};

struct RawWorkflow {
  std::optional<RawTracker> tracker;
  std::optional<RawPolling> polling;
  std::optional<RawWorkspace> workspace;
  std::optional<RawAgent> agent;
  std::optional<RawHooks> hooks;
  std::optional<RawCodex> codex;
};

} // namespace symphony::workflow::detail
