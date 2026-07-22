#include "symphony/observability/observability.hpp"

#include <algorithm>
#include <sstream>

#include "symphony/meta/meta.hpp"

namespace symphony::observability {
MemoryEventStore::MemoryEventStore(const std::size_t capacity) : capacity_(std::max<std::size_t>(1, capacity)) {}

void MemoryEventStore::append(Event event) {
  events_.push_back(redact(std::move(event)));
  while (events_.size() > capacity_) events_.pop_front();
}

std::vector<Event> MemoryEventStore::recent(const std::size_t limit) const {
  const auto count = std::min(limit, events_.size());
  return {events_.end() - static_cast<std::ptrdiff_t>(count), events_.end()};
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
  std::ostringstream output;
  output << "{\"type\":\"" << meta::json_escape(event.type)
         << "\",\"issue_id\":\"" << meta::json_escape(event.issue_id)
         << "\",\"issue_identifier\":\"" << meta::json_escape(event.issue_identifier)
         << "\",\"session_id\":\"" << meta::json_escape(event.session_id)
         << "\",\"message\":\"" << meta::json_escape(event.message) << "\"}";
  return output.str();
}
}  // namespace symphony::observability

