#include "symphony/cli/cli.hpp"

#include <sstream>

#include <CLI/CLI.hpp>

namespace symphony::cli {

DaemonParseResult parse_daemon_arguments(const int argc, char** argv) {
  CLI::App app{
      "Standalone C++26 implementation of OpenAI Symphony Draft v1",
      "symphonyd"};
  std::string positional_workflow;
  std::string named_workflow;
  bool once = false;

  auto* positional = app.add_option(
      "workflow_path", positional_workflow,
      "Path to WORKFLOW.md; defaults to WORKFLOW.md in the current directory");
  auto* named = app.add_option(
      "--workflow", named_workflow,
      "Compatibility alias for the positional workflow path");
  positional->excludes(named);
  app.add_flag("--once", once, "Run one scheduling tick and exit");

  try {
    app.parse(argc, argv);
  } catch (const CLI::ParseError& error) {
    std::ostringstream standard_output;
    std::ostringstream standard_error;
    const auto code = app.exit(error, standard_output, standard_error);
    return std::unexpected(ParseExit{
        code, standard_output.str(), standard_error.str()});
  }

  DaemonOptions options;
  if (!positional_workflow.empty()) {
    options.workflow_path = positional_workflow;
  } else if (!named_workflow.empty()) {
    options.workflow_path = named_workflow;
  }
  options.once = once;
  return options;
}

}  // namespace symphony::cli
