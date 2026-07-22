#include "symphony/domain/domain.hpp"
#include "test.hpp"

using namespace std::chrono_literals;
using namespace symphony::domain;

TEST("fingerprints are order-stable for set-like progress fields") {
  const auto first = fingerprint({"working", "tests", {"b.cpp", "a.cpp"}, {"unit", "lint"}});
  const auto second = fingerprint({"working", "tests", {"a.cpp", "b.cpp"}, {"lint", "unit"}});
  REQUIRE_EQ(first, second);
}

TEST("first unchanged progress gets exactly one corrective continuation") {
  Attempt attempt;
  const auto current = fingerprint({"same", "step", {"file.cpp"}, {"unit"}});
  REQUIRE_EQ(observe_progress(attempt, current), ProgressDecision::progressed);
  REQUIRE_EQ(observe_progress(attempt, current), ProgressDecision::corrective_continuation);
  REQUIRE_EQ(attempt.corrective_continuations, 1U);
  REQUIRE_EQ(attempt.context_state, ContextState::corrective_continuation);
}

TEST("second unchanged progress stalls the attempt") {
  Attempt attempt;
  const auto current = fingerprint({"same", "step", {}, {}});
  static_cast<void>(observe_progress(attempt, current));
  static_cast<void>(observe_progress(attempt, current));
  REQUIRE_EQ(observe_progress(attempt, current), ProgressDecision::stalled_no_progress);
  REQUIRE_EQ(attempt.context_state, ContextState::stalled_no_progress);
}

TEST("new progress resets the unchanged counter") {
  Attempt attempt;
  const auto first = fingerprint({"one", "step", {}, {}});
  const auto second = fingerprint({"two", "step", {}, {}});
  static_cast<void>(observe_progress(attempt, first));
  static_cast<void>(observe_progress(attempt, first));
  REQUIRE_EQ(observe_progress(attempt, second), ProgressDecision::progressed);
  REQUIRE_EQ(attempt.unchanged_results, 0U);
}

TEST("retry delay grows exponentially and caps") {
  REQUIRE_EQ(retry_delay(0, 1s, 5s), 1s);
  REQUIRE_EQ(retry_delay(2, 1s, 5s), 4s);
  REQUIRE_EQ(retry_delay(30, 1s, 5s), 5s);
}

