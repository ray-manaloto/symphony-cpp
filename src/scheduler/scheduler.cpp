#include "symphony/scheduler/scheduler.hpp"

#include <algorithm>
#include <cctype>
#include <limits>
#include <stdexcept>

#include <fmt/format.h>

#include "symphony/workflow/workflow.hpp"

namespace symphony::scheduler {
namespace {
std::string normalized(std::string_view value) {
  const auto first = value.find_first_not_of(" \t\r\n");
  const auto last = value.find_last_not_of(" \t\r\n");
  if (first == std::string_view::npos) return {};
  std::string result{value.substr(first, last - first + 1)};
  std::ranges::transform(result, result.begin(), [](const unsigned char character) {
    return static_cast<char>(std::tolower(character));
  });
  return result;
}

bool config_active_state(const SchedulerConfig& config, const std::string_view state) {
  const auto target = normalized(state);
  return std::ranges::any_of(config.active_states,
                             [&](const auto& value) { return normalized(value) == target; });
}

bool config_terminal_state(const SchedulerConfig& config, const std::string_view state) {
  const auto target = normalized(state);
  return std::ranges::any_of(config.terminal_states,
                             [&](const auto& value) { return normalized(value) == target; });
}

bool config_routable(const SchedulerConfig& config, const domain::Issue& issue) {
  if (!issue.dispatchable) return false;
  return std::ranges::all_of(config.required_labels, [&](const auto& required) {
    const auto target = normalized(required);
    if (target.empty()) return false;
    return std::ranges::any_of(issue.labels,
                               [&](const auto& label) { return normalized(label) == target; });
  });
}

bool config_eligible(const SchedulerConfig& config, const domain::Issue& issue) {
  if (normalized(issue.id).empty() || normalized(issue.identifier).empty() ||
      normalized(issue.title).empty() || normalized(issue.state).empty()) {
    return false;
  }
  return config_active_state(config, issue.state) && !config_terminal_state(config, issue.state) &&
         config_routable(config, issue);
}

void saturating_add(std::uint64_t& total, const std::uint64_t value) {
  const auto maximum = std::numeric_limits<std::uint64_t>::max();
  total = value > maximum - total ? maximum : total + value;
}

std::uint64_t failure_signature(const std::string_view value) {
  std::uint64_t hash = 14695981039346656037ULL;
  for (const auto byte : value) {
    hash ^= static_cast<unsigned char>(byte);
    hash *= 1099511628211ULL;
  }
  return hash;
}

void record_failure(domain::Attempt& attempt, const std::string_view failure) {
  const auto signature = failure_signature(failure);
  if (attempt.last_failure_signature == signature) {
    if (attempt.repeated_failures < std::numeric_limits<std::uint32_t>::max()) {
      ++attempt.repeated_failures;
    }
  } else {
    attempt.last_failure_signature = signature;
    attempt.repeated_failures = 1;
  }
}

struct SelectedPolicy {
  std::optional<std::string> model;
  std::optional<std::string> reasoning_effort;
  std::string_view reason{"baseline"};
};

SelectedPolicy select_policy(const SchedulerConfig& config, const domain::Attempt& attempt) {
  SelectedPolicy selected{config.model, config.reasoning_effort, "baseline"};
  if (attempt.repeated_failures >= 2) {
    if (config.escalation_model) selected.model = config.escalation_model;
    if (config.repeated_failure_reasoning_effort) {
      selected.reasoning_effort = config.repeated_failure_reasoning_effort;
    } else if (config.escalation_reasoning_effort) {
      selected.reasoning_effort = config.escalation_reasoning_effort;
    }
    selected.reason = "repeated_failure";
  } else if (attempt.repeated_failures > 0) {
    if (config.escalation_model) selected.model = config.escalation_model;
    if (config.escalation_reasoning_effort) {
      selected.reasoning_effort = config.escalation_reasoning_effort;
    }
    selected.reason = "failure_retry";
  } else if (attempt.context_state == domain::ContextState::corrective_continuation) {
    if (config.escalation_model) selected.model = config.escalation_model;
    if (config.escalation_reasoning_effort) {
      selected.reasoning_effort = config.escalation_reasoning_effort;
    }
    selected.reason = "no_progress";
  }
  return selected;
}
} // namespace
Clock::time_point FakeClock::now() const {
  return now_;
}
void FakeClock::advance(const std::chrono::milliseconds delta) {
  now_ += delta;
}
Clock::time_point SystemClock::now() const {
  return std::chrono::steady_clock::now();
}

Scheduler::Scheduler(SchedulerConfig config, tracker::IssueTracker& tracker,
                     workspace::WorkspaceExecutor& workspaces, codex::AgentRuntime& runtime,
                     execution::WorkerExecutor& executor, observability::EventStore& events,
                     Clock& clock)
    : config_(std::move(config)), tracker_(tracker), workspaces_(workspaces), runtime_(runtime),
      executor_(executor), events_(events), clock_(clock) {
  if (config_.max_concurrent == 0) throw std::invalid_argument("max_concurrent must be positive");
  if (config_.max_concurrent > executor_.capacity()) {
    throw std::invalid_argument("max_concurrent exceeds worker executor capacity");
  }
  if (config_.max_turns == 0) throw std::invalid_argument("max_turns must be positive");
  if (config_.context_rollover_percent &&
      (*config_.context_rollover_percent == 0 || *config_.context_rollover_percent >= 100)) {
    throw std::invalid_argument("context_rollover_percent must be between 1 and 99");
  }
}

Scheduler::~Scheduler() {
  for (const auto& [issue_id, run] : runs_) {
    if (run.running) {
      static_cast<void>(executor_.request_stop(issue_id));
    }
  }
  executor_.wait();
  static_cast<void>(executor_.take_ready());
}

bool Scheduler::active_state(const std::string_view state) const {
  return config_active_state(config_, state);
}
bool Scheduler::terminal_state(const std::string_view state) const {
  return config_terminal_state(config_, state);
}

bool Scheduler::routable(const domain::Issue& issue) const {
  return config_routable(config_, issue);
}

bool Scheduler::eligible(const domain::Issue& issue) const {
  return config_eligible(config_, issue);
}

bool Scheduler::state_capacity(const domain::Issue& issue) const {
  const auto found = config_.max_concurrent_by_state.find(normalized(issue.state));
  if (found == config_.max_concurrent_by_state.end()) return true;
  const auto count = std::ranges::count_if(runs_, [&](const auto& entry) {
    return entry.second.running && normalized(entry.second.issue.state) == normalized(issue.state);
  });
  return static_cast<std::size_t>(count) < found->second;
}

std::size_t Scheduler::running_count() const {
  return static_cast<std::size_t>(
      std::ranges::count_if(runs_, [](const auto& entry) { return entry.second.running; }));
}

void Scheduler::tick(const std::string_view prompt_template) {
  drain_completions();
  reconcile();
  for (auto& [id, run] : runs_) {
    static_cast<void>(id);
    if (run.retry && run.retry->due_at <= clock_.now() &&
        run.attempt.context_state != domain::ContextState::stalled_no_progress) {
      if (running_count() >= config_.max_concurrent || !state_capacity(run.issue)) {
        queue_retry(run, run.retry->attempt, config_.retry_base,
                    std::string{"no available orchestrator slots"});
        events_.append({"retry_deferred",
                        run.issue.id,
                        run.issue.identifier,
                        {},
                        "no available orchestrator slots"});
        continue;
      }
      run.retry.reset();
      execute(run, prompt_template);
      drain_completions();
    }
  }
  if (running_count() >= config_.max_concurrent) return;
  std::vector<domain::Issue> candidates;
  {
    const std::scoped_lock lock(tracker_mutex_);
    candidates = tracker_.list_by_states(config_.active_states);
  }
  std::ranges::sort(candidates, [](const domain::Issue& left, const domain::Issue& right) {
    const auto priority_key = [](const std::optional<int> priority) {
      return priority && *priority >= 1 && *priority <= 4 ? *priority : 5;
    };
    if (priority_key(left.priority) != priority_key(right.priority)) {
      return priority_key(left.priority) < priority_key(right.priority);
    }
    if (left.created_at != right.created_at) {
      if (!left.created_at) return false;
      if (!right.created_at) return true;
      return *left.created_at < *right.created_at;
    }
    return left.identifier < right.identifier;
  });
  for (const auto& issue : candidates) {
    if (runs_.contains(issue.id) || !eligible(issue) || !state_capacity(issue)) continue;
    try {
      dispatch(issue, prompt_template);
    } catch (const std::exception& error) {
      events_.append({"dispatch_failed", issue.id, issue.identifier, {}, error.what()});
    }
    if (running_count() >= config_.max_concurrent) break;
  }
}

void Scheduler::dispatch(const domain::Issue& issue, const std::string_view prompt_template) {
  RunState run;
  run.issue = issue;
  run.workspace = workspaces_.create(issue);
  if (run.workspace.newly_created && config_.after_create_hook) {
    try {
      workspaces_.run_hook(run.workspace, "after_create",
                           {"bash", "-lc", *config_.after_create_hook}, config_.hook_timeout);
    } catch (...) {
      workspaces_.remove(run.workspace);
      throw;
    }
  }
  auto [position, inserted] = runs_.emplace(issue.id, std::move(run));
  if (!inserted) return;
  events_.append({"dispatch", issue.id, issue.identifier, {}, "fixture dispatch"});
  execute(position->second, prompt_template);
  drain_completions();
}

void Scheduler::execute(RunState& run, const std::string_view prompt_template) {
  const auto prompt = workflow::render_prompt(prompt_template, run.issue, run.attempt);
  run.running = true;
  if (config_.before_run_hook) {
    try {
      workspaces_.run_hook(run.workspace, "before_run", {"bash", "-lc", *config_.before_run_hook},
                           config_.hook_timeout);
    } catch (const std::exception& error) {
      execution::WorkerOutcome outcome;
      outcome.result.error = error.what();
      apply_completion(run, std::move(outcome));
      return;
    }
  }
  const auto policy = select_policy(config_, run.attempt);
  events_.append({"agent_policy_selected",
                  run.issue.id,
                  run.issue.identifier,
                  {},
                  "model=" + policy.model.value_or("default") +
                      " effort=" + policy.reasoning_effort.value_or("default") +
                      " reason=" + std::string{policy.reason}});

  codex::RunRequest request;
  request.issue = run.issue;
  request.attempt = run.attempt;
  request.workspace = run.workspace;
  request.prompt = prompt;
  request.max_turns = config_.max_turns;
  request.model = policy.model;
  request.reasoning_effort = policy.reasoning_effort;
  request.context_rollover_percent = config_.context_rollover_percent;
  const auto config_snapshot = config_;
  const auto issue_id = run.issue.id;

  try {
    executor_.submit(issue_id, [this, request = std::move(request),
                                config_snapshot](const std::stop_token stop_token) mutable {
      execution::WorkerOutcome outcome;
      outcome.after_run_hook = config_snapshot.after_run_hook;
      outcome.hook_timeout = config_snapshot.hook_timeout;
      auto latest_issue = request.issue;
      bool issue_refreshed = false;
      request.continuation_prompt_after_turn =
          [this, &latest_issue, &issue_refreshed,
           config_snapshot](const std::uint32_t completed_turns) -> std::optional<std::string> {
        std::optional<domain::Issue> refreshed;
        {
          const std::scoped_lock lock(tracker_mutex_);
          refreshed = tracker_.refresh_by_id(latest_issue.id);
        }
        if (!refreshed) return std::nullopt;
        latest_issue = *refreshed;
        issue_refreshed = true;
        if (!config_eligible(config_snapshot, latest_issue)) {
          return std::nullopt;
        }
        if (completed_turns >= config_snapshot.max_turns) {
          return std::nullopt;
        }
        const auto turn_number = completed_turns + 1;
        return "Continue working on issue " + latest_issue.identifier + ". This is turn " +
               std::to_string(turn_number) + " of " + std::to_string(config_snapshot.max_turns) +
               " in the current worker session. Re-read the current "
               "workspace and tracker state, continue toward "
               "completion, and run the relevant checks. Do not repeat "
               "the original task prompt.";
      };
      if (stop_token.stop_requested()) {
        outcome.result.cancelled = true;
        return outcome;
      }
      try {
        outcome.result = runtime_.run(request, stop_token);
      } catch (const std::exception& error) {
        outcome.result.error = error.what();
      }
      if (issue_refreshed) {
        outcome.refreshed_issue = std::move(latest_issue);
      }
      return outcome;
    });
  } catch (const std::exception& error) {
    execution::WorkerOutcome outcome;
    outcome.result.error = error.what();
    apply_completion(run, std::move(outcome));
  }
}

void Scheduler::drain_completions() {
  for (auto& completion : executor_.take_ready()) {
    const auto found = runs_.find(completion.key);
    if (found == runs_.end()) {
      events_.append({"worker_completion_discarded",
                      completion.key,
                      {},
                      completion.outcome.result.session_id,
                      "completion arrived after run removal"});
      continue;
    }
    apply_completion(found->second, std::move(completion.outcome));
    if (found->second.discard_after_stop) {
      if (found->second.remove_workspace_after_stop) {
        remove_workspace(found->second);
      }
      runs_.erase(found);
    }
  }
}

void Scheduler::apply_completion(RunState& run, execution::WorkerOutcome outcome) {
  auto& result = outcome.result;
  if (outcome.refreshed_issue) {
    run.issue = std::move(*outcome.refreshed_issue);
  }
  if (outcome.after_run_hook) {
    try {
      workspaces_.run_hook(run.workspace, "after_run", {"bash", "-lc", *outcome.after_run_hook},
                           outcome.hook_timeout);
    } catch (const std::exception& error) {
      events_.append(
          {"hook_failed", run.issue.id, run.issue.identifier, result.session_id, error.what()});
    }
  }
  run.session_id = result.session_id;
  if (result.turns_completed > 0) {
    events_.append({"worker_turns_completed", run.issue.id, run.issue.identifier, result.session_id,
                    "completed " + std::to_string(result.turns_completed) +
                        " Codex turn(s) in one live thread"});
  }
  if (result.process_diagnostic) {
    events_.append(
        {"worker_process_diagnostic", run.issue.id, run.issue.identifier, result.session_id,
         fmt::format("stderr_bytes={} truncated={} tail={}", result.process_diagnostic->bytes_seen,
                     result.process_diagnostic->truncated, result.process_diagnostic->text)});
  }
  if (result.token_usage) {
    saturating_add(codex_totals_.input_tokens, result.token_usage->input_tokens);
    saturating_add(codex_totals_.cached_input_tokens, result.token_usage->cached_input_tokens);
    saturating_add(codex_totals_.output_tokens, result.token_usage->output_tokens);
    saturating_add(codex_totals_.reasoning_output_tokens,
                   result.token_usage->reasoning_output_tokens);
    saturating_add(codex_totals_.total_tokens, result.token_usage->total_tokens);
    if (result.token_usage->model_context_window) {
      codex_totals_.model_context_window = result.token_usage->model_context_window;
    }
  }
  saturating_add(codex_compactions_, result.compaction_count);
  if (result.compaction_count > 0) {
    events_.append({"context_compacted", run.issue.id, run.issue.identifier, result.session_id,
                    "Codex compacted the active context"});
  }
  if (result.context_pressure_rollover) {
    events_.append(
        {"context_pressure_rollover", run.issue.id, run.issue.identifier, result.session_id,
         fmt::format("Codex context utilization reached the configured {}% rollover threshold",
                     config_.context_rollover_percent.value_or(0))});
  }
  if (result.rate_limits) {
    if (!latest_rate_limits_) latest_rate_limits_.emplace();
    codex::merge_rate_limits(*latest_rate_limits_, *result.rate_limits);
  }
  if (result.stalled) {
    events_.append({"stalled_session", run.issue.id, run.issue.identifier, result.session_id,
                    "Codex activity exceeded stall timeout"});
  }
  if (result.timed_out) {
    events_.append({"turn_timeout", run.issue.id, run.issue.identifier, result.session_id,
                    "Codex turn exceeded turn timeout"});
  }
  const auto still_running = !result.normal_exit && !result.cancelled && result.error.empty();
  if (still_running) return;
  run.running = false;
  bool schedule_retry = true;
  if (result.progress) {
    const auto decision =
        domain::observe_progress(run.attempt, domain::fingerprint(*result.progress));
    if (decision == domain::ProgressDecision::corrective_continuation) {
      events_.append({"corrective_continuation", run.issue.id, run.issue.identifier,
                      result.session_id, "unchanged progress fingerprint"});
    } else if (decision == domain::ProgressDecision::stalled_no_progress) {
      events_.append({"stalled_no_progress", run.issue.id, run.issue.identifier, result.session_id,
                      "second unchanged progress fingerprint"});
      schedule_retry = false;
    }
  }
  if (result.cancelled) {
    run.attempt.context_state = domain::ContextState::failed;
  }
  if (schedule_retry) {
    const auto clean_exit = result.normal_exit && !result.cancelled && result.error.empty();
    std::uint32_t retry_attempt = 1;
    auto delay = config_.retry_base;
    if (!clean_exit) {
      record_failure(run.attempt, result.error.empty() ? std::string_view{"cancelled"}
                                                       : std::string_view{result.error});
      retry_attempt = ++run.attempt.failure_retries;
      delay = domain::retry_delay(retry_attempt - 1, config_.failure_retry_base, config_.retry_cap);
    }
    queue_retry(run, retry_attempt, delay,
                result.error.empty() ? std::nullopt : std::optional<std::string>{result.error});
    ++run.attempt.number;
  } else {
    run.retry.reset();
  }
}

void Scheduler::queue_retry(RunState& run, const std::uint32_t attempt,
                            const std::chrono::milliseconds delay,
                            std::optional<std::string> error) {
  auto handle = next_timer_handle_++;
  if (handle == 0) handle = next_timer_handle_++;
  run.retry = RetryEntry{run.issue.id, run.issue.identifier, attempt, clock_.now() + delay,
                         handle,       std::move(error)};
}

void Scheduler::remove_workspace(RunState& run) {
  if (config_.before_remove_hook) {
    try {
      workspaces_.run_hook(run.workspace, "before_remove",
                           {"bash", "-lc", *config_.before_remove_hook}, config_.hook_timeout);
    } catch (const std::exception& error) {
      events_.append({"hook_failed", run.issue.id, run.issue.identifier, {}, error.what()});
    }
  }
  workspaces_.remove(run.workspace);
  events_.append({"terminal_cleanup", run.issue.id, run.issue.identifier, {}, "workspace removed"});
}

void Scheduler::reconcile() {
  for (auto iterator = runs_.begin(); iterator != runs_.end();) {
    std::optional<domain::Issue> refreshed;
    {
      const std::scoped_lock lock(tracker_mutex_);
      refreshed = tracker_.refresh_by_id(iterator->first);
    }
    if (!refreshed || terminal_state(refreshed->state) || !active_state(refreshed->state) ||
        !routable(*refreshed)) {
      const auto remove_after_stop = refreshed && terminal_state(refreshed->state);
      if (refreshed) iterator->second.issue = *refreshed;
      if (iterator->second.running && executor_.request_stop(iterator->first)) {
        iterator->second.discard_after_stop = true;
        iterator->second.remove_workspace_after_stop = remove_after_stop;
        ++iterator;
        continue;
      }
      if (remove_after_stop) remove_workspace(iterator->second);
      iterator = runs_.erase(iterator);
      continue;
    }
    iterator->second.issue = *refreshed;
    ++iterator;
  }
}

void Scheduler::startup_cleanup() {
  std::vector<domain::Issue> terminal_issues;
  {
    const std::scoped_lock lock(tracker_mutex_);
    terminal_issues = tracker_.list_by_states(config_.terminal_states);
  }
  for (const auto& issue : terminal_issues) {
    const auto workspace = workspaces_.find(issue);
    if (!workspace) continue;
    if (config_.before_remove_hook) {
      try {
        workspaces_.run_hook(*workspace, "before_remove",
                             {"bash", "-lc", *config_.before_remove_hook}, config_.hook_timeout);
      } catch (const std::exception& error) {
        events_.append({"hook_failed", issue.id, issue.identifier, {}, error.what()});
      }
    }
    workspaces_.remove(*workspace);
    events_.append(
        {"startup_terminal_cleanup", issue.id, issue.identifier, {}, "workspace removed"});
  }
}

const std::map<std::string, RunState>& Scheduler::runs() const noexcept {
  return runs_;
}

const codex::TokenUsage& Scheduler::codex_totals() const noexcept {
  return codex_totals_;
}

std::uint64_t Scheduler::codex_compactions() const noexcept {
  return codex_compactions_;
}

const std::optional<codex::RateLimits>& Scheduler::latest_rate_limits() const noexcept {
  return latest_rate_limits_;
}

void Scheduler::reconfigure(SchedulerConfig config) {
  if (config.max_concurrent == 0) throw std::invalid_argument("max_concurrent must be positive");
  if (config.max_concurrent > executor_.capacity()) {
    throw std::invalid_argument(
        "max_concurrent exceeds worker executor capacity; restart required");
  }
  if (config.max_turns == 0) throw std::invalid_argument("max_turns must be positive");
  if (config.context_rollover_percent &&
      (*config.context_rollover_percent == 0 || *config.context_rollover_percent >= 100)) {
    throw std::invalid_argument("context_rollover_percent must be between 1 and 99");
  }
  config_ = std::move(config);
}
} // namespace symphony::scheduler
