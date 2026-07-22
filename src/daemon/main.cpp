#include <filesystem>
#include <iostream>
#include <optional>

#include "symphony/codex/codex.hpp"
#include "symphony/observability/observability.hpp"
#include "symphony/scheduler/scheduler.hpp"
#include "symphony/tracker/tracker.hpp"
#include "symphony/workflow/workflow.hpp"
#include "symphony/workspace/workspace.hpp"

int main(int argc, char** argv) {
  try {
    std::optional<std::filesystem::path> explicit_path;
    for (int index = 1; index < argc; ++index) {
      const std::string_view argument{argv[index]};
      if (argument == "--workflow" && index + 1 < argc) explicit_path = argv[++index];
      else if (argument != "--once") throw std::runtime_error("usage: symphonyd [--workflow PATH] [--once]");
    }
    symphony::workflow::ProcessEnvironment environment;
    const auto path = symphony::workflow::WorkflowLoader::resolve_path(explicit_path, std::filesystem::current_path());
    const auto workflow = symphony::workflow::WorkflowLoader{}.load(path, environment);
    symphony::tracker::FakeTracker tracker;
    symphony::workspace::FixtureWorkspaceExecutor workspaces(
        std::filesystem::temp_directory_path() / "symphony-cpp-fixture-workspaces");
    symphony::codex::FakeAgentRuntime runtime;
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::FakeClock clock;
    symphony::scheduler::SchedulerConfig config;
    config.active_states = workflow.config.active_states;
    config.terminal_states = workflow.config.terminal_states;
    config.max_concurrent = workflow.config.agent.max_concurrent;
    config.retry_cap = workflow.config.agent.max_retry_backoff;
    symphony::scheduler::Scheduler scheduler(config, tracker, workspaces, runtime, events, clock);
    scheduler.tick(workflow.prompt);
    std::cout << "symphonyd fixture tick complete; live adapters disabled\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "symphonyd: " << error.what() << '\n';
    return 1;
  }
}

