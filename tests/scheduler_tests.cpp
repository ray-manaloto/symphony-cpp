#include <algorithm>
#include <atomic>
#include <chrono>
#include <filesystem>
#include <optional>
#include <stop_token>
#include <thread>
#include <utility>

#include <ut/ut.hpp>

#include "symphony/execution/execution.hpp"
#include "symphony/scheduler/scheduler.hpp"

using symphony::codex::RunResult;
using symphony::domain::ProgressSnapshot;

namespace {
bool wait_until(const std::atomic<std::size_t>& value, const std::size_t expected,
                const std::chrono::steady_clock::duration timeout) {
  const auto deadline = std::chrono::steady_clock::now() + timeout;
  while (value.load() < expected && std::chrono::steady_clock::now() < deadline) {
    std::this_thread::sleep_for(std::chrono::milliseconds{1});
  }
  return value.load() >= expected;
}

class FixtureExecutorOwner {
protected:
  symphony::execution::InlineWorkerExecutor executor;
};

class FixtureScheduler final : private FixtureExecutorOwner, public symphony::scheduler::Scheduler {
public:
  FixtureScheduler(symphony::scheduler::SchedulerConfig config,
                   symphony::tracker::IssueTracker& tracker,
                   symphony::workspace::WorkspaceExecutor& workspaces,
                   symphony::codex::AgentRuntime& runtime,
                   symphony::observability::EventStore& events, symphony::scheduler::Clock& clock)
      : FixtureExecutorOwner(),
        symphony::scheduler::Scheduler(std::move(config), tracker, workspaces, runtime, executor,
                                       events, clock) {}
};
} // namespace

static ut::suite scheduler_tests = [] {
  ut::test("scheduler overlaps workers and drains completion on its own thread") = [] {
    class OverlapRuntime final : public symphony::codex::AgentRuntime {
    public:
      symphony::codex::RunResult run(const symphony::codex::RunRequest&, std::stop_token) override {
        const auto active_now = active.fetch_add(1) + 1;
        auto observed = maximum_active.load();
        while (observed < active_now &&
               !maximum_active.compare_exchange_weak(observed, active_now)) {
        }
        entered.fetch_add(1);
        while (!release.load()) {
          release.wait(false);
        }
        active.fetch_sub(1);
        completed.fetch_add(1);
        while (!allow_return.load()) {
          allow_return.wait(false);
        }
        return {true, false, std::nullopt, "completed", {}};
      }

      std::atomic<std::size_t> active{0};
      std::atomic<std::size_t> maximum_active{0};
      std::atomic<std::size_t> entered{0};
      std::atomic<std::size_t> completed{0};
      std::atomic<bool> release{false};
      std::atomic<bool> allow_return{false};
    };

    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "First", "Todo", {}});
    tracker.upsert({"2", "SYM-2", "Second", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-concurrent-workers-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    OverlapRuntime runtime;
    symphony::execution::StdexecWorkerExecutor executor(2);
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.max_concurrent = 2;
    symphony::scheduler::Scheduler scheduler(config, tracker, workspaces, runtime, executor, events,
                                             clock);

    scheduler.tick("{{ issue.identifier }}");
    const auto entered = wait_until(runtime.entered, 2, std::chrono::seconds{2});
    runtime.release.store(true);
    runtime.release.notify_all();
    const auto completed = wait_until(runtime.completed, 2, std::chrono::seconds{2});

    ut::expect(entered);
    ut::expect(completed);
    ut::expect(runtime.maximum_active.load() == std::size_t{2});
    ut::expect(scheduler.runs().at("1").running);
    ut::expect(scheduler.runs().at("2").running);

    scheduler.tick("{{ issue.identifier }}");

    ut::expect(scheduler.runs().at("1").running);
    ut::expect(scheduler.runs().at("2").running);

    runtime.allow_return.store(true);
    runtime.allow_return.notify_all();
    const auto completion_deadline = std::chrono::steady_clock::now() + std::chrono::seconds{2};
    while ((scheduler.runs().at("1").running || scheduler.runs().at("2").running ||
            !scheduler.runs().at("1").retry || !scheduler.runs().at("2").retry) &&
           std::chrono::steady_clock::now() < completion_deadline) {
      scheduler.tick("{{ issue.identifier }}");
      std::this_thread::sleep_for(std::chrono::milliseconds{1});
    }

    ut::expect(!scheduler.runs().at("1").running);
    ut::expect(!scheduler.runs().at("2").running);
    ut::expect(scheduler.runs().at("1").retry.has_value());
    ut::expect(scheduler.runs().at("2").retry.has_value());
    std::filesystem::remove_all(root);
  };

  ut::test("terminal reconciliation stops worker before removing workspace") = [] {
    class StoppableRuntime final : public symphony::codex::AgentRuntime {
    public:
      symphony::codex::RunResult run(const symphony::codex::RunRequest&,
                                     const std::stop_token stop_token) override {
        entered.fetch_add(1);
        while (!stop_token.stop_requested()) {
          std::this_thread::sleep_for(std::chrono::milliseconds{1});
        }
        stopped.fetch_add(1);
        return {false, true, std::nullopt, "cancelled", {}};
      }

      std::atomic<std::size_t> entered{0};
      std::atomic<std::size_t> stopped{0};
    };

    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Stop", "Todo", {}});
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-concurrent-cancellation-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    StoppableRuntime runtime;
    symphony::execution::StdexecWorkerExecutor executor(1);
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime, executor, events,
                                             clock);

    scheduler.tick("{{ issue.identifier }}");
    const auto entered = wait_until(runtime.entered, 1, std::chrono::seconds{2});
    const auto path = scheduler.runs().at("1").workspace.path;
    tracker.upsert({"1", "SYM-1", "Stop", "Done", {}});
    scheduler.reconcile();

    ut::expect(entered);
    ut::expect(std::filesystem::exists(path));
    ut::expect(scheduler.runs().contains("1"));
    const auto stopped = wait_until(runtime.stopped, 1, std::chrono::seconds{2});
    const auto completion_deadline = std::chrono::steady_clock::now() + std::chrono::seconds{2};
    while (scheduler.runs().contains("1") &&
           std::chrono::steady_clock::now() < completion_deadline) {
      scheduler.tick("{{ issue.identifier }}");
      std::this_thread::sleep_for(std::chrono::milliseconds{1});
    }

    ut::expect(stopped);
    ut::expect(!scheduler.runs().contains("1"));
    ut::expect(!std::filesystem::exists(path));
    std::filesystem::remove_all(root);
  };

  ut::test("scheduler refreshes active issue between bounded live turns") = [] {
    class MultiTurnRuntime final : public symphony::codex::AgentRuntime {
    public:
      symphony::codex::RunResult run(const symphony::codex::RunRequest& request,
                                     std::stop_token) override {
        max_turns = request.max_turns;
        prompts.push_back(request.prompt);
        for (std::uint32_t completed = 1; completed <= request.max_turns; ++completed) {
          const auto continuation = request.continuation_prompt_after_turn(completed);
          if (completed >= request.max_turns || !continuation) break;
          prompts.push_back(*continuation);
        }
        symphony::codex::RunResult result{true, false, std::nullopt, "thr_1-turn_2", {}};
        result.turns_completed = static_cast<std::uint32_t>(prompts.size());
        return result;
      }
      std::uint32_t max_turns{0};
      std::vector<std::string> prompts;
    };

    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Multi-turn", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-max-turns-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    MultiTurnRuntime runtime;
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.max_turns = 2;
    FixtureScheduler scheduler(config, tracker, workspaces, runtime, events, clock);

    scheduler.tick("Full prompt for {{ issue.identifier }}");

    ut::expect(runtime.max_turns == std::uint32_t{2});
    ut::expect(runtime.prompts.size() == std::size_t{2});
    ut::expect(runtime.prompts.front() == "Full prompt for SYM-1");
    ut::expect(runtime.prompts.back().find("Continue working") != std::string::npos);
    ut::expect(runtime.prompts.back().find("turn 2 of 2") != std::string::npos);
    ut::expect(scheduler.runs().at("1").retry.has_value());
    std::filesystem::remove_all(root);
  };

  ut::test("scheduler stops live turn loop when refreshed issue is terminal") = [] {
    class TerminalRuntime final : public symphony::codex::AgentRuntime {
    public:
      explicit TerminalRuntime(symphony::tracker::FakeTracker& tracker) : tracker_(tracker) {}

      symphony::codex::RunResult run(const symphony::codex::RunRequest& request,
                                     std::stop_token) override {
        tracker_.upsert({"1", "SYM-1", "Finished", "Done", {}});
        continued = request.continuation_prompt_after_turn(1).has_value();
        symphony::codex::RunResult result{true, false, std::nullopt, "thr_1-turn_1", {}};
        result.turns_completed = 1;
        return result;
      }
      bool continued{false};

    private:
      symphony::tracker::FakeTracker& tracker_;
    };

    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Finish", "Todo", {}});
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-terminal-between-turns-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    TerminalRuntime runtime(tracker);
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.max_turns = 3;
    FixtureScheduler scheduler(config, tracker, workspaces, runtime, events, clock);

    scheduler.tick("{{ issue.identifier }}");

    ut::expect(!runtime.continued);
    ut::expect(scheduler.runs().at("1").retry.has_value());
    clock.advance(std::chrono::seconds{1});
    scheduler.tick("{{ issue.identifier }}");
    ut::expect(scheduler.runs().empty());
    std::filesystem::remove_all(root);
  };

  ut::test("scheduler applies corrective continuation then stalls unchanged work") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Do work", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-scheduler-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    const ProgressSnapshot unchanged{"same", "step", {}, {}};
    runtime.enqueue(RunResult{true, false, unchanged, "s1", {}});
    runtime.enqueue(RunResult{true, false, unchanged, "s2", {}});
    runtime.enqueue(RunResult{true, false, unchanged, "s3", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.max_turns = 1;
    config.model = "gpt-5.6-sol";
    config.reasoning_effort = "high";
    config.escalation_reasoning_effort = "xhigh";
    FixtureScheduler scheduler(config, tracker, workspaces, runtime, events, clock);

    scheduler.tick("Work on {{ issue.identifier }} attempt {{ attempt }}");
    clock.advance(std::chrono::seconds{1});
    scheduler.tick("Work on {{ issue.identifier }} attempt {{ attempt }}");
    clock.advance(std::chrono::seconds{2});
    scheduler.tick("Work on {{ issue.identifier }} attempt {{ attempt }}");

    ut::expect(runtime.run_count() == std::size_t{3});
    ut::expect(runtime.last_model() == std::optional<std::string>{"gpt-5.6-sol"});
    ut::expect(runtime.last_reasoning_effort() == std::optional<std::string>{"xhigh"});
    ut::expect(scheduler.runs().at("1").attempt.context_state ==
               symphony::domain::ContextState::stalled_no_progress);
    std::filesystem::remove_all(root);
  };

  ut::test("reconciliation cleans terminal issue workspace") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Do work", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-reconcile-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    FixtureScheduler scheduler({}, tracker, workspaces, runtime, events, clock);
    scheduler.tick("{{ issue.identifier }}");
    const auto path = scheduler.runs().at("1").workspace.path;
    tracker.upsert({"1", "SYM-1", "Do work", "Done", {}});
    scheduler.reconcile();
    ut::expect(scheduler.runs().find("1") == scheduler.runs().end());
    ut::expect(!std::filesystem::exists(path));
    std::filesystem::remove_all(root);
  };

  ut::test("scheduler matches required labels and states case insensitively") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Eligible", " todo ", {" Ready ", "backend"}});
    tracker.upsert({"2", "SYM-2", "Missing label", "TODO", {"backend"}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-eligibility-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.max_concurrent = 2;
    config.required_labels = {"ready"};
    FixtureScheduler scheduler(config, tracker, workspaces, runtime, events, clock);
    scheduler.tick("{{ issue.identifier }}");
    ut::expect(scheduler.runs().contains("1"));
    ut::expect(!scheduler.runs().contains("2"));
    std::filesystem::remove_all(root);
  };

  ut::test("scheduler requires complete adapter-dispatchable candidates") = [] {
    symphony::tracker::FakeTracker tracker;
    symphony::domain::Issue missing_title{"1", "SYM-1", "", "Todo", {}};
    symphony::domain::Issue provider_blocked{"2", "SYM-2", "Blocked", "Todo", {}};
    provider_blocked.dispatchable = false;
    tracker.upsert(std::move(missing_title));
    tracker.upsert(std::move(provider_blocked));
    const auto root = std::filesystem::temp_directory_path() / "symphony-candidate-validity-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    FixtureScheduler scheduler({}, tracker, workspaces, runtime, events, clock);

    scheduler.tick("{{ issue.identifier }}");

    ut::expect(scheduler.runs().empty());
    ut::expect(runtime.run_count() == std::size_t{0});
    std::filesystem::remove_all(root);
  };

  ut::test("scheduler orders valid priorities then creation time") = [] {
    symphony::tracker::FakeTracker tracker;
    const auto epoch = std::chrono::system_clock::time_point{};
    symphony::domain::Issue later{"1", "SYM-9", "Later", "Todo", {}};
    later.priority = 2;
    later.created_at = epoch + std::chrono::seconds{2};
    symphony::domain::Issue earlier{"2", "SYM-8", "Earlier", "Todo", {}};
    earlier.priority = 2;
    earlier.created_at = epoch + std::chrono::seconds{1};
    symphony::domain::Issue highest{"3", "SYM-7", "Highest", "Todo", {}};
    highest.priority = 1;
    highest.created_at = epoch + std::chrono::seconds{3};
    tracker.upsert(std::move(later));
    tracker.upsert(std::move(earlier));
    tracker.upsert(std::move(highest));
    const auto root = std::filesystem::temp_directory_path() / "symphony-candidate-order-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.max_concurrent = 2;
    FixtureScheduler scheduler(config, tracker, workspaces, runtime, events, clock);

    scheduler.tick("{{ issue.identifier }}");

    ut::expect(scheduler.runs().contains("3"));
    ut::expect(scheduler.runs().contains("2"));
    ut::expect(!scheduler.runs().contains("1"));
    std::filesystem::remove_all(root);
  };

  ut::test("reconciliation releases active issue made unroutable by adapter") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Initially routable", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-routability-refresh-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    FixtureScheduler scheduler({}, tracker, workspaces, runtime, events, clock);
    scheduler.tick("{{ issue.identifier }}");
    auto unroutable = *tracker.refresh_by_id("1");
    unroutable.dispatchable = false;
    tracker.upsert(std::move(unroutable));

    scheduler.reconcile();

    ut::expect(scheduler.runs().empty());
    std::filesystem::remove_all(root);
  };

  ut::test("scheduler runs all workspace lifecycle hooks in order") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Hooks", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-hooks-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.after_create_hook = "true";
    config.before_run_hook = "true";
    config.after_run_hook = "true";
    config.before_remove_hook = "true";
    FixtureScheduler scheduler(config, tracker, workspaces, runtime, events, clock);
    scheduler.tick("{{ issue.identifier }}");
    tracker.upsert({"1", "SYM-1", "Hooks", "Done", {}});
    scheduler.reconcile();
    ut::expect(
        workspaces.hook_history() ==
        std::vector<std::string>({"after_create", "before_run", "after_run", "before_remove"}));
    std::filesystem::remove_all(root);
  };

  ut::test("startup cleanup removes preserved terminal workspaces without "
           "creating new ones") = [] {
    symphony::tracker::FakeTracker tracker;
    const symphony::domain::Issue terminal{"1", "SYM-1", "Done", "Done", {}};
    tracker.upsert(terminal);
    const auto root = std::filesystem::temp_directory_path() / "symphony-startup-cleanup-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    const auto existing = workspaces.create(terminal);
    symphony::codex::FakeAgentRuntime runtime;
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    FixtureScheduler scheduler({}, tracker, workspaces, runtime, events, clock);
    scheduler.startup_cleanup();
    ut::expect(!std::filesystem::exists(existing.path));
    std::filesystem::remove_all(root);
  };

  ut::test("abnormal worker exit uses ten second exponential retry") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Retry", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-backoff-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "failed", "exit"});
    runtime.enqueue(RunResult{false, false, std::nullopt, "failed-again", "exit"});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    FixtureScheduler scheduler({}, tracker, workspaces, runtime, events, clock);
    scheduler.tick("{{ issue.identifier }}");
    clock.advance(std::chrono::seconds{9});
    scheduler.tick("{{ issue.identifier }}");
    ut::expect(runtime.run_count() == std::size_t{1});
    clock.advance(std::chrono::seconds{1});
    scheduler.tick("{{ issue.identifier }}");
    ut::expect(runtime.run_count() == std::size_t{2});
    std::filesystem::remove_all(root);
  };

  ut::test("scheduler escalates repeated failure effort with explicit reasons") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Repeated failure", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-policy-escalation-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "s1", "same failure"});
    runtime.enqueue(RunResult{false, false, std::nullopt, "s2", "same failure"});
    runtime.enqueue(RunResult{false, false, std::nullopt, "s3", "same failure"});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.max_turns = 1;
    config.model = "gpt-5.6-sol";
    config.reasoning_effort = "high";
    config.escalation_model = "gpt-5.6-sol";
    config.escalation_reasoning_effort = "xhigh";
    config.repeated_failure_reasoning_effort = "max";
    FixtureScheduler scheduler(config, tracker, workspaces, runtime, events, clock);

    scheduler.tick("{{ issue.identifier }}");
    ut::expect(runtime.last_reasoning_effort() == std::optional<std::string>{"high"});
    clock.advance(std::chrono::seconds{10});
    scheduler.tick("{{ issue.identifier }}");
    ut::expect(runtime.last_reasoning_effort() == std::optional<std::string>{"xhigh"});
    clock.advance(std::chrono::seconds{20});
    scheduler.tick("{{ issue.identifier }}");
    ut::expect(runtime.last_reasoning_effort() == std::optional<std::string>{"max"});

    const auto recent = events.recent(20);
    ut::expect(std::ranges::any_of(recent, [](const auto& event) {
      return event.type == "agent_policy_selected" &&
             event.message.find("reason=repeated_failure") != std::string::npos;
    }));
    std::filesystem::remove_all(root);
  };

  ut::test("scheduler sends process diagnostics through event redaction") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Diagnostic", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-diagnostic-redaction-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    RunResult result{false, false, std::nullopt, "failed", "exit"};
    result.process_diagnostic =
        symphony::codex::ProcessDiagnostic{std::string{"to"} + "ken=fixture-secret", 20, false};
    runtime.enqueue(std::move(result));
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    FixtureScheduler scheduler(config, tracker, workspaces, runtime, events, clock);

    scheduler.tick("{{ issue.identifier }}");

    const auto recent = events.recent(20);
    const auto diagnostic = std::ranges::find_if(
        recent, [](const auto& event) { return event.type == "worker_process_diagnostic"; });
    ut::expect(diagnostic != recent.end());
    ut::expect(diagnostic->message == std::string{"[REDACTED]"});
    std::filesystem::remove_all(root);
  };

  ut::test("scheduler exposes proactive context rollover") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Context rollover", "Todo", {}});
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-context-rollover-event-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    RunResult result{true, false, std::nullopt, "session", {}};
    result.context_pressure_rollover = true;
    runtime.enqueue(std::move(result));
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.context_rollover_percent = 70;
    FixtureScheduler scheduler(config, tracker, workspaces, runtime, events, clock);

    scheduler.tick("{{ issue.identifier }}");

    ut::expect(runtime.last_context_rollover_percent() == std::optional<std::uint32_t>{70});
    const auto recent = events.recent(20);
    ut::expect(std::ranges::any_of(
        recent, [](const auto& event) { return event.type == "context_pressure_rollover"; }));
    std::filesystem::remove_all(root);
  };

  ut::test("failure retry records complete one-based queue metadata") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Retry metadata", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-retry-metadata-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "failed", "exit"});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    FixtureScheduler scheduler({}, tracker, workspaces, runtime, events, clock);

    scheduler.tick("{{ issue.identifier }}");

    const auto& retry = *scheduler.runs().at("1").retry;
    ut::expect(retry.issue_id == "1");
    ut::expect(retry.identifier == "SYM-1");
    ut::expect(retry.attempt == std::uint32_t{1});
    ut::expect(retry.due_at == symphony::scheduler::Clock::time_point{} + std::chrono::seconds{10});
    ut::expect(retry.timer_handle != std::uint64_t{0});
    ut::expect(retry.error == std::optional<std::string>{"exit"});
    std::filesystem::remove_all(root);
  };

  ut::test("due retry requeues when a running worker exhausts slots") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Will retry", "Todo", {}});
    tracker.upsert({"2", "SYM-2", "Occupies slot", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-retry-slot-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "failed", "exit"});
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.max_concurrent = 2;
    FixtureScheduler scheduler(config, tracker, workspaces, runtime, events, clock);
    scheduler.tick("{{ issue.identifier }}");
    config.max_concurrent = 1;
    scheduler.reconfigure(config);

    clock.advance(std::chrono::seconds{10});
    scheduler.tick("{{ issue.identifier }}");

    ut::expect(runtime.run_count() == std::size_t{2});
    const auto& retry = *scheduler.runs().at("1").retry;
    ut::expect(retry.attempt == std::uint32_t{1});
    ut::expect(retry.error == std::optional<std::string>{"no available orchestrator slots"});
    ut::expect(retry.due_at == symphony::scheduler::Clock::time_point{} + std::chrono::seconds{11});
    std::filesystem::remove_all(root);
  };

  ut::test("stalled worker emits a distinct event and queues failure retry") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Stalled", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-stalled-session-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    RunResult stalled{false, false, std::nullopt, "thr-turn", "app-server stalled"};
    stalled.stalled = true;
    runtime.enqueue(std::move(stalled));
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    FixtureScheduler scheduler({}, tracker, workspaces, runtime, events, clock);

    scheduler.tick("{{ issue.identifier }}");

    const auto recent = events.recent(10);
    ut::expect(std::ranges::any_of(recent, [](const auto& event) {
      return event.type == "stalled_session" && event.issue_id == "1";
    }));
    ut::expect(scheduler.runs().at("1").retry->attempt == std::uint32_t{1});
    ut::expect(scheduler.runs().at("1").retry->error ==
               std::optional<std::string>{"app-server stalled"});
    std::filesystem::remove_all(root);
  };

  ut::test("scheduler aggregates usage and merges sparse rate-limit updates") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Telemetry", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() / "symphony-telemetry-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    symphony::codex::RunResult first{true, false, std::nullopt, "s1", {}};
    first.token_usage = symphony::codex::TokenUsage{
        .input_tokens = 10,
        .cached_input_tokens = 4,
        .output_tokens = 6,
        .reasoning_output_tokens = 2,
        .total_tokens = 16,
        .model_context_window = 200000,
        .last_input_tokens = std::nullopt,
    };
    first.compaction_count = 1;
    first.rate_limits = symphony::codex::RateLimits{
        "codex", symphony::codex::RateLimitWindow{25, 300, 1000}, std::nullopt};
    symphony::codex::RunResult second{true, false, std::nullopt, "s2", {}};
    second.token_usage = symphony::codex::TokenUsage{
        .input_tokens = 3,
        .cached_input_tokens = 1,
        .output_tokens = 2,
        .reasoning_output_tokens = 1,
        .total_tokens = 5,
        .model_context_window = 180000,
        .last_input_tokens = std::nullopt,
    };
    second.compaction_count = 2;
    second.rate_limits = symphony::codex::RateLimits{
        std::nullopt, std::nullopt, symphony::codex::RateLimitWindow{50, 10080, 2000}};
    runtime.enqueue(std::move(first));
    runtime.enqueue(std::move(second));
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    FixtureScheduler scheduler({}, tracker, workspaces, runtime, events, clock);

    scheduler.tick("{{ issue.identifier }}");
    clock.advance(std::chrono::seconds{1});
    scheduler.tick("{{ issue.identifier }}");

    ut::expect(scheduler.codex_totals().input_tokens == std::uint64_t{13});
    ut::expect(scheduler.codex_totals().cached_input_tokens == std::uint64_t{5});
    ut::expect(scheduler.codex_totals().output_tokens == std::uint64_t{8});
    ut::expect(scheduler.codex_totals().total_tokens == std::uint64_t{21});
    ut::expect(scheduler.codex_totals().model_context_window ==
               std::optional<std::int64_t>{180000});
    ut::expect(!scheduler.codex_totals().last_input_tokens.has_value());
    ut::expect(scheduler.codex_compactions() == std::uint64_t{3});
    ut::expect(scheduler.latest_rate_limits()->limit_id == std::optional<std::string>{"codex"});
    ut::expect(scheduler.latest_rate_limits()->primary->used_percent == 25);
    ut::expect(scheduler.latest_rate_limits()->secondary->used_percent == 50);
    std::filesystem::remove_all(root);
  };
};
