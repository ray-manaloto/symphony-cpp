#pragma once

#include <atomic>
#include <cstdint>
#include <memory>

#include "symphony/observability/observability.hpp"

namespace spdlog {
class logger;
}

namespace symphony::observability {

class SpdlogEventStore final : public EventStore {
public:
  explicit SpdlogEventStore(std::size_t capacity = 512);
  SpdlogEventStore(std::shared_ptr<spdlog::logger> logger, std::size_t capacity = 512);

  void append(Event event) override;
  [[nodiscard]] std::vector<Event> recent(std::size_t limit) const override;
  [[nodiscard]] std::uint64_t sink_failures() const noexcept;

private:
  std::shared_ptr<spdlog::logger> logger_;
  MemoryEventStore history_;
  std::shared_ptr<std::atomic<std::uint64_t>> sink_failures_;
};

} // namespace symphony::observability
