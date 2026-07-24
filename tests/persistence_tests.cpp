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
#include <tuple>
#include <vector>

#include <boost/sqlite/connection.hpp>
#include <boost/sqlite/query.hpp>

#include "symphony/observability/observability.hpp"
#include "symphony/persistence/event_store.hpp"
#include "symphony/persistence/persistence.hpp"

namespace {

class FixtureDatabase {
public:
  explicit FixtureDatabase(std::string_view name)
      : path_(std::filesystem::temp_directory_path() /
              ("symphony-" + std::string{name} + "-" +
               std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()) +
               ".sqlite3")) {}

  ~FixtureDatabase() {
    std::error_code ignored;
    std::filesystem::remove(path_, ignored);
    std::filesystem::remove(path_.string() + "-shm", ignored);
    std::filesystem::remove(path_.string() + "-wal", ignored);
  }

  [[nodiscard]] const std::filesystem::path& path() const noexcept {
    return path_;
  }

private:
  std::filesystem::path path_;
};

} // namespace

static ut::suite persistence_tests = [] {
  ut::test("sqlite event repository survives restart with explicit envelopes") = [] {
    FixtureDatabase fixture{"restart"};
    {
      auto opened = symphony::persistence::SqliteEventRepository::open(fixture.path());
      ut::expect(opened.has_value());
      if (!opened) return;

      auto rejected = (*opened)->append({
          .schema_version = 0,
          .type = "invalid",
          .issue_id = "fixture-1",
          .payload = "{}",
      });
      ut::expect(!rejected.has_value());
      if (!rejected) ut::expect(!rejected.error().message.empty());

      auto sequence = (*opened)->append({
          .schema_version = 1,
          .type = "attempt_started",
          .issue_id = "fixture-1",
          .payload = R"({"attempt":1})",
      });
      ut::expect(sequence.has_value());
      if (sequence) ut::expect(*sequence == 1);
    }

    auto reopened = symphony::persistence::SqliteEventRepository::open(fixture.path());
    ut::expect(reopened.has_value());
    if (!reopened) return;

    auto events = (*reopened)->load_after(0);
    ut::expect(events.has_value());
    if (!events) return;
    ut::expect(events->size() == std::size_t{1});
    if (events->size() != 1) return;
    ut::expect(events->front().sequence == 1);
    ut::expect(events->front().schema_version == std::uint32_t{1});
    ut::expect(events->front().type == "attempt_started");
    ut::expect(events->front().issue_id == "fixture-1");
    ut::expect(events->front().payload == R"({"attempt":1})");
  };

  ut::test("sqlite event repository serializes concurrent appends") = [] {
    FixtureDatabase fixture{"serialized"};
    auto opened = symphony::persistence::SqliteEventRepository::open(fixture.path());
    ut::expect(opened.has_value());
    if (!opened) return;

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
    if (events) ut::expect(events->size() == append_count);
  };

  ut::test("sqlite event repository cancels an async append before mutation while busy") = [] {
    FixtureDatabase fixture{"cancelled"};
    auto opened = symphony::persistence::SqliteEventRepository::open(fixture.path());
    ut::expect(opened.has_value());
    if (!opened) return;

    boost::sqlite::connection blocker{fixture.path().string()};
    blocker.execute("BEGIN IMMEDIATE");

    auto first_submission = (*opened)->submit_append("first", {
                                                                  .schema_version = 1,
                                                                  .type = "fixture",
                                                                  .issue_id = "fixture-first",
                                                                  .payload = "{}",
                                                              });
    auto cancelled_submission =
        (*opened)->submit_append("cancelled", {
                                                  .schema_version = 1,
                                                  .type = "fixture",
                                                  .issue_id = "fixture-cancelled",
                                                  .payload = "{}",
                                              });
    ut::expect(first_submission.has_value());
    ut::expect(cancelled_submission.has_value());
    ut::expect((*opened)->request_stop("cancelled"));
    blocker.execute("ROLLBACK");

    (*opened)->drain();
    auto completions = (*opened)->take_ready_appends();
    ut::expect(completions.size() == std::size_t{2});
    const auto first = std::ranges::find_if(
        completions, [](const auto& completion) { return completion.key == "first"; });
    const auto cancelled = std::ranges::find_if(
        completions, [](const auto& completion) { return completion.key == "cancelled"; });
    ut::expect(first != completions.end());
    ut::expect(cancelled != completions.end());
    if (first != completions.end()) ut::expect(first->result.has_value());
    if (cancelled != completions.end()) {
      ut::expect(!cancelled->result.has_value());
      if (!cancelled->result) {
        ut::expect(cancelled->result.error().kind == symphony::persistence::ErrorKind::cancelled);
        ut::expect(cancelled->result.error().code ==
                   std::make_error_code(std::errc::operation_canceled).value());
      }
    }

    auto events = (*opened)->load_after(0);
    ut::expect(events.has_value());
    if (events) {
      ut::expect(events->size() == std::size_t{1});
      if (events->size() == 1) ut::expect(events->front().issue_id == "fixture-first");
    }
  };

  ut::test("sqlite event repository rejects work above its queue bound") = [] {
    FixtureDatabase fixture{"bounded"};
    auto opened = symphony::persistence::SqliteEventRepository::open(fixture.path(),
                                                                     {.max_pending_appends = 1});
    ut::expect(opened.has_value());
    if (!opened) return;

    boost::sqlite::connection blocker{fixture.path().string()};
    blocker.execute("BEGIN IMMEDIATE");

    auto accepted = (*opened)->submit_append("accepted", {
                                                             .schema_version = 1,
                                                             .type = "fixture",
                                                             .issue_id = "fixture-accepted",
                                                             .payload = "{}",
                                                         });
    auto overloaded = (*opened)->submit_append("overloaded", {
                                                                 .schema_version = 1,
                                                                 .type = "fixture",
                                                                 .issue_id = "fixture-overloaded",
                                                                 .payload = "{}",
                                                             });

    ut::expect(accepted.has_value());
    ut::expect(!overloaded.has_value());
    if (!overloaded)
      ut::expect(overloaded.error().kind == symphony::persistence::ErrorKind::overloaded);

    blocker.execute("ROLLBACK");
    (*opened)->drain();
    auto completions = (*opened)->take_ready_appends();
    ut::expect(completions.size() == std::size_t{1});
    if (completions.size() == 1) ut::expect(completions.front().key == "accepted");

    auto after_drain =
        (*opened)->submit_append("after-drain", {
                                                    .schema_version = 1,
                                                    .type = "fixture",
                                                    .issue_id = "fixture-after-drain",
                                                    .payload = "{}",
                                                });
    ut::expect(after_drain.has_value());
    (*opened)->drain();
    completions = (*opened)->take_ready_appends();
    ut::expect(completions.size() == std::size_t{1});
    if (completions.size() == 1) ut::expect(completions.front().key == "after-drain");

    auto events = (*opened)->load_after(0);
    ut::expect(events.has_value());
    if (events) ut::expect(events->size() == std::size_t{2});
  };

  ut::test("sqlite event repository owns an explicit schema version") = [] {
    FixtureDatabase fresh_fixture{"schema-version"};
    {
      auto opened = symphony::persistence::SqliteEventRepository::open(fresh_fixture.path());
      ut::expect(opened.has_value());
    }

    boost::sqlite::connection inspected{fresh_fixture.path().string()};
    sqlite3_int64 schema_version = 0;
    for (const auto& [version] :
         boost::sqlite::query<std::tuple<sqlite3_int64>>(inspected, "PRAGMA user_version")) {
      schema_version = version;
    }
    ut::expect(schema_version == sqlite3_int64{1});
    inspected.close();

    FixtureDatabase future_fixture{"future-schema"};
    {
      boost::sqlite::connection future{future_fixture.path().string()};
      future.execute("PRAGMA user_version=2");
    }
    auto rejected = symphony::persistence::SqliteEventRepository::open(future_fixture.path());
    ut::expect(!rejected.has_value());
    if (!rejected) ut::expect(rejected.error().message.find("schema version") != std::string::npos);

    FixtureDatabase legacy_fixture{"legacy-schema"};
    {
      boost::sqlite::connection legacy{legacy_fixture.path().string()};
      legacy.execute("CREATE TABLE symphony_events("
                     "  sequence INTEGER PRIMARY KEY AUTOINCREMENT,"
                     "  schema_version INTEGER NOT NULL CHECK(schema_version > 0),"
                     "  type TEXT NOT NULL,"
                     "  issue_id TEXT NOT NULL,"
                     "  payload TEXT NOT NULL"
                     ");"
                     "INSERT INTO symphony_events("
                     "  schema_version, type, issue_id, payload"
                     ") VALUES (1, 'legacy', 'fixture-legacy', '{}')");
    }
    auto migrated = symphony::persistence::SqliteEventRepository::open(legacy_fixture.path());
    ut::expect(migrated.has_value());
    if (migrated) {
      auto events = (*migrated)->load_after(0);
      ut::expect(events.has_value());
      if (events) {
        ut::expect(events->size() == std::size_t{1});
        if (events->size() == 1) ut::expect(events->front().issue_id == "fixture-legacy");
      }
    }
  };

  ut::test("durable event store persists only the redacted event") = [] {
    FixtureDatabase fixture{"durable-events"};
    auto opened = symphony::persistence::SqliteEventRepository::open(fixture.path());
    ut::expect(opened.has_value());
    if (!opened) return;

    symphony::observability::MemoryEventStore memory;
    symphony::persistence::DurableEventStore events{memory, **opened};
    const auto sensitive_value = std::string{"fixture-"} + "sensitive-value";
    events.append({
        .type = "worker_process_diagnostic",
        .issue_id = "fixture-1",
        .issue_identifier = "SYM-1",
        .session_id = "session-1",
        .message = "token=" + sensitive_value,
    });
    events.drain();

    const auto recent = events.recent(1);
    ut::expect(recent.size() == std::size_t{1});
    if (recent.size() == 1) ut::expect(recent.front().message == "[REDACTED]");
    ut::expect(events.persistence_failures() == std::uint64_t{0});

    auto durable = (*opened)->load_after(0);
    ut::expect(durable.has_value());
    if (durable) {
      ut::expect(durable->size() == std::size_t{1});
      if (durable->size() == 1) {
        ut::expect(durable->front().type == "worker_process_diagnostic");
        ut::expect(durable->front().issue_id == "fixture-1");
        ut::expect(durable->front().payload.find("[REDACTED]") != std::string::npos);
        ut::expect(durable->front().payload.find(sensitive_value) == std::string::npos);
      }
    }
  };

  ut::test("durable event store retains events when persistence overloads") = [] {
    FixtureDatabase fixture{"durable-overload"};
    auto opened = symphony::persistence::SqliteEventRepository::open(fixture.path(),
                                                                     {.max_pending_appends = 0});
    ut::expect(opened.has_value());
    if (!opened) return;

    symphony::observability::MemoryEventStore memory;
    symphony::persistence::DurableEventStore events{memory, **opened};
    events.append({
        .type = "dispatch",
        .issue_id = "fixture-1",
        .issue_identifier = "SYM-1",
        .session_id = "",
        .message = "retained",
    });
    events.drain();

    ut::expect(events.recent(1).size() == std::size_t{1});
    ut::expect(events.persistence_failures() == std::uint64_t{1});
    auto durable = (*opened)->load_after(0);
    ut::expect(durable.has_value());
    if (durable) ut::expect(durable->empty());
  };
};
