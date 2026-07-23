#include "symphony/persistence/event_store.hpp"

#include <string>
#include <utility>

namespace symphony::persistence {

DurableEventStore::DurableEventStore(
    observability::EventStore& downstream,
    EventRepository& repository)
    : downstream_(downstream), repository_(repository) {}

DurableEventStore::~DurableEventStore() {
  try {
    drain();
  } catch (...) {
    ++persistence_failures_;
  }
}

void DurableEventStore::append(observability::Event event) {
  reap();
  auto safe = observability::redact(std::move(event));
  downstream_.append(safe);

  const auto key =
      "durable-event-" + std::to_string(next_operation_++);
  auto submitted = repository_.submit_append(
      key,
      {
          .schema_version = 1,
          .type = safe.type,
          .issue_id = safe.issue_id,
          .payload = observability::to_json(safe),
      });
  if (!submitted)
    ++persistence_failures_;
}

std::vector<observability::Event>
DurableEventStore::recent(const std::size_t limit) const {
  return downstream_.recent(limit);
}

void DurableEventStore::drain() {
  repository_.drain();
  reap();
}

std::uint64_t DurableEventStore::persistence_failures() const noexcept {
  return persistence_failures_;
}

void DurableEventStore::reap() {
  for (auto& completion : repository_.take_ready_appends()) {
    if (!completion.result)
      ++persistence_failures_;
  }
}

} // namespace symphony::persistence
