#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <string>
#include <ut/ut.hpp>

#include "symphony/workspace/workspace.hpp"

static ut::suite workspace_tests = [] {
  ut::test("workspace leaf is sanitized and collision resistant") = [] {
    const symphony::domain::Issue one{"id-1", "../SYM 1", "", "Todo", {}};
    const symphony::domain::Issue two{"id-2", "../SYM 1", "", "Todo", {}};
    const auto first = symphony::workspace::workspace_leaf(one);
    const auto second = symphony::workspace::workspace_leaf(two);
    ut::expect(first == second);
    ut::expect(first.starts_with(".._SYM_1-"));
    ut::expect(first.size() == std::string{".._SYM_1-"}.size() + 16);
    ut::expect(std::ranges::all_of(
        first.substr(first.size() - 16), [](const unsigned char character) {
          return std::isxdigit(character) != 0;
        }));
  };

  ut::test("workspace leaf preserves allowed identifiers without a suffix") =
      [] {
        const symphony::domain::Issue issue{
            "opaque-id", "SYM.1_release-2", "", "Todo", {}};
        ut::expect(symphony::workspace::workspace_leaf(issue) ==
                   std::string{"SYM.1_release-2"});
      };

  ut::test("workspace leaf hashes the original identifier with at least 64 bits") =
      [] {
        const symphony::domain::Issue space{
            "same-id", "SYM 1", "", "Todo", {}};
        const symphony::domain::Issue slash{
            "same-id", "SYM/1", "", "Todo", {}};
        const symphony::domain::Issue utf8{
            "same-id", std::string{"SYM-\xC3\xA9"}, "", "Todo", {}};
        const auto first = symphony::workspace::workspace_leaf(space);
        const auto second = symphony::workspace::workspace_leaf(slash);
        const auto third = symphony::workspace::workspace_leaf(utf8);
        ut::expect(first.starts_with("SYM_1-"));
        ut::expect(second.starts_with("SYM_1-"));
        ut::expect(third.starts_with("SYM-__-"));
        ut::expect(first != second);
        ut::expect(first.size() == std::string{"SYM_1-"}.size() + 16);
        ut::expect(second.size() == std::string{"SYM_1-"}.size() + 16);
      };

  ut::test("workspace leaf rejects a missing required identifier") = [] {
    const symphony::domain::Issue issue{"opaque-id", "", "", "Todo", {}};
    ut::expect(ut::throws(
        [&] { static_cast<void>(symphony::workspace::workspace_leaf(issue)); }));
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

  ut::test("fixture workspace rejects a symlink swapped in before hooks or removal") =
      [] {
        const auto temporary = std::filesystem::temp_directory_path();
        const auto root = temporary / "symphony-fixture-symlink-workspaces";
        const auto outside = temporary / "symphony-fixture-symlink-outside";
        std::filesystem::remove_all(root);
        std::filesystem::remove_all(outside);
        std::filesystem::create_directories(outside);
        const auto sentinel = outside / "keep";
        std::ofstream{sentinel} << "outside";

        symphony::workspace::FixtureWorkspaceExecutor executor(root);
        const symphony::domain::Issue issue{
            "id-fixture-symlink", "SYM-FIXTURE-SYMLINK", "", "Todo", {}};
        const auto workspace = executor.create(issue);
        std::filesystem::remove_all(workspace.path);
        std::filesystem::create_directory_symlink(outside, workspace.path);

        ut::expect(ut::throws([&] {
          executor.run_hook(workspace, "before_run", {"fixture", "check"},
                            std::chrono::seconds{1});
        }));
        ut::expect(ut::throws([&] { executor.remove(workspace); }));
        ut::expect(std::filesystem::exists(sentinel));

        std::filesystem::remove(workspace.path);
        std::filesystem::remove_all(root);
        std::filesystem::remove_all(outside);
      };

  ut::test("local workspace rejects traversal and symlink swaps without touching outside data") =
      [] {
        const auto temporary = std::filesystem::temp_directory_path();
        const auto root = temporary / "symphony-local-containment-workspaces";
        const auto outside = temporary / "symphony-local-containment-outside";
        std::filesystem::remove_all(root);
        std::filesystem::remove_all(outside);
        std::filesystem::create_directories(outside);
        const auto sentinel = outside / "keep";
        std::ofstream{sentinel} << "outside";

        symphony::workspace::LocalWorkspaceExecutor executor(root);
        const symphony::domain::Issue issue{
            "id-local-containment", "SYM-LOCAL-CONTAINMENT", "", "Todo", {}};
        const auto workspace = executor.create(issue);
        const symphony::workspace::Workspace forged{
            root / ".." / outside.filename(), issue.id, false};
        ut::expect(ut::throws([&] {
          executor.run_hook(forged, "before_run", {"/usr/bin/touch", "escaped"},
                            std::chrono::seconds{1});
        }));
        ut::expect(ut::throws([&] { executor.remove(forged); }));

        std::filesystem::remove_all(workspace.path);
        std::filesystem::create_directory_symlink(outside, workspace.path);
        ut::expect(ut::throws([&] {
          executor.run_hook(workspace, "before_run",
                            {"/usr/bin/touch", "escaped"},
                            std::chrono::seconds{1});
        }));
        ut::expect(ut::throws([&] { executor.remove(workspace); }));
        ut::expect(std::filesystem::exists(sentinel));
        ut::expect(!std::filesystem::exists(outside / "escaped"));

        std::filesystem::remove(workspace.path);
        std::filesystem::remove_all(root);
        std::filesystem::remove_all(outside);
      };
};
