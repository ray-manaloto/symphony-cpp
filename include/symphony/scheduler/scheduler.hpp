#pragma once

#include <chrono>
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

struct SchedulerConfig {
  std::vector<std::string> active_states{"Todo", "In Progress"};
  std::vector<std::string> terminal_states{"Done", "Cancelled"};
  std::size_t max_concurrent{1};
  std::chrono::milliseconds retry_base{1000};
  std::chrono::milliseconds retry_cap{300000};
};

struct RunState {
  domain::Issue issue;
  domain::Attempt attempt;
  workspace::Workspace workspace;
  std::optional<Clock::time_point> retry_at;
  std::string session_id;
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
  [[nodiscard]] const std::map<std::string, RunState>& runs() const noexcept;

 private:
  void dispatch(const domain::Issue& issue, std::string_view prompt_template);
  void execute(RunState& run, std::string_view prompt_template);
  [[nodiscard]] bool active_state(std::string_view state) const;
  [[nodiscard]] bool terminal_state(std::string_view state) const;

  SchedulerConfig config_;
  tracker::IssueTracker& tracker_;
  workspace::WorkspaceExecutor& workspaces_;
  codex::AgentRuntime& runtime_;
  observability::EventStore& events_;
  Clock& clock_;
  std::map<std::string, RunState> runs_;
};

}  // namespace symphony::scheduler

