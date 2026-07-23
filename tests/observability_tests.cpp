#include <ut/ut.hpp>

#include "symphony/observability/observability.hpp"
#include "symphony/observability/spdlog_event_store.hpp"

#include <memory>
#include <mutex>
#include <sstream>
#include <stdexcept>

#include <spdlog/logger.h>
#include <spdlog/sinks/base_sink.h>
#include <spdlog/sinks/ostream_sink.h>

namespace {
class FailingSink final : public spdlog::sinks::base_sink<std::mutex> {
 protected:
  void sink_it_(const spdlog::details::log_msg&) override {
    throw std::runtime_error("fixture sink failure");
  }

  void flush_() override {}
};
}  // namespace

static ut::suite observability_tests = [] {
  ut::test("event store bounds history and redacts sensitive message data") =
      [] {
        symphony::observability::MemoryEventStore store(2);
        store.append({"one", "1", "SYM-1", "s1", "token=abc"});
        store.append({"two", "2", "SYM-2", "s2", "safe"});
        store.append({"three", "3", "SYM-3", "s3", "password: nope"});
        const auto events = store.recent(10);
        ut::expect(events.size() == std::size_t{2});
        ut::expect(events.back().message == std::string{"[REDACTED]"});
        const auto json = symphony::observability::to_json(events.back());
        ut::expect(json.find("issue_identifier") != std::string::npos);
        ut::expect(json.find("nope") == std::string::npos);
      };

  ut::test("structured event store isolates sink failures") = [] {
    std::ostringstream output;
    auto recording =
        std::make_shared<spdlog::sinks::ostream_sink_mt>(output, true);
    auto logger = std::make_shared<spdlog::logger>(
        "failing-fixture",
        spdlog::sinks_init_list{std::make_shared<FailingSink>(), recording});
    symphony::observability::SpdlogEventStore store(std::move(logger), 2);

    store.append({"worker_failed", "1", "SYM-1", "s1", "token=secret"});

    const auto events = store.recent(10);
    ut::expect(events.size() == std::size_t{1});
    ut::expect(events.front().issue_identifier == std::string{"SYM-1"});
    ut::expect(output.str().find("\"issue_identifier\":\"SYM-1\"") !=
               std::string::npos);
    ut::expect(output.str().find("[REDACTED]") != std::string::npos);
    ut::expect(output.str().find("secret") == std::string::npos);
    ut::expect(store.sink_failures() == std::uint64_t{1});
  };
};
