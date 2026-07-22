#include <filesystem>

#include "symphony/workspace/workspace.hpp"
#include "test.hpp"

TEST("workspace leaf is sanitized and collision resistant") {
  const symphony::domain::Issue one{"id-1", "../SYM 1", "", "Todo", {}};
  const symphony::domain::Issue two{"id-2", "../SYM 1", "", "Todo", {}};
  const auto first = symphony::workspace::workspace_leaf(one);
  const auto second = symphony::workspace::workspace_leaf(two);
  REQUIRE(first.find("..") == std::string::npos);
  REQUIRE(first != second);
}

TEST("fixture workspace creates hooks and removes only contained paths") {
  const auto root = std::filesystem::temp_directory_path() / "symphony-workspaces";
  std::filesystem::remove_all(root);
  symphony::workspace::FixtureWorkspaceExecutor executor(root);
  const symphony::domain::Issue issue{"id-1", "SYM-1", "", "Todo", {}};
  const auto workspace = executor.create(issue);
  REQUIRE(std::filesystem::is_directory(workspace.path));
  executor.run_hook(workspace, "before_run", {"fixture", "check"}, std::chrono::milliseconds{10});
  REQUIRE_EQ(executor.hook_history().size(), std::size_t{1});
  executor.remove(workspace);
  REQUIRE(!std::filesystem::exists(workspace.path));
  std::filesystem::remove_all(root);
}

