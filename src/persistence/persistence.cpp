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
constexpr sqlite3_int64 current_schema_version = 1;

struct SqliteEventRepository::Impl {
  explicit Impl(const std::size_t max_pending)
      : max_pending_appends(max_pending) {}

  sqlite::connection connection;
  execution::StdexecTaskExecutor tasks{1};
  std::atomic<std::uint64_t> next_operation{1};
  std::atomic<std::size_t> pending_appends{0};
  std::size_t max_pending_appends;
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

Error overload_error() {
  return Error{
      .code = std::make_error_code(std::errc::resource_unavailable_try_again)
                  .value(),
      .message = "persistence append queue is full",
      .kind = ErrorKind::overloaded,
  };
}

template <typename Impl> bool acquire_append_slot(Impl &impl) noexcept {
  auto pending = impl.pending_appends.load(std::memory_order_relaxed);
  while (pending < impl.max_pending_appends) {
    if (impl.pending_appends.compare_exchange_weak(
            pending, pending + 1, std::memory_order_relaxed))
      return true;
  }
  return false;
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
SqliteEventRepository::open(const std::filesystem::path &path,
                            const RepositoryOptions options) {
  auto repository = std::unique_ptr<SqliteEventRepository>(
      new SqliteEventRepository(
          std::make_unique<Impl>(options.max_pending_appends)));
  auto initialized = on_database(
      *repository->impl_,
      [impl = repository->impl_.get(),
       filename = path.string()]() -> std::expected<void, Error> {
        try {
          impl->connection.connect(filename);
          sqlite3_int64 schema_version = 0;
          for (const auto &[version] :
               sqlite::query<std::tuple<sqlite3_int64>>(
                   impl->connection, "PRAGMA user_version")) {
            schema_version = version;
          }
          if (schema_version > current_schema_version) {
            throw std::runtime_error(
                "database schema version " +
                std::to_string(schema_version) +
                " is newer than supported version " +
                std::to_string(current_schema_version));
          }

          impl->connection.execute(
              "PRAGMA journal_mode=WAL;"
              "PRAGMA foreign_keys=ON;"
              "PRAGMA busy_timeout=5000;");
          if (schema_version < current_schema_version) {
            sqlite::transaction migration{impl->connection};
            impl->connection.execute(
                "CREATE TABLE IF NOT EXISTS symphony_events("
                "  sequence INTEGER PRIMARY KEY AUTOINCREMENT,"
                "  schema_version INTEGER NOT NULL CHECK(schema_version > 0),"
                "  type TEXT NOT NULL,"
                "  issue_id TEXT NOT NULL,"
                "  payload TEXT NOT NULL"
                ");"
                "PRAGMA user_version=1;");
            migration.commit();
          }
          impl->connection.execute(
              "SELECT sequence, schema_version, type, issue_id, payload "
              "FROM symphony_events LIMIT 0");
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

std::expected<void, Error>
SqliteEventRepository::submit_append(std::string key, NewEvent event) {
  if (key.empty())
    throw std::invalid_argument("persistence operation key must not be empty");
  const auto execution_key = "persistence-async:" + key;
  if (!acquire_append_slot(*impl_))
    return std::unexpected(overload_error());

  try {
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
          impl->pending_appends.fetch_sub(1, std::memory_order_relaxed);
        });
  } catch (...) {
    impl_->pending_appends.fetch_sub(1, std::memory_order_relaxed);
    return std::unexpected(current_error());
  }
  return {};
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
