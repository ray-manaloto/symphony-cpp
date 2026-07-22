#include <filesystem>
#include <atomic>
#include <csignal>
#include <iostream>
#include <optional>
#include <thread>

#include "symphony/codex/codex.hpp"
#include "symphony/observability/observability.hpp"
#include "symphony/scheduler/scheduler.hpp"
#include "symphony/tracker/tracker.hpp"
#include "symphony/workflow/workflow.hpp"
#include "symphony/workspace/workspace.hpp"

namespace {
std::atomic_bool stop_requested{false};

void stop_handler(int) { stop_requested.store(true); }

symphony::scheduler::SchedulerConfig scheduler_config(const symphony::workflow::WorkflowConfig& workflow) {
  symphony::scheduler::SchedulerConfig config;
  config.active_states = workflow.tracker.active_states;
  config.terminal_states = workflow.tracker.terminal_states;
  config.required_labels = workflow.tracker.required_labels;
  config.max_concurrent = workflow.agent.max_concurrent_agents;
  for (const auto& [state, limit] : workflow.agent.max_concurrent_agents_by_state) {
    config.max_concurrent_by_state.emplace(state, limit);
  }
  config.retry_cap = workflow.agent.max_retry_backoff;
  config.hook_timeout = workflow.hooks.timeout;
  config.after_create_hook = workflow.hooks.after_create;
  config.before_run_hook = workflow.hooks.before_run;
  config.after_run_hook = workflow.hooks.after_run;
  config.before_remove_hook = workflow.hooks.before_remove;
  return config;
}
}  // namespace

int main(int argc, char** argv) {
  try {
    std::optional<std::filesystem::path> explicit_path;
    bool once = false;
    for (int index = 1; index < argc; ++index) {
      const std::string_view argument{argv[index]};
      if (argument == "--workflow" && index + 1 < argc) explicit_path = argv[++index];
      else if (argument == "--once") once = true;
      else throw std::runtime_error("usage: symphonyd [--workflow PATH] [--once]");
    }
    symphony::workflow::ProcessEnvironment environment;
    const auto path = symphony::workflow::WorkflowLoader::resolve_path(explicit_path, std::filesystem::current_path());
    auto workflow = symphony::workflow::WorkflowLoader{}.load(path, environment);
    symphony::workflow::validate_for_dispatch(workflow.config, {"fake", "github", "linear"});
    symphony::tracker::FakeTracker tracker;
    symphony::workspace::FixtureWorkspaceExecutor workspaces(workflow.config.workspace.root);
    symphony::codex::CodexAppServerRuntime runtime(
        workflow.config.codex.command,
        workflow.config.codex.read_timeout,
        workflow.config.codex.stall_timeout,
        workflow.config.codex.turn_timeout);
    symphony::observability::MemoryEventStore events;
    symphony::scheduler::SystemClock clock;
    auto config = scheduler_config(workflow.config);
    symphony::scheduler::Scheduler scheduler(config, tracker, workspaces, runtime, events, clock);
    scheduler.startup_cleanup();
    symphony::workflow::WorkflowWatcher watcher;
    if (const auto initial = watcher.reload_if_changed(path, environment)) watcher.accept(*initial);
    std::signal(SIGINT, stop_handler);
    std::signal(SIGTERM, stop_handler);
    do {
      try {
        if (auto changed = watcher.reload_if_changed(path, environment)) {
          symphony::workflow::validate_for_dispatch(changed->config, {"fake", "github", "linear"});
          if (changed->config.workspace.root != workflow.config.workspace.root) {
            if (!scheduler.runs().empty()) {
              throw std::runtime_error("workspace.root reload deferred while issue runs exist");
            }
            workspaces = symphony::workspace::FixtureWorkspaceExecutor(changed->config.workspace.root);
          }
          runtime.reconfigure(
              changed->config.codex.command,
              changed->config.codex.read_timeout,
              changed->config.codex.stall_timeout,
              changed->config.codex.turn_timeout);
          scheduler.reconfigure(scheduler_config(changed->config));
          watcher.accept(*changed);
          workflow = std::move(*changed);
          std::cerr << "symphonyd: workflow reloaded\n";
        }
      } catch (const std::exception& error) {
        std::cerr << "symphonyd: workflow reload rejected: " << error.what() << '\n';
      }
      scheduler.tick(workflow.prompt);
      if (!once) std::this_thread::sleep_for(workflow.config.polling.interval);
    } while (!once && !stop_requested.load());
    std::cout << "symphonyd fixture loop stopped; live adapters disabled\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "symphonyd: " << error.what() << '\n';
    return 1;
  }
}
