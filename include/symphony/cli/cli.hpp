#pragma once

#include <expected>
#include <filesystem>
#include <optional>
#include <string>

namespace symphony::cli {

struct DaemonOptions {
  std::optional<std::filesystem::path> workflow_path;
  bool once{false};
};

struct ParseExit {
  int code{1};
  std::string standard_output;
  std::string standard_error;
};

using DaemonParseResult = std::expected<DaemonOptions, ParseExit>;

[[nodiscard]] DaemonParseResult parse_daemon_arguments(int argc, char** argv);

}  // namespace symphony::cli
