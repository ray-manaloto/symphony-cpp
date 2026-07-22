#include "symphony/observability/observability.hpp"
#include "test.hpp"

TEST("event store bounds history and redacts sensitive message data") {
  symphony::observability::MemoryEventStore store(2);
  store.append({"one", "1", "SYM-1", "s1", "token=abc"});
  store.append({"two", "2", "SYM-2", "s2", "safe"});
  store.append({"three", "3", "SYM-3", "s3", "password: nope"});
  const auto events = store.recent(10);
  REQUIRE_EQ(events.size(), std::size_t{2});
  REQUIRE_EQ(events.back().message, std::string{"[REDACTED]"});
  const auto json = symphony::observability::to_json(events.back());
  REQUIRE(json.find("issue_identifier") != std::string::npos);
  REQUIRE(json.find("nope") == std::string::npos);
}

