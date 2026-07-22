#include <filesystem>

#include "symphony/scheduler/scheduler.hpp"
#include "test.hpp"

using symphony::codex::RunResult;
using symphony::domain::ProgressSnapshot;

TEST("scheduler applies corrective continuation then stalls unchanged work") {
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
  symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime, events, clock);

  scheduler.tick("Work on {{ issue.identifier }} attempt {{ attempt }}");
  clock.advance(std::chrono::seconds{1});
  scheduler.tick("Work on {{ issue.identifier }} attempt {{ attempt }}");
  clock.advance(std::chrono::seconds{2});
  scheduler.tick("Work on {{ issue.identifier }} attempt {{ attempt }}");

  REQUIRE_EQ(runtime.run_count(), std::size_t{3});
  REQUIRE_EQ(scheduler.runs().at("1").attempt.context_state, symphony::domain::ContextState::stalled_no_progress);
  std::filesystem::remove_all(root);
}

TEST("reconciliation cleans terminal issue workspace") {
  symphony::tracker::FakeTracker tracker;
  tracker.upsert({"1", "SYM-1", "Do work", "Todo", {}});
  const auto root = std::filesystem::temp_directory_path() / "symphony-reconcile-test";
  std::filesystem::remove_all(root);
  symphony::workspace::FixtureWorkspaceExecutor workspaces(root);
  symphony::codex::FakeAgentRuntime runtime;
  runtime.enqueue(RunResult{false, false, std::nullopt, "running", {}});
  symphony::observability::MemoryEventStore events;
  symphony::scheduler::FakeClock clock;
  symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime, events, clock);
  scheduler.tick("{{ issue.identifier }}");
  const auto path = scheduler.runs().at("1").workspace.path;
  tracker.upsert({"1", "SYM-1", "Do work", "Done", {}});
  scheduler.reconcile();
  REQUIRE(scheduler.runs().find("1") == scheduler.runs().end());
  REQUIRE(!std::filesystem::exists(path));
  std::filesystem::remove_all(root);
}

TEST("scheduler matches required labels and states case insensitively") {
  symphony::tracker::FakeTracker tracker;
  tracker.upsert({"1", "SYM-1", "Eligible", "todo", {" Ready ", "backend"}});
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
  symphony::scheduler::Scheduler scheduler(config, tracker, workspaces, runtime, events, clock);
  scheduler.tick("{{ issue.identifier }}");
  REQUIRE(scheduler.runs().contains("1"));
  REQUIRE(!scheduler.runs().contains("2"));
  std::filesystem::remove_all(root);
}

TEST("scheduler runs all workspace lifecycle hooks in order") {
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
  symphony::scheduler::Scheduler scheduler(config, tracker, workspaces, runtime, events, clock);
  scheduler.tick("{{ issue.identifier }}");
  tracker.upsert({"1", "SYM-1", "Hooks", "Done", {}});
  scheduler.reconcile();
  REQUIRE_EQ(
      workspaces.hook_history(),
      std::vector<std::string>({"after_create", "before_run", "after_run", "before_remove"}));
  std::filesystem::remove_all(root);
}

TEST("startup cleanup removes preserved terminal workspaces without creating new ones") {
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
  symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime, events, clock);
  scheduler.startup_cleanup();
  REQUIRE(!std::filesystem::exists(existing.path));
  std::filesystem::remove_all(root);
}

TEST("abnormal worker exit uses ten second exponential retry") {
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
  symphony::scheduler::Scheduler scheduler({}, tracker, workspaces, runtime, events, clock);
  scheduler.tick("{{ issue.identifier }}");
  clock.advance(std::chrono::seconds{9});
  scheduler.tick("{{ issue.identifier }}");
  REQUIRE_EQ(runtime.run_count(), std::size_t{1});
  clock.advance(std::chrono::seconds{1});
  scheduler.tick("{{ issue.identifier }}");
  REQUIRE_EQ(runtime.run_count(), std::size_t{2});
  std::filesystem::remove_all(root);
}
