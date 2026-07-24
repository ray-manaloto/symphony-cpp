#include <string>
#include <vector>

#include <ut/ut.hpp>

#include "symphony/cli/cli.hpp"

namespace {
symphony::cli::DaemonParseResult parse(std::vector<std::string> arguments) {
  std::vector<char*> raw;
  raw.reserve(arguments.size());
  for (auto& argument : arguments) raw.push_back(argument.data());
  return symphony::cli::parse_daemon_arguments(static_cast<int>(raw.size()), raw.data());
}
} // namespace

static ut::suite cli_tests = [] {
  ut::test("daemon CLI defaults to cwd workflow and continuous mode") = [] {
    const auto parsed = parse({"symphonyd"});
    ut::expect(parsed.has_value());
    ut::expect(!parsed->workflow_path);
    ut::expect(!parsed->once);
  };

  ut::test("daemon CLI accepts one positional workflow path") = [] {
    const auto parsed = parse({"symphonyd", "config/WORKFLOW.md", "--once"});
    ut::expect(parsed.has_value());
    ut::expect(parsed->workflow_path == std::optional<std::filesystem::path>{"config/WORKFLOW.md"});
    ut::expect(parsed->once);
  };

  ut::test("daemon CLI retains the named workflow compatibility option") = [] {
    const auto parsed = parse({"symphonyd", "--workflow", "legacy/WORKFLOW.md"});
    ut::expect(parsed.has_value());
    ut::expect(parsed->workflow_path == std::optional<std::filesystem::path>{"legacy/WORKFLOW.md"});
  };

  ut::test("daemon CLI rejects conflicting and extra workflow paths") = [] {
    const auto conflicting = parse({"symphonyd", "positional.md", "--workflow", "named.md"});
    ut::expect(!conflicting.has_value());
    ut::expect(conflicting.error().code != 0);

    const auto extra = parse({"symphonyd", "one.md", "two.md"});
    ut::expect(!extra.has_value());
    ut::expect(extra.error().code != 0);
  };

  ut::test("daemon CLI help is a successful parser-owned exit") = [] {
    const auto help = parse({"symphonyd", "--help"});
    ut::expect(!help.has_value());
    ut::expect(help.error().code == 0);
    ut::expect(help.error().standard_output.find("WORKFLOW.md") != std::string::npos);
    ut::expect(help.error().standard_error.empty());
  };
};
