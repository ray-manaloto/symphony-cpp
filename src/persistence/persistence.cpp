#include "symphony/persistence/persistence.hpp"

#include <atomic>
#include <exception>
#include <functional>
#include <future>
#include <mutex>
#include <stdexcept>
#include <system_error>
#include <tuple>
#include <type_traits>
#include <utility>

#include <boost/sqlite/connection.hpp>
#include <boost/sqlite/query.hpp>
#include <boost/sqlite/transaction.hpp>
#include <boost/system/system_error.hpp>

#include "symphony/execution/execution.hpp"

namespace symphony::persistence {
namespace sqlite = boost::sqlite;

struct SqliteEventRepository::Impl {
  sqlite::connection connection;
  execution::StdexecTaskExecutor tasks{1};
  std::atomic<std::uint64_t> next_operation{1};
  std::mutex completion_mutex;
  std::vector<AppendCompletion> append_completions;
};

namespace {

Error current_error() {
  try {
    throw;
  } catch (const boost::system::system_error &error) {
    return Error{error.code().value(), error.what()};
  } catch (const std::exception &error) {
    return Error{0, error.what()};
  } catch (...) {
    return Error{0, "persistence operation failed"};
  }
}

Error cancellation_error() {
  return Error{
      .code = std::make_error_code(std::errc::operation_canceled).value(),
      .message = "persistence operation cancelled",
      .kind = ErrorKind::cancelled,
  };
}

template <typename Impl>
std::expected<std::int64_t, Error> append_event(Impl &impl, NewEvent event) {
  try {
    sqlite::transaction transaction{impl.connection};
    impl.connection
        .prepare("INSERT INTO symphony_events("
                 "schema_version, type, issue_id, payload"
                 ") VALUES (?1, ?2, ?3, ?4)")
        .execute(
            {event.schema_version, event.type, event.issue_id, event.payload});
    const auto sequence = static_cast<std::int64_t>(
        sqlite3_last_insert_rowid(impl.connection.handle()));
    transaction.commit();
    return sequence;
  } catch (...) {
    return std::unexpected(current_error());
  }
}

template <typename Impl, typename Function>
auto on_database(Impl &impl, Function &&function)
    -> std::invoke_result_t<Function> {
  using Result = std::invoke_result_t<Function>;
  std::promise<Result> promise;
  auto future = promise.get_future();
  const auto operation =
      "persistence-sync-" + std::to_string(impl.next_operation.fetch_add(1));
  impl.tasks.submit(operation, [function = std::forward<Function>(function),
                                promise = std::move(promise)](
                                   std::stop_token) mutable noexcept {
    try {
      promise.set_value(function());
    } catch (...) {
      promise.set_exception(std::current_exception());
    }
  });
  return future.get();
}

} // namespace

SqliteEventRepository::SqliteEventRepository(std::unique_ptr<Impl> impl)
    : impl_(std::move(impl)) {}

std::expected<std::unique_ptr<SqliteEventRepository>, Error>
SqliteEventRepository::open(const std::filesystem::path &path) {
  auto repository = std::unique_ptr<SqliteEventRepository>(
      new SqliteEventRepository(std::make_unique<Impl>()));
  auto initialized = on_database(
      *repository->impl_,
      [impl = repository->impl_.get(),
       filename = path.string()]() -> std::expected<void, Error> {
        try {
          impl->connection.connect(filename);
          impl->connection.execute(
              "PRAGMA journal_mode=WAL;"
              "PRAGMA foreign_keys=ON;"
              "PRAGMA busy_timeout=5000;"
              "CREATE TABLE IF NOT EXISTS symphony_events("
              "  sequence INTEGER PRIMARY KEY AUTOINCREMENT,"
              "  schema_version INTEGER NOT NULL CHECK(schema_version > 0),"
              "  type TEXT NOT NULL,"
              "  issue_id TEXT NOT NULL,"
              "  payload TEXT NOT NULL"
              ");");
          return {};
        } catch (...) {
          return std::unexpected(current_error());
        }
      });
  if (!initialized)
    return std::unexpected(std::move(initialized.error()));
  return repository;
}

SqliteEventRepository::~SqliteEventRepository() {
  if (!impl_ || !impl_->connection.valid())
    return;
  static_cast<void>(on_database(*impl_, [impl = impl_.get()] {
    try {
      impl->connection.close();
    } catch (...) {
    }
    return 0;
  }));
}

std::expected<std::int64_t, Error>
SqliteEventRepository::append(NewEvent event) {
  return on_database(*impl_,
                     [impl = impl_.get(), event = std::move(event)]()
                         -> std::expected<std::int64_t, Error> {
                       return append_event(*impl, std::move(event));
                     });
}

std::expected<std::vector<Event>, Error>
SqliteEventRepository::load_after(const std::int64_t sequence) {
  return on_database(
      *impl_,
      [impl = impl_.get(),
       sequence]() -> std::expected<std::vector<Event>, Error> {
        try {
          std::vector<Event> events;
          using Row = std::tuple<sqlite3_int64, sqlite3_int64, std::string,
                                 std::string, std::string>;
          for (auto &&[row_sequence, schema_version, type, issue_id, payload] :
               sqlite::query<Row>(
                   impl->connection,
                   "SELECT sequence, schema_version, type, issue_id, payload "
                   "FROM symphony_events WHERE sequence > ?1 "
                   "ORDER BY sequence ASC",
                   {sequence})) {
            events.push_back(Event{
                .sequence = static_cast<std::int64_t>(row_sequence),
                .schema_version = static_cast<std::uint32_t>(schema_version),
                .type = std::move(type),
                .issue_id = std::move(issue_id),
                .payload = std::move(payload),
            });
          }
          return events;
        } catch (...) {
          return std::unexpected(current_error());
        }
      });
}

void SqliteEventRepository::submit_append(std::string key, NewEvent event) {
  if (key.empty())
    throw std::invalid_argument("persistence operation key must not be empty");
  const auto execution_key = "persistence-async:" + key;
  impl_->tasks.submit(
      execution_key,
      [impl = impl_.get(), key = std::move(key), event = std::move(event)](
          const std::stop_token stop_token) mutable noexcept {
        auto result = stop_token.stop_requested()
                          ? std::expected<std::int64_t, Error>{std::unexpected(
                                cancellation_error())}
                          : append_event(*impl, std::move(event));
        const std::scoped_lock lock(impl->completion_mutex);
        impl->append_completions.push_back(
            AppendCompletion{std::move(key), std::move(result)});
      });
}

bool SqliteEventRepository::request_stop(const std::string_view key) {
  return impl_->tasks.request_stop("persistence-async:" + std::string{key});
}

std::vector<AppendCompletion> SqliteEventRepository::take_ready_appends() {
  const std::scoped_lock lock(impl_->completion_mutex);
  return std::exchange(impl_->append_completions,
                       std::vector<AppendCompletion>{});
}

void SqliteEventRepository::drain() { impl_->tasks.drain(); }

} // namespace symphony::persistence
