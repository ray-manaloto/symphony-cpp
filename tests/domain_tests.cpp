#include <ut/ut.hpp>

#include "symphony/domain/domain.hpp"

using namespace std::chrono_literals;
using namespace symphony::domain;

static ut::suite domain_tests = [] {
  ut::test("fingerprints are order-stable for set-like progress fields") = [] {
    const auto first = fingerprint({"working", "tests", {"b.cpp", "a.cpp"}, {"unit", "lint"}});
    const auto second = fingerprint({"working", "tests", {"a.cpp", "b.cpp"}, {"lint", "unit"}});
    ut::expect(first == second);
  };

  ut::test("first unchanged progress gets exactly one corrective continuation") = [] {
    Attempt attempt;
    const auto current = fingerprint({"same", "step", {"file.cpp"}, {"unit"}});
    ut::expect(observe_progress(attempt, current) == ProgressDecision::progressed);
    ut::expect(observe_progress(attempt, current) == ProgressDecision::corrective_continuation);
    ut::expect(attempt.corrective_continuations == 1U);
    ut::expect(attempt.context_state == ContextState::corrective_continuation);
  };

  ut::test("second unchanged progress stalls the attempt") = [] {
    Attempt attempt;
    const auto current = fingerprint({"same", "step", {}, {}});
    static_cast<void>(observe_progress(attempt, current));
    static_cast<void>(observe_progress(attempt, current));
    ut::expect(observe_progress(attempt, current) == ProgressDecision::stalled_no_progress);
    ut::expect(attempt.context_state == ContextState::stalled_no_progress);
  };

  ut::test("new progress resets the unchanged counter") = [] {
    Attempt attempt;
    const auto first = fingerprint({"one", "step", {}, {}});
    const auto second = fingerprint({"two", "step", {}, {}});
    static_cast<void>(observe_progress(attempt, first));
    static_cast<void>(observe_progress(attempt, first));
    attempt.repeated_failures = 2;
    attempt.last_failure_signature = 42;
    ut::expect(observe_progress(attempt, second) == ProgressDecision::progressed);
    ut::expect(attempt.unchanged_results == 0U);
    ut::expect(attempt.repeated_failures == 0U);
    ut::expect(!attempt.last_failure_signature);
  };

  ut::test("retry delay grows exponentially and caps") = [] {
    ut::expect(retry_delay(0, 1s, 5s) == 1s);
    ut::expect(retry_delay(2, 1s, 5s) == 4s);
    ut::expect(retry_delay(30, 1s, 5s) == 5s);
  };
};
