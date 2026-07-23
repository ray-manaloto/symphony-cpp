#include <filesystem>
#include <string>
#include <vector>

#include <boost/asio.hpp>
#include <boost/filesystem/path.hpp>
#include <boost/process/v2/process.hpp>
#include <boost/process/v2/start_dir.hpp>
#include <boost/process/v2/stdio.hpp>
#include <ut/ut.hpp>

namespace {
struct ProcessResult {
  int exit_code{1};
  std::string standard_output;
  std::string standard_error;
};

ProcessResult run_daemon(const std::vector<std::string>& arguments) {
  boost::asio::io_context context;
  boost::asio::readable_pipe standard_output(context);
  boost::asio::readable_pipe standard_error(context);
  boost::process::v2::process child(
      context, SYMPHONYD_PATH, arguments,
      boost::process::v2::process_stdio{
          nullptr, standard_output, standard_error});
  ProcessResult result;
  boost::system::error_code output_status;
  boost::system::error_code error_status;
  boost::asio::read(standard_output,
                    boost::asio::dynamic_buffer(result.standard_output),
                    output_status);
  boost::asio::read(standard_error,
                    boost::asio::dynamic_buffer(result.standard_error),
                    error_status);
  result.exit_code = child.wait();
  return result;
}
}  // namespace

static ut::suite process_tests = [] {
  ut::test("Boost.Process v2 separates stdout stderr and reports pipe EOF") = [] {
    boost::asio::io_context context;
    boost::asio::readable_pipe standard_output(context);
    boost::asio::readable_pipe standard_error(context);
    const auto root = std::filesystem::temp_directory_path() /
                      "symphony-boost-process-stdio-test";
    std::filesystem::remove_all(root);
    std::filesystem::create_directories(root);
    boost::process::v2::process child(
        context,
        "/bin/sh",
        {"-c", "printf stdout; printf stderr >&2; pwd"},
        boost::process::v2::process_start_dir(
            boost::filesystem::path(root.string())),
        boost::process::v2::process_stdio{
            nullptr, standard_output, standard_error});

    std::string output;
    std::string error;
    boost::system::error_code output_status;
    boost::system::error_code error_status;
    boost::asio::read(
        standard_output, boost::asio::dynamic_buffer(output), output_status);
    boost::asio::read(
        standard_error, boost::asio::dynamic_buffer(error), error_status);
    const auto exit_code = child.wait();

    ut::expect(exit_code == 0);
    ut::expect(output.starts_with("stdout"));
    ut::expect(output.find(root.string()) != std::string::npos);
    ut::expect(error == std::string{"stderr"});
    ut::expect(output_status == boost::asio::error::eof);
    ut::expect(error_status == boost::asio::error::eof);
    std::filesystem::remove_all(root);
  };

  ut::test("Boost.Process v2 terminal cancellation reaps a live child") = [] {
    boost::asio::io_context context;
    boost::process::v2::process child(
        context, "/bin/sh", {"-c", "exec sleep 30"});
    ut::expect(child.running());

    child.terminate();
    static_cast<void>(child.wait());

    ut::expect(!child.running());
  };

  ut::test("daemon help exits successfully without starting the service") = [] {
    const auto result = run_daemon({"--help"});
    ut::expect(result.exit_code == 0);
    ut::expect(result.standard_output.find("WORKFLOW.md") !=
               std::string::npos);
    ut::expect(result.standard_error.empty());
  };

  ut::test("daemon invalid CLI exits nonzero with a bounded diagnostic") = [] {
    const auto result = run_daemon({"first.md", "second.md"});
    ut::expect(result.exit_code != 0);
    ut::expect(!result.standard_error.empty());
    ut::expect(result.standard_error.size() < std::size_t{4096});
  };

  ut::test("daemon startup validation exits nonzero without entering its loop") =
      [] {
        const auto result = run_daemon({"/dev/null", "--once"});
        ut::expect(result.exit_code != 0);
        ut::expect(result.standard_output.empty());
        ut::expect(result.standard_error.starts_with("symphonyd:"));
        ut::expect(result.standard_error.size() < std::size_t{4096});
      };
};
