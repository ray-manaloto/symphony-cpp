#include <ut/ut.hpp>

#include "symphony/observability/observability.hpp"

static ut::suite observability_tests = [] {
  ut::test("event store bounds history and redacts sensitive message data") =
      [] {
        symphony::observability::MemoryEventStore store(2);
        store.append({"one", "1", "SYM-1", "s1", "token=abc"});
        store.append({"two", "2", "SYM-2", "s2", "safe"});
        store.append({"three", "3", "SYM-3", "s3", "password: nope"});
        const auto events = store.recent(10);
        ut::expect(events.size() == std::size_t{2});
        ut::expect(events.back().message == std::string{"[REDACTED]"});
        const auto json = symphony::observability::to_json(events.back());
        ut::expect(json.find("issue_identifier") != std::string::npos);
        ut::expect(json.find("nope") == std::string::npos);
      };
};
