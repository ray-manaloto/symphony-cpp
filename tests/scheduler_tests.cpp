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
