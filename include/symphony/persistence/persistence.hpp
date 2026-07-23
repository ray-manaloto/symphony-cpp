#pragma once

#include <cstdint>
#include <expected>
#include <filesystem>
#include <memory>
#include <string>
#include <vector>

namespace symphony::persistence {

struct Error {
  int code{0};
  std::string message;

  friend bool operator==(const Error &, const Error &) = default;
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

class EventRepository {
public:
  virtual ~EventRepository() = default;
  [[nodiscard]] virtual std::expected<std::int64_t, Error>
  append(NewEvent event) = 0;
  [[nodiscard]] virtual std::expected<std::vector<Event>, Error>
  load_after(std::int64_t sequence) = 0;
};

class SqliteEventRepository final : public EventRepository {
public:
  [[nodiscard]] static std::expected<std::unique_ptr<SqliteEventRepository>,
                                     Error>
  open(const std::filesystem::path &path);

  ~SqliteEventRepository() override;

  SqliteEventRepository(const SqliteEventRepository &) = delete;
  SqliteEventRepository &operator=(const SqliteEventRepository &) = delete;
  SqliteEventRepository(SqliteEventRepository &&) = delete;
  SqliteEventRepository &operator=(SqliteEventRepository &&) = delete;

  [[nodiscard]] std::expected<std::int64_t, Error>
  append(NewEvent event) override;
  [[nodiscard]] std::expected<std::vector<Event>, Error>
  load_after(std::int64_t sequence) override;

private:
  struct Impl;
  explicit SqliteEventRepository(std::unique_ptr<Impl> impl);

  std::unique_ptr<Impl> impl_;
};

} // namespace symphony::persistence
