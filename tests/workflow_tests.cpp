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
      "---\npoll_interval_ms: $POLL_MS\nagent:\n  max_concurrent: 3\nhooks:\n  timeout_ms: 42\ncodex:\n  command: codex app-server --fixture\n---\nWork on {{ issue.identifier }} attempt {{ attempt }}.\n");
  FakeEnvironment env;
  env.values.emplace("POLL_MS", "250");
  const auto document = symphony::workflow::WorkflowLoader{}.load(path, env);
  REQUIRE_EQ(document.config.poll_interval.count(), 250);
  REQUIRE_EQ(document.config.agent.max_concurrent, 3U);
  REQUIRE_EQ(document.config.hooks.timeout.count(), 42);
  REQUIRE(document.prompt.find("issue.identifier") != std::string::npos);
  std::filesystem::remove(path);
}

TEST("workflow rejects unknown keys and absent environment") {
  FakeEnvironment env;
  auto path = temp_workflow("---\nunknown: 1\n---\nprompt\n");
  REQUIRE_THROWS(symphony::workflow::WorkflowLoader{}.load(path, env));
  path = temp_workflow("---\npoll_interval_ms: $MISSING\n---\nprompt\n");
  REQUIRE_THROWS(symphony::workflow::WorkflowLoader{}.load(path, env));
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
