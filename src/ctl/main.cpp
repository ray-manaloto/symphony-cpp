#include <filesystem>
#include <iostream>
#include <string_view>

#include "symphony/workflow/workflow.hpp"

int main(int argc, char** argv) {
  try {
    if (argc < 2)
      throw std::runtime_error("usage: symphonyctl validate PATH | conformance | status");
    const std::string_view command{argv[1]};
    if (command == "validate") {
      if (argc != 3) throw std::runtime_error("usage: symphonyctl validate PATH");
      symphony::workflow::ProcessEnvironment environment;
      const auto document = symphony::workflow::WorkflowLoader{}.load(argv[2], environment);
      symphony::workflow::validate_for_dispatch(document.config, {"fake", "github", "linear"});
      std::cout << "valid " << document.path << " " << document.fingerprint << '\n';
      return 0;
    }
    if (command == "conformance") {
      std::cout << "run ctest --preset gcc-debug; matrix: docs/conformance.md\n";
      return 0;
    }
    if (command == "status") {
      std::cout << "{\"mode\":\"fixture-only\",\"live_mutation\":false}\n";
      return 0;
    }
    throw std::runtime_error("unknown command");
  } catch (const std::exception& error) {
    std::cerr << "symphonyctl: " << error.what() << '\n';
    return 1;
  }
}
