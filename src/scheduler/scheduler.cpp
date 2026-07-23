#include "symphony/scheduler/scheduler.hpp"

#include <algorithm>
#include <cctype>
#include <limits>
#include <stdexcept>

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

void saturating_add(std::uint64_t& total, const std::uint64_t value) {
  const auto maximum = std::numeric_limits<std::uint64_t>::max();
  total = value > maximum - total ? maximum : total + value;
}
}  // namespace
Clock::time_point FakeClock::now() const { return now_; }
void FakeClock::advance(const std::chrono::milliseconds delta) { now_ += delta; }
Clock::time_point SystemClock::now() const { return std::chrono::steady_clock::now(); }

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
  if (config_.max_turns == 0) throw std::invalid_argument("max_turns must be positive");
}

bool Scheduler::active_state(const std::string_view state) const {
  const auto target = normalized(state);
  return std::ranges::any_of(config_.active_states, [&](const auto& value) { return normalized(value) == target; });
}
bool Scheduler::terminal_state(const std::string_view state) const {
  const auto target = normalized(state);
  return std::ranges::any_of(config_.terminal_states, [&](const auto& value) { return normalized(value) == target; });
}

bool Scheduler::routable(const domain::Issue& issue) const {
  if (!issue.dispatchable) return false;
  return std::ranges::all_of(config_.required_labels, [&](const auto& required) {
    const auto target = normalized(required);
    if (target.empty()) return false;
    return std::ranges::any_of(issue.labels, [&](const auto& label) { return normalized(label) == target; });
  });
}

bool Scheduler::eligible(const domain::Issue& issue) const {
  if (normalized(issue.id).empty() || normalized(issue.identifier).empty() ||
      normalized(issue.title).empty() || normalized(issue.state).empty()) {
    return false;
  }
  return active_state(issue.state) && !terminal_state(issue.state) && routable(issue);
}

bool Scheduler::state_capacity(const domain::Issue& issue) const {
  const auto found = config_.max_concurrent_by_state.find(normalized(issue.state));
  if (found == config_.max_concurrent_by_state.end()) return true;
  const auto count = std::ranges::count_if(runs_, [&](const auto& entry) {
    return entry.second.running &&
           normalized(entry.second.issue.state) == normalized(issue.state);
  });
  return static_cast<std::size_t>(count) < found->second;
}

std::size_t Scheduler::running_count() const {
  return static_cast<std::size_t>(std::ranges::count_if(
      runs_, [](const auto& entry) { return entry.second.running; }));
}

void Scheduler::tick(const std::string_view prompt_template) {
  reconcile();
  for (auto& [id, run] : runs_) {
    static_cast<void>(id);
    if (run.retry && run.retry->due_at <= clock_.now() &&
        run.attempt.context_state != domain::ContextState::stalled_no_progress) {
      if (running_count() >= config_.max_concurrent || !state_capacity(run.issue)) {
        queue_retry(
            run,
            run.retry->attempt,
            config_.retry_base,
            std::string{"no available orchestrator slots"});
        events_.append({"retry_deferred", run.issue.id, run.issue.identifier, {},
                        "no available orchestrator slots"});
        continue;
      }
      run.retry.reset();
      execute(run, prompt_template);
    }
  }
  if (running_count() >= config_.max_concurrent) return;
  auto candidates = tracker_.list_by_states(config_.active_states);
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
      workspaces_.run_hook(
          run.workspace, "after_create", {"bash", "-lc", *config_.after_create_hook}, config_.hook_timeout);
    } catch (...) {
      workspaces_.remove(run.workspace);
      throw;
    }
  }
  auto [position, inserted] = runs_.emplace(issue.id, std::move(run));
  if (!inserted) return;
  events_.append({"dispatch", issue.id, issue.identifier, {}, "fixture dispatch"});
  execute(position->second, prompt_template);
}

void Scheduler::execute(RunState& run, const std::string_view prompt_template) {
  const auto prompt = workflow::render_prompt(prompt_template, run.issue, run.attempt);
  run.running = true;
  codex::RunResult result;
  try {
    if (config_.before_run_hook) {
      workspaces_.run_hook(
          run.workspace, "before_run", {"bash", "-lc", *config_.before_run_hook}, config_.hook_timeout);
    }
    codex::RunRequest request;
    request.issue = run.issue;
    request.attempt = run.attempt;
    request.workspace = run.workspace;
    request.prompt = prompt;
    request.max_turns = config_.max_turns;
    request.continuation_prompt_after_turn =
        [this, &run](const std::uint32_t completed_turns)
        -> std::optional<std::string> {
          const auto refreshed = tracker_.refresh_by_id(run.issue.id);
          if (!refreshed || !eligible(*refreshed)) return std::nullopt;
          run.issue = *refreshed;
          if (completed_turns >= config_.max_turns) return std::nullopt;
          const auto turn_number = completed_turns + 1;
          return "Continue working on issue " + run.issue.identifier +
                 ". This is turn " + std::to_string(turn_number) + " of " +
                 std::to_string(config_.max_turns) +
                 " in the current worker session. Re-read the current workspace "
                 "and tracker state, continue toward completion, and run the "
                 "relevant checks. Do not repeat the original task prompt.";
        };
    result = runtime_.run(request);
  } catch (const std::exception& error) {
    result.error = error.what();
  }
  if (config_.after_run_hook) {
    try {
      workspaces_.run_hook(
          run.workspace, "after_run", {"bash", "-lc", *config_.after_run_hook}, config_.hook_timeout);
    } catch (const std::exception& error) {
      events_.append({"hook_failed", run.issue.id, run.issue.identifier, result.session_id, error.what()});
    }
  }
  run.session_id = result.session_id;
  if (result.turns_completed > 0) {
    events_.append({
        "worker_turns_completed", run.issue.id, run.issue.identifier,
        result.session_id,
        "completed " + std::to_string(result.turns_completed) +
            " Codex turn(s) in one live thread"});
  }
  if (result.token_usage) {
    saturating_add(codex_totals_.input_tokens, result.token_usage->input_tokens);
    saturating_add(
        codex_totals_.cached_input_tokens,
        result.token_usage->cached_input_tokens);
    saturating_add(codex_totals_.output_tokens, result.token_usage->output_tokens);
    saturating_add(
        codex_totals_.reasoning_output_tokens,
        result.token_usage->reasoning_output_tokens);
    saturating_add(codex_totals_.total_tokens, result.token_usage->total_tokens);
    if (result.token_usage->model_context_window) {
      codex_totals_.model_context_window =
          result.token_usage->model_context_window;
    }
  }
  saturating_add(codex_compactions_, result.compaction_count);
  if (result.compaction_count > 0) {
    events_.append({
        "context_compacted",
        run.issue.id,
        run.issue.identifier,
        result.session_id,
        "Codex compacted the active context"});
  }
  if (result.rate_limits) {
    if (!latest_rate_limits_) latest_rate_limits_.emplace();
    codex::merge_rate_limits(*latest_rate_limits_, *result.rate_limits);
  }
  if (result.stalled) {
    events_.append({"stalled_session", run.issue.id, run.issue.identifier,
                    result.session_id, "Codex activity exceeded stall timeout"});
  }
  if (result.timed_out) {
    events_.append({"turn_timeout", run.issue.id, run.issue.identifier,
                    result.session_id, "Codex turn exceeded turn timeout"});
  }
  const auto still_running = !result.normal_exit && !result.cancelled &&
                             result.error.empty();
  if (still_running) return;
  run.running = false;
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
    const auto clean_exit = result.normal_exit && !result.cancelled && result.error.empty();
    std::uint32_t retry_attempt = 1;
    auto delay = config_.retry_base;
    if (!clean_exit) {
      retry_attempt = ++run.attempt.failure_retries;
      delay = domain::retry_delay(
          retry_attempt - 1,
          config_.failure_retry_base,
          config_.retry_cap);
    }
    queue_retry(
        run,
        retry_attempt,
        delay,
        result.error.empty() ? std::nullopt
                             : std::optional<std::string>{result.error});
    ++run.attempt.number;
  } else {
    run.retry.reset();
  }
}

void Scheduler::queue_retry(
    RunState& run,
    const std::uint32_t attempt,
    const std::chrono::milliseconds delay,
    std::optional<std::string> error) {
  auto handle = next_timer_handle_++;
  if (handle == 0) handle = next_timer_handle_++;
  run.retry = RetryEntry{
      run.issue.id,
      run.issue.identifier,
      attempt,
      clock_.now() + delay,
      handle,
      std::move(error)};
}

void Scheduler::reconcile() {
  for (auto iterator = runs_.begin(); iterator != runs_.end();) {
    const auto refreshed = tracker_.refresh_by_id(iterator->first);
    if (!refreshed || terminal_state(refreshed->state) ||
        !active_state(refreshed->state) || !routable(*refreshed)) {
      if (iterator->second.running && !iterator->second.session_id.empty()) {
        runtime_.cancel(iterator->second.session_id);
      }
      if (refreshed && terminal_state(refreshed->state)) {
        if (config_.before_remove_hook) {
          try {
            workspaces_.run_hook(
                iterator->second.workspace,
                "before_remove",
                {"bash", "-lc", *config_.before_remove_hook},
                config_.hook_timeout);
          } catch (const std::exception& error) {
            events_.append({"hook_failed", refreshed->id, refreshed->identifier, {}, error.what()});
          }
        }
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

void Scheduler::startup_cleanup() {
  for (const auto& issue : tracker_.list_by_states(config_.terminal_states)) {
    const auto workspace = workspaces_.find(issue);
    if (!workspace) continue;
    if (config_.before_remove_hook) {
      try {
        workspaces_.run_hook(
            *workspace,
            "before_remove",
            {"bash", "-lc", *config_.before_remove_hook},
            config_.hook_timeout);
      } catch (const std::exception& error) {
        events_.append({"hook_failed", issue.id, issue.identifier, {}, error.what()});
      }
    }
    workspaces_.remove(*workspace);
    events_.append({"startup_terminal_cleanup", issue.id, issue.identifier, {}, "workspace removed"});
  }
}

const std::map<std::string, RunState>& Scheduler::runs() const noexcept { return runs_; }

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
  if (config.max_turns == 0) throw std::invalid_argument("max_turns must be positive");
  config_ = std::move(config);
}
}  // namespace symphony::scheduler
