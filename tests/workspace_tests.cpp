#include <filesystem>
#include <ut/ut.hpp>

#include "symphony/workspace/workspace.hpp"

static ut::suite workspace_tests = [] {
  ut::test("workspace leaf is sanitized and collision resistant") = [] {
    const symphony::domain::Issue one{"id-1", "../SYM 1", "", "Todo", {}};
    const symphony::domain::Issue two{"id-2", "../SYM 1", "", "Todo", {}};
    const auto first = symphony::workspace::workspace_leaf(one);
    const auto second = symphony::workspace::workspace_leaf(two);
    ut::expect(first.find("..") == std::string::npos);
    ut::expect(first != second);
  };

  ut::test("fixture workspace creates hooks and removes only contained paths") =
      [] {
        const auto root =
            std::filesystem::temp_directory_path() / "symphony-workspaces";
        std::filesystem::remove_all(root);
        symphony::workspace::FixtureWorkspaceExecutor executor(root);
        const symphony::domain::Issue issue{"id-1", "SYM-1", "", "Todo", {}};
        const auto workspace = executor.create(issue);
        ut::expect(std::filesystem::is_directory(workspace.path));
        executor.run_hook(workspace, "before_run", {"fixture", "check"},
                          std::chrono::milliseconds{10});
        ut::expect(executor.hook_history().size() == std::size_t{1});
        executor.remove(workspace);
        ut::expect(!std::filesystem::exists(workspace.path));
        std::filesystem::remove_all(root);
      };

  ut::test("local workspace executes argv hooks inside the workspace") = [] {
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-local-workspaces";
    std::filesystem::remove_all(root);
    symphony::workspace::LocalWorkspaceExecutor executor(root);
    const symphony::domain::Issue issue{
        "id-local", "SYM-LOCAL", "", "Todo", {}};
    const auto workspace = executor.create(issue);
    executor.run_hook(workspace, "before_run", {"/usr/bin/touch", "hook-ran"},
                      std::chrono::seconds{1});
    ut::expect(std::filesystem::exists(workspace.path / "hook-ran"));
    executor.remove(workspace);
    std::filesystem::remove_all(root);
  };

  ut::test("local workspace kills timed-out hooks") = [] {
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-timeout-workspaces";
    std::filesystem::remove_all(root);
    symphony::workspace::LocalWorkspaceExecutor executor(root);
    const symphony::domain::Issue issue{
        "id-timeout", "SYM-TIMEOUT", "", "Todo", {}};
    const auto workspace = executor.create(issue);
    ut::expect(ut::throws([&] {
      executor.run_hook(workspace, "before_run", {"/bin/sh", "-c", "sleep 1"},
                        std::chrono::milliseconds{20});
    }));
    executor.remove(workspace);
    std::filesystem::remove_all(root);
  };
};
