#include <filesystem>
#include <string>

#include <boost/asio.hpp>
#include <boost/process/v2/process.hpp>
#include <boost/process/v2/start_dir.hpp>
#include <boost/process/v2/stdio.hpp>
#include <ut/ut.hpp>

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
        boost::process::v2::process_start_dir(root),
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
};
