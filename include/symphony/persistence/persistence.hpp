#pragma once

#include <cstddef>
#include <cstdint>
#include <expected>
#include <filesystem>
#include <memory>
#include <string>
#include <string_view>
#include <vector>

namespace symphony::persistence {

enum class ErrorKind { provider, cancelled, overloaded };

struct Error {
  int code{0};
  std::string message;
  ErrorKind kind{ErrorKind::provider};

  friend bool operator==(const Error&, const Error&) = default;
};

struct NewEvent {
  std::uint32_t schema_version{1};
  std::string type;
  std::string issue_id;
  std::string payload;
};

struct Event {
  std::int64_t sequence{0};
  std::uint32_t schema_version{1};
  std::string type;
  std::string issue_id;
  std::string payload;
};

struct AppendCompletion {
  std::string key;
  std::expected<std::int64_t, Error> result;
};

struct RepositoryOptions {
  std::size_t max_pending_appends{64};
};

class EventRepository {
public:
  virtual ~EventRepository() = default;
  [[nodiscard]] virtual std::expected<std::int64_t, Error> append(NewEvent event) = 0;
  [[nodiscard]] virtual std::expected<std::vector<Event>, Error>
  load_after(std::int64_t sequence) = 0;
  [[nodiscard]] virtual std::expected<void, Error> submit_append(std::string key,
                                                                 NewEvent event) = 0;
  [[nodiscard]] virtual bool request_stop(std::string_view key) = 0;
  [[nodiscard]] virtual std::vector<AppendCompletion> take_ready_appends() = 0;
  virtual void drain() = 0;
};

class SqliteEventRepository final : public EventRepository {
public:
  [[nodiscard]] static std::expected<std::unique_ptr<SqliteEventRepository>, Error>
  open(const std::filesystem::path& path, RepositoryOptions options = {});

  ~SqliteEventRepository() override;

  SqliteEventRepository(const SqliteEventRepository&) = delete;
  SqliteEventRepository& operator=(const SqliteEventRepository&) = delete;
  SqliteEventRepository(SqliteEventRepository&&) = delete;
  SqliteEventRepository& operator=(SqliteEventRepository&&) = delete;

  [[nodiscard]] std::expected<std::int64_t, Error> append(NewEvent event) override;
  [[nodiscard]] std::expected<std::vector<Event>, Error> load_after(std::int64_t sequence) override;
  [[nodiscard]] std::expected<void, Error> submit_append(std::string key, NewEvent event) override;
  [[nodiscard]] bool request_stop(std::string_view key) override;
  [[nodiscard]] std::vector<AppendCompletion> take_ready_appends() override;
  void drain() override;

private:
  struct Impl;
  explicit SqliteEventRepository(std::unique_ptr<Impl> impl);

  std::unique_ptr<Impl> impl_;
};

} // namespace symphony::persistence
