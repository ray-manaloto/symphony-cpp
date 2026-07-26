#include <ut/ut.hpp>

#include <string>

#include "symphony/domain/domain.hpp"

using namespace std::chrono_literals;
using namespace symphony::domain;

static ut::suite domain_tests = [] {
  ut::test("fingerprints ignore model-authored progress narrative") = [] {
    const auto first =
        fingerprint({"implemented the feature", "running tests", {"a.cpp"}, {"unit"}});
    const auto second =
        fingerprint({"everything is done", "waiting for review", {"a.cpp"}, {"unit"}});
    ut::expect(first == second);
  };

  ut::test("fingerprints normalize set-like objective progress fields") = [] {
    const auto first =
        fingerprint({"ignored", "ignored", {"b.cpp", "a.cpp", "a.cpp"}, {"unit", "lint", "unit"}});
    const auto second =
        fingerprint({"also ignored", "also ignored", {"a.cpp", "b.cpp"}, {"lint", "unit"}});
    ut::expect(first == second);
  };

  ut::test("fingerprints distinguish changed paths from completed checks") = [] {
    const auto changed_path = fingerprint({"", "", {"same"}, {}});
    const auto completed_check = fingerprint({"", "", {}, {"same"}});
    ut::expect(changed_path != completed_check);
  };

  ut::test("fingerprints change only with objective progress entries") = [] {
    const auto empty = fingerprint({"", "", {}, {}});
    const auto changed_path = fingerprint({"", "", {"a.cpp"}, {}});
    const auto completed_check = fingerprint({"", "", {}, {"unit"}});
    ut::expect(empty != changed_path);
    ut::expect(empty != completed_check);
    ut::expect(changed_path != completed_check);
  };

  ut::test("fingerprints are lowercase SHA-256 hex") = [] {
    const auto value = fingerprint({"ignored", "ignored", {"a.cpp"}, {"unit"}}).value;
    ut::expect(value.size() == std::size_t{64});
    ut::expect(value.find_first_not_of("0123456789abcdef") == std::string::npos);
  };

  ut::test("fingerprints preserve the versioned portable encoding") = [] {
    const auto value = fingerprint({"", "", {"a.cpp"}, {"unit"}}).value;
    ut::expect(value ==
               std::string{"89fd5e5fe8adee4352abbb949116b76a51b705c55c598b189682701bd8c77043"});
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
    const auto second = fingerprint({"two", "step", {"a.cpp"}, {}});
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
