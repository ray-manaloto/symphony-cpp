#include <ut/ut.hpp>

#include <cstdint>
#include <string>
#include <string_view>

#include "symphony/domain/domain.hpp"

using namespace std::chrono_literals;
using namespace symphony::domain;

namespace {
RepositoryContentEvidence repository_evidence(const std::string_view path,
                                              const char digest_character) {
  return {
      .path = std::string{path},
      .content_digest = std::string(64, digest_character),
  };
}

CommandExecutionEvidence command_evidence(const std::string_view command,
                                          const char digest_character,
                                          const std::int32_t exit_status = 0) {
  return {
      .command = std::string{command},
      .cwd = "/workspace",
      .toolchain = "gcc-16.1",
      .exit_status = exit_status,
      .artifact_digests = {std::string(64, digest_character)},
  };
}
} // namespace

static ut::suite domain_tests = [] {
  ut::test("fingerprints track typed repository and command evidence") = [] {
    const auto repository = repository_evidence("src/domain/domain.cpp", 'a');
    const auto command = command_evidence("ctest --preset gcc-debug", 'b');
    const ProgressSnapshot baseline{"ignored", "ignored", {repository}, {command}};

    auto changed_content = baseline;
    changed_content.repository_content.front().content_digest = std::string(64, 'c');
    auto changed_exit = baseline;
    changed_exit.command_results.front().exit_status = 1;
    auto changed_artifact = baseline;
    changed_artifact.command_results.front().artifact_digests = {std::string(64, 'd')};

    ut::expect(fingerprint(baseline) != fingerprint(changed_content));
    ut::expect(fingerprint(baseline) != fingerprint(changed_exit));
    ut::expect(fingerprint(baseline) != fingerprint(changed_artifact));
  };

  ut::test("fingerprints ignore model-authored progress narrative") = [] {
    const auto repository = repository_evidence("a.cpp", 'a');
    const auto command = command_evidence("unit", 'b');
    const auto first =
        fingerprint({"implemented the feature", "running tests", {repository}, {command}});
    const auto second =
        fingerprint({"everything is done", "waiting for review", {repository}, {command}});
    ut::expect(first == second);
  };

  ut::test("fingerprints normalize set-like objective progress fields") = [] {
    const auto first =
        fingerprint({"ignored",
                     "ignored",
                     {repository_evidence("b.cpp", 'b'), repository_evidence("a.cpp", 'a'),
                      repository_evidence("a.cpp", 'a')},
                     {command_evidence("unit", 'u'), command_evidence("lint", 'l'),
                      command_evidence("unit", 'u')}});
    const auto second =
        fingerprint({"also ignored",
                     "also ignored",
                     {repository_evidence("a.cpp", 'a'), repository_evidence("b.cpp", 'b')},
                     {command_evidence("lint", 'l'), command_evidence("unit", 'u')}});
    ut::expect(first == second);
  };

  ut::test("fingerprints distinguish changed paths from completed checks") = [] {
    const auto changed_path = fingerprint({"", "", {repository_evidence("same", 'a')}, {}});
    const auto completed_check = fingerprint({"", "", {}, {command_evidence("same", 'a')}});
    ut::expect(changed_path != completed_check);
  };

  ut::test("fingerprints change only with objective progress entries") = [] {
    const auto empty = fingerprint({"", "", {}, {}});
    const auto changed_path = fingerprint({"", "", {repository_evidence("a.cpp", 'a')}, {}});
    const auto completed_check = fingerprint({"", "", {}, {command_evidence("unit", 'b')}});
    ut::expect(empty != changed_path);
    ut::expect(empty != completed_check);
    ut::expect(changed_path != completed_check);
  };

  ut::test("fingerprints are lowercase SHA-256 hex") = [] {
    const auto value = fingerprint({"ignored",
                                    "ignored",
                                    {repository_evidence("a.cpp", 'a')},
                                    {command_evidence("unit", 'b')}})
                           .value;
    ut::expect(value.size() == std::size_t{64});
    ut::expect(value.find_first_not_of("0123456789abcdef") == std::string::npos);
  };

  ut::test("fingerprints preserve the versioned portable encoding") = [] {
    const auto value =
        fingerprint({"", "", {repository_evidence("a.cpp", 'a')}, {command_evidence("unit", 'b')}})
            .value;
    ut::expect(value ==
               std::string{"49d4f71f201d1566e44e9134f45e4ee5914bf371108d7a4ee814ba487f075515"});
  };

  ut::test("first unchanged progress gets exactly one corrective continuation") = [] {
    Attempt attempt;
    const auto current = fingerprint(
        {"same", "step", {repository_evidence("file.cpp", 'a')}, {command_evidence("unit", 'b')}});
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
    const auto second = fingerprint({"two", "step", {repository_evidence("a.cpp", 'a')}, {}});
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
