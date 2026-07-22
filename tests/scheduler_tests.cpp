#include <algorithm>
#include <filesystem>
#include <optional>

#include <ut/ut.hpp>

#include "symphony/scheduler/scheduler.hpp"

using symphony::codex::RunResult;
using symphony::domain::ProgressSnapshot;

static ut::suite scheduler_tests = [] {
  ut::test(
      "scheduler applies corrective continuation then stalls unchanged work") =
      [] {
        symphony::tracker::FakeTracker tracker;
        tracker.upsert({"1", "SYM-1", "Do work", "Todo", {}});
        const auto root =
            std::filesystem::temp_directory_path() / "symphony-scheduler-test";
        std::filesystem::remove_all(root);
        symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
        symphony::codex::FakeAgentRuntime runtime;
        const ProgressSnapshot unchanged{"same", "step", {}, {}};
        runtime.enqueue(RunResult{true, false, unchanged, "s1", {}});
        runtime.enqueue(RunResult{true, false, unchanged, "s2", {}});
        runtime.enqueue(RunResult{true, false, unchanged, "s3", {}});
        symphony::observability::MemoryEventStore events;
        symphony::scheduler::FakeClock clock;
        symphony::scheduler::Scheduler scheduler({}, tracker, workspaces,
                                                 runtime, events, clock);

        scheduler.tick("Work on {{ issue.identifier }} attempt {{ attempt }}");
        clock.advance(std::chrono::seconds{1});
        scheduler.tick("Work on {{ issue.identifier }} attempt {{ attempt }}");
        clock.advance(std::chrono::seconds{2});
        scheduler.tick("Work on {{ issue.identifier }} attempt {{ attempt }}");

        ut::expect(runtime.run_count() == std::size_t{3});
        ut::expect(scheduler.runs().at("1").attempt.context_state ==
                   symphony::domain::ContextState::stalled_no_progress);
        std::filesystem::remove_all(root);
      };

  ut::test("reconciliation cleans terminal issue workspace") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Do work", "Todo", {}});
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-reconcile-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime,
                                             events, clock);
    scheduler.tick("{{ issue.identifier }}");
    const auto path = scheduler.runs().at("1").workspace.path;
    tracker.upsert({"1", "SYM-1", "Do work", "Done", {}});
    scheduler.reconcile();
    ut::expect(scheduler.runs().find("1") == scheduler.runs().end());
    ut::expect(!std::filesystem::exists(path));
    std::filesystem::remove_all(root);
  };

  ut::test(
      "scheduler matches required labels and states case insensitively") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Eligible", " todo ", {" Ready ", "backend"}});
    tracker.upsert({"2", "SYM-2", "Missing label", "TODO", {"backend"}});
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-eligibility-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.max_concurrent = 2;
    config.required_labels = {"ready"};
    symphony::scheduler::Scheduler scheduler(config, tracker, workspaces,
                                             runtime, events, clock);
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
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-candidate-validity-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime,
                                             events, clock);

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
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-candidate-order-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.max_concurrent = 2;
    symphony::scheduler::Scheduler scheduler(config, tracker, workspaces, runtime,
                                             events, clock);

    scheduler.tick("{{ issue.identifier }}");

    ut::expect(scheduler.runs().contains("3"));
    ut::expect(scheduler.runs().contains("2"));
    ut::expect(!scheduler.runs().contains("1"));
    std::filesystem::remove_all(root);
  };

  ut::test("reconciliation releases active issue made unroutable by adapter") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Initially routable", "Todo", {}});
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-routability-refresh-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime,
                                             events, clock);
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
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-hooks-test";
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
    symphony::scheduler::Scheduler scheduler(config, tracker, workspaces,
                                             runtime, events, clock);
    scheduler.tick("{{ issue.identifier }}");
    tracker.upsert({"1", "SYM-1", "Hooks", "Done", {}});
    scheduler.reconcile();
    ut::expect(workspaces.hook_history() ==
               std::vector<std::string>({"after_create", "before_run",
                                         "after_run", "before_remove"}));
    std::filesystem::remove_all(root);
  };

  ut::test("startup cleanup removes preserved terminal workspaces without "
           "creating new ones") = [] {
    symphony::tracker::FakeTracker tracker;
    const symphony::domain::Issue terminal{"1", "SYM-1", "Done", "Done", {}};
    tracker.upsert(terminal);
    const auto root = std::filesystem::temp_directory_path() /
                      "symphony-startup-cleanup-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    const auto existing = workspaces.create(terminal);
    symphony::codex::FakeAgentRuntime runtime;
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime,
                                             events, clock);
    scheduler.startup_cleanup();
    ut::expect(!std::filesystem::exists(existing.path));
    std::filesystem::remove_all(root);
  };

  ut::test("abnormal worker exit uses ten second exponential retry") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Retry", "Todo", {}});
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-backoff-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "failed", "exit"});
    runtime.enqueue(
        RunResult{false, false, std::nullopt, "failed-again", "exit"});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime,
                                             events, clock);
    scheduler.tick("{{ issue.identifier }}");
    clock.advance(std::chrono::seconds{9});
    scheduler.tick("{{ issue.identifier }}");
    ut::expect(runtime.run_count() == std::size_t{1});
    clock.advance(std::chrono::seconds{1});
    scheduler.tick("{{ issue.identifier }}");
    ut::expect(runtime.run_count() == std::size_t{2});
    std::filesystem::remove_all(root);
  };

  ut::test("failure retry records complete one-based queue metadata") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Retry metadata", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() /
                      "symphony-retry-metadata-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "failed", "exit"});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime,
                                             events, clock);

    scheduler.tick("{{ issue.identifier }}");

    const auto& retry = *scheduler.runs().at("1").retry;
    ut::expect(retry.issue_id == "1");
    ut::expect(retry.identifier == "SYM-1");
    ut::expect(retry.attempt == std::uint32_t{1});
    ut::expect(retry.due_at == symphony::scheduler::Clock::time_point{} +
                                  std::chrono::seconds{10});
    ut::expect(retry.timer_handle != std::uint64_t{0});
    ut::expect(retry.error == std::optional<std::string>{"exit"});
    std::filesystem::remove_all(root);
  };

  ut::test("due retry requeues when a running worker exhausts slots") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Will retry", "Todo", {}});
    tracker.upsert({"2", "SYM-2", "Occupies slot", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() /
                      "symphony-retry-slot-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(RunResult{false, false, std::nullopt, "failed", "exit"});
    runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.max_concurrent = 2;
    symphony::scheduler::Scheduler scheduler(config, tracker, workspaces,
                                             runtime, events, clock);
    scheduler.tick("{{ issue.identifier }}");
    config.max_concurrent = 1;
    scheduler.reconfigure(config);

    clock.advance(std::chrono::seconds{10});
    scheduler.tick("{{ issue.identifier }}");

    ut::expect(runtime.run_count() == std::size_t{2});
    const auto& retry = *scheduler.runs().at("1").retry;
    ut::expect(retry.attempt == std::uint32_t{1});
    ut::expect(retry.error ==
               std::optional<std::string>{"no available orchestrator slots"});
    ut::expect(retry.due_at == symphony::scheduler::Clock::time_point{} +
                                  std::chrono::seconds{11});
    std::filesystem::remove_all(root);
  };

  ut::test("stalled worker emits a distinct event and queues failure retry") = [] {
    symphony::tracker::FakeTracker tracker;
    tracker.upsert({"1", "SYM-1", "Stalled", "Todo", {}});
    const auto root = std::filesystem::temp_directory_path() /
                      "symphony-stalled-session-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    RunResult stalled{false, false, std::nullopt, "thr-turn", "app-server stalled"};
    stalled.stalled = true;
    runtime.enqueue(std::move(stalled));
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime,
                                             events, clock);

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
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-telemetry-test";
    std::filesystem::remove_all(root);
    symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
    symphony::codex::FakeAgentRuntime runtime;
    symphony::codex::RunResult first{true, false, std::nullopt, "s1", {}};
    first.token_usage = symphony::codex::TokenUsage{10, 4, 6, 2, 16};
    first.rate_limits = symphony::codex::RateLimits{
        "codex", symphony::codex::RateLimitWindow{25, 300, 1000}, std::nullopt};
    symphony::codex::RunResult second{true, false, std::nullopt, "s2", {}};
    second.token_usage = symphony::codex::TokenUsage{3, 1, 2, 1, 5};
    second.rate_limits = symphony::codex::RateLimits{
        std::nullopt, std::nullopt,
        symphony::codex::RateLimitWindow{50, 10080, 2000}};
    runtime.enqueue(std::move(first));
    runtime.enqueue(std::move(second));
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime,
                                             events, clock);

    scheduler.tick("{{ issue.identifier }}");
    clock.advance(std::chrono::seconds{1});
    scheduler.tick("{{ issue.identifier }}");

    ut::expect(scheduler.codex_totals().input_tokens == std::uint64_t{13});
    ut::expect(scheduler.codex_totals().cached_input_tokens == std::uint64_t{5});
    ut::expect(scheduler.codex_totals().output_tokens == std::uint64_t{8});
    ut::expect(scheduler.codex_totals().total_tokens == std::uint64_t{21});
    ut::expect(scheduler.latest_rate_limits()->limit_id ==
               std::optional<std::string>{"codex"});
    ut::expect(scheduler.latest_rate_limits()->primary->used_percent == 25);
    ut::expect(scheduler.latest_rate_limits()->secondary->used_percent == 50);
    std::filesystem::remove_all(root);
  };
};
