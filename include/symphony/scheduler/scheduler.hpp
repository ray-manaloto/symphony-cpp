#pragma once

#include <chrono>
#include <cstdint>
#include <map>
#include <optional>
#include <string>
#include <vector>

#include "symphony/codex/codex.hpp"
#include "symphony/domain/domain.hpp"
#include "symphony/observability/observability.hpp"
#include "symphony/tracker/tracker.hpp"
#include "symphony/workspace/workspace.hpp"

namespace symphony::scheduler {

class Clock {
 public:
  using time_point = std::chrono::steady_clock::time_point;
  virtual ~Clock() = default;
  [[nodiscard]] virtual time_point now() const = 0;
};

class FakeClock final : public Clock {
 public:
  [[nodiscard]] time_point now() const override;
  void advance(std::chrono::milliseconds delta);

 private:
  time_point now_{};
};

class SystemClock final : public Clock {
 public:
  [[nodiscard]] time_point now() const override;
};

struct SchedulerConfig {
  std::vector<std::string> active_states{"Todo", "In Progress"};
  std::vector<std::string> terminal_states{"Done", "Cancelled"};
  std::vector<std::string> required_labels;
  std::size_t max_concurrent{1};
  std::map<std::string, std::size_t> max_concurrent_by_state;
  std::chrono::milliseconds retry_base{1000};
  std::chrono::milliseconds failure_retry_base{10000};
  std::chrono::milliseconds retry_cap{300000};
  std::chrono::milliseconds hook_timeout{60000};
  std::optional<std::string> after_create_hook;
  std::optional<std::string> before_run_hook;
  std::optional<std::string> after_run_hook;
  std::optional<std::string> before_remove_hook;
};

struct RetryEntry {
  std::string issue_id;
  std::string identifier;
  std::uint32_t attempt{1};
  Clock::time_point due_at;
  std::uint64_t timer_handle{0};
  std::optional<std::string> error;
};

struct RunState {
  domain::Issue issue;
  domain::Attempt attempt;
  workspace::Workspace workspace;
  std::optional<RetryEntry> retry;
  std::string session_id;
  bool running{false};
};

class Scheduler {
 public:
  Scheduler(
      SchedulerConfig config,
      tracker::IssueTracker& tracker,
      workspace::WorkspaceExecutor& workspaces,
      codex::AgentRuntime& runtime,
      observability::EventStore& events,
      Clock& clock);

  void tick(std::string_view prompt_template);
  void reconcile();
  void startup_cleanup();
  void reconfigure(SchedulerConfig config);
  [[nodiscard]] const std::map<std::string, RunState>& runs() const noexcept;
  [[nodiscard]] const codex::TokenUsage& codex_totals() const noexcept;
  [[nodiscard]] const std::optional<codex::RateLimits>& latest_rate_limits() const noexcept;

 private:
  void dispatch(const domain::Issue& issue, std::string_view prompt_template);
  void execute(RunState& run, std::string_view prompt_template);
  void queue_retry(
      RunState& run,
      std::uint32_t attempt,
      std::chrono::milliseconds delay,
      std::optional<std::string> error);
  [[nodiscard]] bool active_state(std::string_view state) const;
  [[nodiscard]] bool terminal_state(std::string_view state) const;
  [[nodiscard]] bool routable(const domain::Issue& issue) const;
  [[nodiscard]] bool eligible(const domain::Issue& issue) const;
  [[nodiscard]] bool state_capacity(const domain::Issue& issue) const;
  [[nodiscard]] std::size_t running_count() const;

  SchedulerConfig config_;
  tracker::IssueTracker& tracker_;
  workspace::WorkspaceExecutor& workspaces_;
  codex::AgentRuntime& runtime_;
  observability::EventStore& events_;
  Clock& clock_;
  std::map<std::string, RunState> runs_;
  codex::TokenUsage codex_totals_;
  std::optional<codex::RateLimits> latest_rate_limits_;
  std::uint64_t next_timer_handle_{1};
};

}  // namespace symphony::scheduler
