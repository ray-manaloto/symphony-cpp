#pragma once

#include <chrono>
#include <deque>
#include <map>
#include <string>
#include <string_view>
#include <vector>

namespace symphony::observability {

struct Event {
  std::string type;
  std::string issue_id;
  std::string issue_identifier;
  std::string session_id;
  std::string message;
};

class EventStore {
public:
  virtual ~EventStore() = default;
  virtual void append(Event event) = 0;
  [[nodiscard]] virtual std::vector<Event> recent(std::size_t limit) const = 0;
};

class MemoryEventStore final : public EventStore {
public:
  explicit MemoryEventStore(std::size_t capacity = 512);
  void append(Event event) override;
  [[nodiscard]] std::vector<Event> recent(std::size_t limit) const override;

private:
  std::size_t capacity_;
  std::deque<Event> events_;
};

[[nodiscard]] Event redact(Event event);
[[nodiscard]] std::string to_json(const Event& event);

} // namespace symphony::observability
