#include <ut/ut.hpp>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <filesystem>
#include <mutex>
#include <string>
#include <string_view>
#include <system_error>
#include <thread>
#include <vector>

#include <boost/sqlite/connection.hpp>

#include "symphony/persistence/persistence.hpp"

namespace {

class FixtureDatabase {
public:
  explicit FixtureDatabase(std::string_view name)
      : path_(
            std::filesystem::temp_directory_path() /
            ("symphony-" + std::string{name} + "-" +
             std::to_string(
                 std::chrono::steady_clock::now().time_since_epoch().count()) +
             ".sqlite3")) {}

  ~FixtureDatabase() {
    std::error_code ignored;
    std::filesystem::remove(path_, ignored);
    std::filesystem::remove(path_.string() + "-shm", ignored);
    std::filesystem::remove(path_.string() + "-wal", ignored);
  }

  [[nodiscard]] const std::filesystem::path &path() const noexcept {
    return path_;
  }

private:
  std::filesystem::path path_;
};

} // namespace

static ut::suite persistence_tests = [] {
  ut::test(
      "sqlite event repository survives restart with explicit envelopes") = [] {
    FixtureDatabase fixture{"restart"};
    {
      auto opened =
          symphony::persistence::SqliteEventRepository::open(fixture.path());
      ut::expect(opened.has_value());
      if (!opened)
        return;

      auto rejected = (*opened)->append({
          .schema_version = 0,
          .type = "invalid",
          .issue_id = "fixture-1",
          .payload = "{}",
      });
      ut::expect(!rejected.has_value());
      if (!rejected)
        ut::expect(!rejected.error().message.empty());

      auto sequence = (*opened)->append({
          .schema_version = 1,
          .type = "attempt_started",
          .issue_id = "fixture-1",
          .payload = R"({"attempt":1})",
      });
      ut::expect(sequence.has_value());
      if (sequence)
        ut::expect(*sequence == 1);
    }

    auto reopened =
        symphony::persistence::SqliteEventRepository::open(fixture.path());
    ut::expect(reopened.has_value());
    if (!reopened)
      return;

    auto events = (*reopened)->load_after(0);
    ut::expect(events.has_value());
    if (!events)
      return;
    ut::expect(events->size() == std::size_t{1});
    if (events->size() != 1)
      return;
    ut::expect(events->front().sequence == 1);
    ut::expect(events->front().schema_version == std::uint32_t{1});
    ut::expect(events->front().type == "attempt_started");
    ut::expect(events->front().issue_id == "fixture-1");
    ut::expect(events->front().payload == R"({"attempt":1})");
  };

  ut::test("sqlite event repository serializes concurrent appends") = [] {
    FixtureDatabase fixture{"serialized"};
    auto opened =
        symphony::persistence::SqliteEventRepository::open(fixture.path());
    ut::expect(opened.has_value());
    if (!opened)
      return;

    constexpr std::size_t append_count = 12;
    std::mutex result_mutex;
    std::vector<std::int64_t> sequences;
    std::vector<symphony::persistence::Error> errors;
    std::vector<std::jthread> callers;
    callers.reserve(append_count);

    for (std::size_t index = 0; index < append_count; ++index) {
      callers.emplace_back([&, index] {
        auto result = (*opened)->append({
            .schema_version = 1,
            .type = "fixture",
            .issue_id = "fixture-" + std::to_string(index),
            .payload = "{}",
        });
        const std::scoped_lock lock(result_mutex);
        if (result) {
          sequences.push_back(*result);
        } else {
          errors.push_back(result.error());
        }
      });
    }
    callers.clear();

    ut::expect(errors.empty());
    ut::expect(sequences.size() == append_count);
    std::ranges::sort(sequences);
    for (std::size_t index = 0; index < sequences.size(); ++index) {
      ut::expect(sequences[index] == static_cast<std::int64_t>(index + 1));
    }

    auto events = (*opened)->load_after(0);
    ut::expect(events.has_value());
    if (events)
      ut::expect(events->size() == append_count);
  };

  ut::test("sqlite event repository cancels a queued append while busy") = [] {
    FixtureDatabase fixture{"cancelled"};
    auto opened =
        symphony::persistence::SqliteEventRepository::open(fixture.path());
    ut::expect(opened.has_value());
    if (!opened)
      return;

    boost::sqlite::connection blocker{fixture.path().string()};
    blocker.execute("BEGIN IMMEDIATE");

    (*opened)->submit_append(
        "first",
        {
            .schema_version = 1,
            .type = "fixture",
            .issue_id = "fixture-first",
            .payload = "{}",
        });
    (*opened)->submit_append(
        "cancelled",
        {
            .schema_version = 1,
            .type = "fixture",
            .issue_id = "fixture-cancelled",
            .payload = "{}",
        });
    ut::expect((*opened)->request_stop("cancelled"));
    blocker.execute("ROLLBACK");

    (*opened)->drain();
    auto completions = (*opened)->take_ready_appends();
    ut::expect(completions.size() == std::size_t{2});
    const auto first =
        std::ranges::find_if(completions, [](const auto &completion) {
          return completion.key == "first";
        });
    const auto cancelled =
        std::ranges::find_if(completions, [](const auto &completion) {
          return completion.key == "cancelled";
        });
    ut::expect(first != completions.end());
    ut::expect(cancelled != completions.end());
    if (first != completions.end())
      ut::expect(first->result.has_value());
    if (cancelled != completions.end()) {
      ut::expect(!cancelled->result.has_value());
      if (!cancelled->result) {
        ut::expect(cancelled->result.error().kind ==
                   symphony::persistence::ErrorKind::cancelled);
        ut::expect(cancelled->result.error().code ==
                   std::make_error_code(std::errc::operation_canceled).value());
      }
    }

    auto events = (*opened)->load_after(0);
    ut::expect(events.has_value());
    if (events) {
      ut::expect(events->size() == std::size_t{1});
      if (events->size() == 1)
        ut::expect(events->front().issue_id == "fixture-first");
    }
  };
};
