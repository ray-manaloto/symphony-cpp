#pragma once

#include <cstdint>

#include "symphony/observability/observability.hpp"
#include "symphony/persistence/persistence.hpp"

namespace symphony::persistence {

class DurableEventStore final : public observability::EventStore {
public:
  // The repository's asynchronous append-completion channel must be dedicated
  // to this adapter for its lifetime.
  DurableEventStore(observability::EventStore& downstream, EventRepository& repository);
  ~DurableEventStore() override;

  DurableEventStore(const DurableEventStore&) = delete;
  DurableEventStore& operator=(const DurableEventStore&) = delete;
  DurableEventStore(DurableEventStore&&) = delete;
  DurableEventStore& operator=(DurableEventStore&&) = delete;

  void append(observability::Event event) override;
  [[nodiscard]] std::vector<observability::Event> recent(std::size_t limit) const override;
  void drain();
  [[nodiscard]] std::uint64_t persistence_failures() const noexcept;

private:
  void reap();

  observability::EventStore& downstream_;
  EventRepository& repository_;
  std::uint64_t next_operation_{1};
  std::uint64_t persistence_failures_{0};
};

} // namespace symphony::persistence
