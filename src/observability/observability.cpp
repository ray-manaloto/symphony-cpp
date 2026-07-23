#include "symphony/observability/observability.hpp"
#include "symphony/observability/spdlog_event_store.hpp"

#include <algorithm>
#include <stdexcept>

#include <glaze/glaze.hpp>
#include <spdlog/logger.h>
#include <spdlog/sinks/stdout_sinks.h>

template <>
struct glz::meta<symphony::observability::Event> {
  using T = symphony::observability::Event;
  static constexpr auto value =
      object("type", &T::type, "issue_id", &T::issue_id, "issue_identifier",
             &T::issue_identifier, "session_id", &T::session_id, "message",
             &T::message);
};

namespace symphony::observability {
namespace {
std::shared_ptr<spdlog::logger> make_stderr_logger() {
  return std::make_shared<spdlog::logger>(
      "symphony", std::make_shared<spdlog::sinks::stderr_sink_mt>());
}
}  // namespace

MemoryEventStore::MemoryEventStore(const std::size_t capacity) : capacity_(std::max<std::size_t>(1, capacity)) {}

void MemoryEventStore::append(Event event) {
  events_.push_back(redact(std::move(event)));
  while (events_.size() > capacity_) events_.pop_front();
}

std::vector<Event> MemoryEventStore::recent(const std::size_t limit) const {
  const auto count = std::min(limit, events_.size());
  return {events_.end() - static_cast<std::ptrdiff_t>(count), events_.end()};
}

SpdlogEventStore::SpdlogEventStore(const std::size_t capacity)
    : SpdlogEventStore(make_stderr_logger(), capacity) {}

SpdlogEventStore::SpdlogEventStore(std::shared_ptr<spdlog::logger> logger,
                                   const std::size_t capacity)
    : logger_(std::move(logger)),
      history_(capacity),
      sink_failures_(std::make_shared<std::atomic<std::uint64_t>>(0)) {
  if (!logger_) throw std::invalid_argument("structured logger is required");
  logger_->set_pattern("%v");
  logger_->set_error_handler([failures = sink_failures_](const std::string&) {
    failures->fetch_add(1, std::memory_order_relaxed);
  });
}

void SpdlogEventStore::append(Event event) {
  auto safe = redact(std::move(event));
  history_.append(safe);
  logger_->info("{}", to_json(safe));
}

std::vector<Event> SpdlogEventStore::recent(const std::size_t limit) const {
  return history_.recent(limit);
}

std::uint64_t SpdlogEventStore::sink_failures() const noexcept {
  return sink_failures_->load(std::memory_order_relaxed);
}

Event redact(Event event) {
  std::string lowered = event.message;
  std::ranges::transform(lowered, lowered.begin(), [](const unsigned char value) {
    return static_cast<char>(std::tolower(value));
  });
  for (const std::string_view marker : {"token=", "password", "authorization", "secret="}) {
    if (lowered.find(marker) != std::string::npos) {
      event.message = "[REDACTED]";
      break;
    }
  }
  return event;
}

std::string to_json(const Event& event) {
  auto result = glz::write_json(event);
  if (!result) {
    throw std::runtime_error("Glaze could not serialize an observability event: " +
                             glz::format_error(result.error()));
  }
  return std::move(*result);
}
}  // namespace symphony::observability
