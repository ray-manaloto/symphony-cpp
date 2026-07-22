#include "symphony/scheduler/scheduler.hpp"

#include <algorithm>
#include <stdexcept>

#include "symphony/workflow/workflow.hpp"

namespace symphony::scheduler {
Clock::time_point FakeClock::now() const { return now_; }
void FakeClock::advance(const std::chrono::milliseconds delta) { now_ += delta; }

Scheduler::Scheduler(
    SchedulerConfig config,
    tracker::IssueTracker& tracker,
    workspace::WorkspaceExecutor& workspaces,
    codex::AgentRuntime& runtime,
    observability::EventStore& events,
    Clock& clock)
    : config_(std::move(config)),
      tracker_(tracker),
      workspaces_(workspaces),
      runtime_(runtime),
      events_(events),
      clock_(clock) {
  if (config_.max_concurrent == 0) throw std::invalid_argument("max_concurrent must be positive");
}

bool Scheduler::active_state(const std::string_view state) const {
  return std::ranges::find(config_.active_states, state) != config_.active_states.end();
}
bool Scheduler::terminal_state(const std::string_view state) const {
  return std::ranges::find(config_.terminal_states, state) != config_.terminal_states.end();
}

void Scheduler::tick(const std::string_view prompt_template) {
  reconcile();
  for (auto& [id, run] : runs_) {
    static_cast<void>(id);
    if (run.retry_at && *run.retry_at <= clock_.now() &&
        run.attempt.context_state != domain::ContextState::stalled_no_progress) {
      run.retry_at.reset();
      execute(run, prompt_template);
    }
  }
  if (runs_.size() >= config_.max_concurrent) return;
  for (const auto& issue : tracker_.list_by_states(config_.active_states)) {
    if (runs_.contains(issue.id)) continue;
    dispatch(issue, prompt_template);
    if (runs_.size() >= config_.max_concurrent) break;
  }
}

void Scheduler::dispatch(const domain::Issue& issue, const std::string_view prompt_template) {
  RunState run;
  run.issue = issue;
  run.workspace = workspaces_.create(issue);
  auto [position, inserted] = runs_.emplace(issue.id, std::move(run));
  if (!inserted) return;
  events_.append({"dispatch", issue.id, issue.identifier, {}, "fixture dispatch"});
  execute(position->second, prompt_template);
}

void Scheduler::execute(RunState& run, const std::string_view prompt_template) {
  const auto prompt = workflow::render_prompt(prompt_template, run.issue, run.attempt);
  const auto result = runtime_.run({run.issue, run.attempt, run.workspace, prompt});
  run.session_id = result.session_id;
  bool schedule_retry = true;
  if (result.progress) {
    const auto decision = domain::observe_progress(run.attempt, domain::fingerprint(*result.progress));
    if (decision == domain::ProgressDecision::corrective_continuation) {
      events_.append({"corrective_continuation", run.issue.id, run.issue.identifier,
                      result.session_id, "unchanged progress fingerprint"});
    } else if (decision == domain::ProgressDecision::stalled_no_progress) {
      events_.append({"stalled_no_progress", run.issue.id, run.issue.identifier,
                      result.session_id, "second unchanged progress fingerprint"});
      schedule_retry = false;
    }
  }
  if (result.cancelled) {
    run.attempt.context_state = domain::ContextState::failed;
  }
  if (schedule_retry) {
    const auto ordinal = run.attempt.number - 1;
    run.retry_at = clock_.now() + domain::retry_delay(ordinal, config_.retry_base, config_.retry_cap);
    ++run.attempt.number;
  } else {
    run.retry_at.reset();
  }
}

void Scheduler::reconcile() {
  for (auto iterator = runs_.begin(); iterator != runs_.end();) {
    const auto refreshed = tracker_.refresh_by_id(iterator->first);
    if (!refreshed || !active_state(refreshed->state)) {
      if (!iterator->second.session_id.empty()) runtime_.cancel(iterator->second.session_id);
      if (refreshed && terminal_state(refreshed->state)) {
        workspaces_.remove(iterator->second.workspace);
        events_.append({"terminal_cleanup", refreshed->id, refreshed->identifier, {}, "workspace removed"});
      }
      iterator = runs_.erase(iterator);
      continue;
    }
    iterator->second.issue = *refreshed;
    ++iterator;
  }
}

const std::map<std::string, RunState>& Scheduler::runs() const noexcept { return runs_; }
}  // namespace symphony::scheduler
