#include <filesystem>
#include <fstream>
#include <map>

#include "symphony/workflow/workflow.hpp"
#include "test.hpp"

namespace {
class FakeEnvironment final : public symphony::workflow::Environment {
 public:
  std::map<std::string, std::string> values;
  [[nodiscard]] std::optional<std::string> get(std::string_view name) const override {
    const auto found = values.find(std::string{name});
    if (found == values.end()) return std::nullopt;
    return found->second;
  }
};

std::filesystem::path temp_workflow(std::string_view content) {
  const auto path = std::filesystem::temp_directory_path() / "symphony-workflow-test.md";
  std::ofstream stream(path, std::ios::trunc);
  stream << content;
  return path;
}
}  // namespace

TEST("workflow path uses explicit path or cwd default") {
  using symphony::workflow::WorkflowLoader;
  REQUIRE_EQ(WorkflowLoader::resolve_path("custom.md", "/tmp/base"), std::filesystem::path{"custom.md"});
  REQUIRE_EQ(WorkflowLoader::resolve_path(std::nullopt, "/tmp/base"), std::filesystem::path{"/tmp/base/WORKFLOW.md"});
}

TEST("workflow parses typed defaults environment and prompt") {
  const auto path = temp_workflow(
      "---\npolling:\n  interval_ms: 250\nworkspace:\n  root: $WORKSPACE_ROOT\nagent:\n  max_concurrent_agents: 3\n  max_turns: 7\nhooks:\n  timeout_ms: 42\n  before_run: |\n    echo fixture\ncodex:\n  command: codex app-server --fixture\nfuture_extension:\n  enabled: true\n---\nWork on {{ issue.identifier }} attempt {{ attempt }}.\n");
  FakeEnvironment env;
  env.values.emplace("WORKSPACE_ROOT", "/tmp/symphony-fixtures");
  const auto document = symphony::workflow::WorkflowLoader{}.load(path, env);
  REQUIRE_EQ(document.config.polling.interval.count(), 250);
  REQUIRE_EQ(document.config.workspace.root, std::filesystem::path{"/tmp/symphony-fixtures"});
  REQUIRE_EQ(document.config.agent.max_concurrent_agents, 3U);
  REQUIRE_EQ(document.config.agent.max_turns, 7U);
  REQUIRE_EQ(document.config.hooks.timeout.count(), 42);
  REQUIRE(document.config.hooks.before_run->find("echo fixture") != std::string::npos);
  REQUIRE(document.prompt.find("issue.identifier") != std::string::npos);
  std::filesystem::remove(path);
}

TEST("workflow ignores extension keys and rejects absent path environment") {
  FakeEnvironment env;
  auto path = temp_workflow("---\nunknown: 1\n---\nprompt\n");
  REQUIRE_EQ(symphony::workflow::WorkflowLoader{}.load(path, env).prompt, std::string{"prompt\n"});
  path = temp_workflow("---\nworkspace:\n  root: $MISSING\n---\nprompt\n");
  REQUIRE_THROWS(symphony::workflow::WorkflowLoader{}.load(path, env));
  std::filesystem::remove(path);
}

TEST("workflow preserves provider config and normalizes state concurrency") {
  FakeEnvironment env;
  const auto path = temp_workflow(
      "---\ntracker:\n  kind: fake\n  provider:\n    project: symphony\n  required_labels: [ready]\n  active_states: [Todo]\n  terminal_states: [Done]\nagent:\n  max_concurrent_agents_by_state:\n    ' In Progress ': 2\n    bad: 0\n---\nprompt\n");
  const auto document = symphony::workflow::WorkflowLoader{}.load(path, env);
  REQUIRE_EQ(document.config.tracker.kind, std::string{"fake"});
  REQUIRE(document.config.tracker.provider_yaml.find("symphony") != std::string::npos);
  REQUIRE_EQ(document.config.agent.max_concurrent_agents_by_state.at("in progress"), 2U);
  REQUIRE(!document.config.agent.max_concurrent_agents_by_state.contains("bad"));
  symphony::workflow::validate_for_dispatch(document.config, {"fake"});
  std::filesystem::remove(path);
}

TEST("dispatch validation rejects missing and unsupported trackers") {
  symphony::workflow::WorkflowConfig config;
  REQUIRE_THROWS(symphony::workflow::validate_for_dispatch(config, {"fake"}));
  config.tracker.kind = "unknown";
  config.tracker.active_states = {"Todo"};
  config.tracker.terminal_states = {"Done"};
  REQUIRE_THROWS(symphony::workflow::validate_for_dispatch(config, {"fake"}));
}

TEST("workflow watcher retries unaccepted changes and quiets accepted content") {
  FakeEnvironment env;
  const auto path = temp_workflow("---\nunknown: true\n---\nprompt\n");
  symphony::workflow::WorkflowWatcher watcher;
  const auto first = watcher.reload_if_changed(path, env);
  REQUIRE(first.has_value());
  REQUIRE(watcher.reload_if_changed(path, env).has_value());
  watcher.accept(*first);
  REQUIRE(!watcher.reload_if_changed(path, env).has_value());
  std::filesystem::remove(path);
}

TEST("strict prompt renderer permits only issue and attempt variables") {
  symphony::domain::Issue issue{"1", "SYM-1", "Title", "Todo", {}};
  symphony::domain::Attempt attempt;
  attempt.number = 2;
  const auto rendered = symphony::workflow::render_prompt(
      "{{ issue.identifier }}: {{ issue.title }} / {{ attempt }}", issue, attempt);
  REQUIRE_EQ(rendered, std::string{"SYM-1: Title / 2"});
  REQUIRE_THROWS(symphony::workflow::render_prompt("{{ secret }}", issue, attempt));
}
