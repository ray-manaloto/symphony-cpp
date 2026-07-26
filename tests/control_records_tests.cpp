#include <glaze/json/generic.hpp>
#include <ut/ut.hpp>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

#include "symphony/control/records.hpp"

namespace {

using namespace symphony::control;

constexpr std::size_t maximum_record_bytes = 1024 * 1024;

TaskPacketV1 task_packet() {
  return {
      .schema_version = 1,
      .record_kind = "task_packet",
      .identity =
          {
              .packet_id = "packet-001",
              .issue_id = "issue-001",
              .issue_identifier = "CONTROL-RECORDS-001",
              .repository_url = "https://github.com/ray-manaloto/symphony-cpp",
              .worktree = "/workspace/symphony-cpp",
              .branch = "codex/implementation",
              .base_sha = std::string(40, 'a'),
              .plan_digest = std::string(64, 'b'),
              .spec_digest = std::string(64, 'c'),
              .created_at = "2026-07-25T00:00:00Z",
              .expires_at = "2026-07-26T00:00:00Z",
          },
      .role = "executor",
      .objective =
          {
              .observable_contract = "round-trip strict V1 records",
              .acceptance_boundary = "focused schema fixtures pass",
              .atomic_action = "implement the control-record codec",
              .stop_conditions = {"provider cannot express the contract"},
              .split_conditions = {"controller wiring is requested"},
          },
      .authority =
          {
              .read_only = false,
              .tracker_mutation = false,
              .publication = false,
              .deployment = false,
              .allowed_paths = {"include/symphony/control/records.hpp"},
              .denied_paths = {"fixtures/generated"},
              .serialized_paths = {"src/CMakeLists.txt"},
              .resource_keys = {"build/gcc-debug"},
          },
      .dependency =
          {
              .decision_status = "adopted",
              .provider = "Glaze 7.9.0",
              .seam = "symphony::control",
              .decision_record = "docs/dependency-decisions.md",
          },
      .failure_first =
          {
              .fixture_id = "control-records-red-001",
              .focused_command = "ctest --preset gcc-debug -R ^symphony_control_record",
              .expected_initial_outcome = "missing control-record interface",
          },
      .acceptance = {{
          .command = "ctest --preset gcc-debug -R ^symphony_control_record",
          .cwd = "/workspace/symphony-cpp",
          .expected_exit = 0,
          .artifact_path = "build/gcc-debug/tests/symphony_control_records_tests",
          .artifact_digest = std::nullopt,
          .toolchain = "GCC 16.1",
          .commit = std::string(40, 'a'),
      }},
      .review =
          {
              .risk_triggers = {"control policy"},
              .required_kinds = {"normal", "adversarial"},
              .independent_reviewer_required = true,
          },
      .budget =
          {
              .max_turns = 4,
              .max_sessions = 2,
              .deadline_seconds = 5400,
              .no_progress_limit = 1,
              .repeated_failure_limit = 2,
          },
      .model_route =
          {
              .model = "gpt-5.6-sol",
              .effort = "high",
              .reason = "baseline implementation route",
          },
      .checkpoint =
          {
              .notepad_path = ".codex/notepads/root.md",
              .notepad_schema_version = 1,
              .context_telemetry_source = "native exact-turn telemetry",
              .checkpoint_percent = 45,
              .handoff_percent = 50,
              .hard_stop_percent = 55,
              .next_owner = "root",
          },
  };
}

TaskResultV1 task_result() {
  return {
      .schema_version = 1,
      .record_kind = "task_result",
      .packet_id = "packet-001",
      .packet_digest = std::string(64, 'd'),
      .role = "executor",
      .actor_id = "root",
      .session_id = "session-001",
      .role_history_digest = std::string(64, 'e'),
      .repository =
          {
              .repository_url = "https://github.com/ray-manaloto/symphony-cpp",
              .worktree = "/workspace/symphony-cpp",
              .branch = "codex/implementation",
              .base_sha = std::string(40, 'a'),
              .head_sha = std::string(40, 'f'),
          },
      .changed_path_digest = std::string(64, '1'),
      .progress_fingerprint = std::string(64, '2'),
      .command_results = {{
          .command = "ctest --preset gcc-debug",
          .cwd = "/workspace/symphony-cpp",
          .exit_status = 0,
          .toolchain = "GCC 16.1",
          .environment_digest = std::string(64, '3'),
          .redacted_log_digest = std::string(64, '4'),
          .artifact_digests = {std::string(64, '5')},
      }},
      .failure = std::nullopt,
      .files_touched = {"tests/control_records_tests.cpp"},
      .resources_touched = {"build/gcc-debug"},
      .unresolved_risks = {},
      .blockers = {},
      .next_action = "request review",
      .next_owner = "root",
      .notepad_digest = std::string(64, '6'),
      .terminal_reason = "completed",
      .partial = false,
      .redaction_summary = "no secrets or issue content",
  };
}

ReviewAttestationV1 review_attestation() {
  return {
      .schema_version = 1,
      .record_kind = "review_attestation",
      .review_id = "review-001",
      .packet_id = "packet-001",
      .review_kind = "adversarial",
      .reviewer_id = "reviewer-001",
      .reviewer_session_id = "session-review-001",
      .role_history_digest = std::string(64, '7'),
      .independence =
          {
              .designed_change = false,
              .authored_change = false,
              .materially_shaped_change = false,
          },
      .reviewed_sha = std::string(40, 'f'),
      .reviewed_diff_digest = std::string(64, '8'),
      .reviewed_path_digest = std::string(64, '9'),
      .findings = {},
      .required_check_ids = {"symphony_control_records_tests"},
      .required_checks_fresh = true,
      .reviewed_path_bytes_unchanged = true,
      .passed = true,
      .created_at = "2026-07-25T00:00:00Z",
      .redaction_summary = "sanitized",
  };
}

TaskNotepadV1 task_notepad() {
  return {
      .schema_version = 1,
      .record_kind = "task_notepad",
      .task_id = "CONTROL-RECORDS-001",
      .packet_id = "packet-001",
      .objective = "introduce strict versioned control records",
      .constraints = {"records grant no authority"},
      .decisions = {{
          .decision = "use Glaze",
          .evidence_references = {"docs/dependency-decisions.md"},
      }},
      .commands = {{
          .command = "ctest --preset gcc-debug",
          .cwd = "/workspace/symphony-cpp",
          .exit_status = 0,
          .result_summary = "passed",
          .redacted_log_digest = std::string(64, 'a'),
      }},
      .repository =
          {
              .repository_url = "https://github.com/ray-manaloto/symphony-cpp",
              .worktree = "/workspace/symphony-cpp",
              .branch = "codex/implementation",
              .base_sha = std::string(40, 'a'),
              .head_sha = std::string(40, 'f'),
          },
      .files_claimed = {"include/symphony/control/records.hpp"},
      .resources_claimed = {"build/gcc-debug"},
      .progress_fingerprint = std::string(64, 'b'),
      .failure_signature = std::nullopt,
      .failure_family = std::nullopt,
      .consecutive_failure_count = 0,
      .blockers = {},
      .unresolved_risks = {},
      .role = "executor",
      .model = "gpt-5.6-sol",
      .effort = "high",
      .turn_number = 1,
      .session_id = "session-001",
      .context =
          ContextTelemetryV1{
              .thread_id = "thread-001",
              .turn_id = "turn-001",
              .context_window = 100000,
              .last_input_tokens = 44000,
              .cumulative_input_tokens = 44000,
              .cumulative_output_tokens = 1000,
              .cumulative_cached_tokens = 20000,
              .compaction_count = 0,
          },
      .task_items = {{.id = "fixture", .description = "add failing fixture", .state = "completed"}},
      .next_action = "request review",
      .next_owner = "root",
      .created_at = "2026-07-25T00:00:00Z",
      .updated_at = "2026-07-25T00:10:00Z",
      .content_digest = std::string(64, 'c'),
      .redaction_summary = "sanitized",
  };
}

std::optional<glz::generic_u64> parse_json(const std::string_view input) {
  glz::generic_u64 value;
  constexpr auto options = glz::opts{.null_terminated = false};
  if (const auto error = glz::read<options>(value, input)) {
    return std::nullopt;
  }
  return value;
}

bool has_required(const glz::generic_u64& schema, const std::string_view field) {
  if (!schema.contains("required")) return false;
  const auto& required = schema.at("required").get_array();
  return std::ranges::any_of(
      required, [field](const auto& item) { return item.template get<std::string>() == field; });
}

} // namespace

static ut::suite control_record_tests = [] {
  ut::test("all V1 control records round-trip through the strict owned codec") = [] {
    const auto packet = task_packet();
    const auto result = task_result();
    const auto review = review_attestation();
    const auto notepad = task_notepad();

    const auto packet_json = encode_json(packet);
    const auto result_json = encode_json(result);
    const auto review_json = encode_json(review);
    const auto notepad_json = encode_json(notepad);
    ut::expect(packet_json.has_value());
    ut::expect(result_json.has_value());
    ut::expect(review_json.has_value());
    ut::expect(notepad_json.has_value());
    if (!packet_json || !result_json || !review_json || !notepad_json) return;

    ut::expect(decode_task_packet_v1(*packet_json) == packet);
    ut::expect(decode_task_result_v1(*result_json) == result);
    ut::expect(decode_review_attestation_v1(*review_json) == review);
    ut::expect(decode_task_notepad_v1(*notepad_json) == notepad);
  };

  ut::test("strict record decode rejects missing unknown malformed and wrong-version input") = [] {
    auto unknown = encode_json(task_packet()).value();
    unknown.insert(unknown.size() - 1, R"(,"untrusted_instruction":"mutate tracker")");

    ut::expect(!decode_task_packet_v1(R"({"schema_version":1})"));
    ut::expect(!decode_task_packet_v1(unknown));
    ut::expect(!decode_task_packet_v1(R"({"schema_version":1)"));

    auto wrong_version = encode_json(task_packet()).value();
    const auto version = wrong_version.find(R"("schema_version":1)");
    ut::expect(version != std::string::npos);
    if (version != std::string::npos) {
      wrong_version.replace(version, std::string_view{R"("schema_version":1)"}.size(),
                            R"("schema_version":2)");
      const auto decoded = decode_task_packet_v1(wrong_version);
      ut::expect(!decoded);
      if (!decoded) ut::expect(decoded.error().code == RecordErrorCode::unsupported_schema_version);
    }

    auto wrong_kind = encode_json(task_packet()).value();
    const auto kind = wrong_kind.find(R"("record_kind":"task_packet")");
    ut::expect(kind != std::string::npos);
    if (kind != std::string::npos) {
      wrong_kind.replace(kind, std::string_view{R"("record_kind":"task_packet")"}.size(),
                         R"("record_kind":"task_result")");
      const auto decoded = decode_task_packet_v1(wrong_kind);
      ut::expect(!decoded);
      if (!decoded) ut::expect(decoded.error().code == RecordErrorCode::wrong_record_kind);
    }

    const std::string oversized(1024 * 1024 + 1, ' ');
    const auto oversized_result = decode_task_packet_v1(oversized);
    ut::expect(!oversized_result);
    if (!oversized_result) {
      ut::expect(oversized_result.error().code == RecordErrorCode::record_too_large);
    }
  };

  ut::test("strict record encode rejects wrong identity and oversized output") = [] {
    auto wrong_version = task_packet();
    wrong_version.schema_version = 2;
    const auto version_result = encode_json(wrong_version);
    ut::expect(!version_result);
    if (!version_result) {
      ut::expect(version_result.error().code == RecordErrorCode::unsupported_schema_version);
    }

    auto wrong_kind = task_packet();
    wrong_kind.record_kind = "task_result";
    const auto kind_result = encode_json(wrong_kind);
    ut::expect(!kind_result);
    if (!kind_result) {
      ut::expect(kind_result.error().code == RecordErrorCode::wrong_record_kind);
    }

    auto oversized = task_packet();
    oversized.objective.observable_contract = std::string(1024 * 1024, 'x');
    const auto oversized_result = encode_json(oversized);
    ut::expect(!oversized_result);
    if (!oversized_result) {
      ut::expect(oversized_result.error().code == RecordErrorCode::record_too_large);
    }

    auto escaped = task_packet();
    escaped.objective.observable_contract = "line one\nline two";
    const auto escaped_json = encode_json(escaped);
    ut::expect(escaped_json.has_value());
    if (escaped_json) {
      ut::expect(escaped_json->find(R"(line one\nline two)") != std::string::npos);
      ut::expect(decode_task_packet_v1(*escaped_json) == escaped);
    }
  };

  ut::test("record size limits are inclusive and preserve strict trailing-input semantics") = [] {
    auto empty_contract = task_packet();
    empty_contract.objective.observable_contract.clear();
    const auto empty_json = encode_json(empty_contract);
    ut::expect(empty_json.has_value());
    if (!empty_json) return;
    ut::expect(empty_json->size() < maximum_record_bytes);
    if (empty_json->size() >= maximum_record_bytes) return;

    auto exact_limit = empty_contract;
    exact_limit.objective.observable_contract.assign(maximum_record_bytes - empty_json->size(),
                                                     'x');
    const auto exact_json = encode_json(exact_limit);
    ut::expect(exact_json.has_value());
    if (exact_json) {
      ut::expect(exact_json->size() == maximum_record_bytes);
      ut::expect(decode_task_packet_v1(*exact_json) == exact_limit);
    }

    auto over_limit = exact_limit;
    over_limit.objective.observable_contract.push_back('x');
    const auto over_limit_result = encode_json(over_limit);
    ut::expect(!over_limit_result);
    if (!over_limit_result) {
      ut::expect(over_limit_result.error().code == RecordErrorCode::record_too_large);
    }

    auto one_byte_short = empty_contract;
    one_byte_short.objective.observable_contract.assign(
        maximum_record_bytes - empty_json->size() - 1, 'x');
    const auto one_byte_short_json = encode_json(one_byte_short);
    ut::expect(one_byte_short_json.has_value());
    if (!one_byte_short_json) return;
    ut::expect(one_byte_short_json->size() == maximum_record_bytes - 1);

    auto exact_with_whitespace = *one_byte_short_json;
    exact_with_whitespace.push_back(' ');
    ut::expect(exact_with_whitespace.size() == maximum_record_bytes);
    ut::expect(decode_task_packet_v1(exact_with_whitespace) == one_byte_short);

    auto exact_with_garbage = *one_byte_short_json;
    exact_with_garbage.push_back('x');
    const auto garbage_result = decode_task_packet_v1(exact_with_garbage);
    ut::expect(!garbage_result);
    if (!garbage_result) {
      ut::expect(garbage_result.error().code == RecordErrorCode::invalid_json);
    }

    exact_with_whitespace.push_back(' ');
    const auto over_limit_input = decode_task_packet_v1(exact_with_whitespace);
    ut::expect(!over_limit_input);
    if (!over_limit_input) {
      ut::expect(over_limit_input.error().code == RecordErrorCode::record_too_large);
    }
  };

  ut::test("passed review attestations reject contradictory evidence") = [] {
    auto stale_checks = review_attestation();
    stale_checks.required_checks_fresh = false;
    ut::expect(!encode_json(stale_checks));

    auto changed_bytes = review_attestation();
    changed_bytes.reviewed_path_bytes_unchanged = false;
    ut::expect(!encode_json(changed_bytes));

    auto unresolved_finding = review_attestation();
    unresolved_finding.findings.push_back({
        .id = "finding-001",
        .severity = "P1",
        .path = "src/control/records.cpp",
        .line = 1,
        .evidence = "contradictory pass state",
        .disposition = ReviewFindingDispositionV1::unresolved,
        .rerun_evidence_ids = {},
    });
    ut::expect(!encode_json(unresolved_finding));

    auto reviewer_contributed = review_attestation();
    reviewer_contributed.independence.authored_change = true;
    ut::expect(!encode_json(reviewer_contributed));

    auto resolved_finding = review_attestation();
    resolved_finding.findings.push_back({
        .id = "finding-002",
        .severity = "P1",
        .path = "src/control/records.cpp",
        .line = 1,
        .evidence = "bounded encoding correction verified",
        .disposition = ReviewFindingDispositionV1::resolved,
        .rerun_evidence_ids = {"focused-gcc-debug-001"},
    });
    const auto resolved_json = encode_json(resolved_finding);
    ut::expect(resolved_json.has_value());
    if (resolved_json) {
      ut::expect(decode_review_attestation_v1(*resolved_json) == resolved_finding);

      auto missing_rerun_json = *resolved_json;
      constexpr std::string_view rerun_evidence =
          R"("rerun_evidence_ids":["focused-gcc-debug-001"])";
      const auto rerun = missing_rerun_json.find(rerun_evidence);
      ut::expect(rerun != std::string::npos);
      if (rerun != std::string::npos) {
        missing_rerun_json.replace(rerun, rerun_evidence.size(), R"("rerun_evidence_ids":[])");
        const auto missing_rerun_decode = decode_review_attestation_v1(missing_rerun_json);
        ut::expect(!missing_rerun_decode);
        if (!missing_rerun_decode) {
          ut::expect(missing_rerun_decode.error().code == RecordErrorCode::invalid_record_state);
        }
      }
    }

    auto missing_rerun = resolved_finding;
    missing_rerun.findings.front().rerun_evidence_ids.clear();
    const auto missing_rerun_encode = encode_json(missing_rerun);
    ut::expect(!missing_rerun_encode);
    if (!missing_rerun_encode) {
      ut::expect(missing_rerun_encode.error().code == RecordErrorCode::invalid_record_state);
    }

    auto stale_json = encode_json(review_attestation()).value();
    const auto fresh = stale_json.find(R"("required_checks_fresh":true)");
    ut::expect(fresh != std::string::npos);
    if (fresh != std::string::npos) {
      stale_json.replace(fresh, std::string_view{R"("required_checks_fresh":true)"}.size(),
                         R"("required_checks_fresh":false)");
      ut::expect(!decode_review_attestation_v1(stale_json));
    }

    auto changed_json = encode_json(review_attestation()).value();
    const auto unchanged = changed_json.find(R"("reviewed_path_bytes_unchanged":true)");
    ut::expect(unchanged != std::string::npos);
    if (unchanged != std::string::npos) {
      changed_json.replace(unchanged,
                           std::string_view{R"("reviewed_path_bytes_unchanged":true)"}.size(),
                           R"("reviewed_path_bytes_unchanged":false)");
      ut::expect(!decode_review_attestation_v1(changed_json));
    }
  };

  ut::test("generated schemas are closed required and version constrained") = [] {
    for (const auto kind : {RecordKindV1::task_packet, RecordKindV1::task_result,
                            RecordKindV1::review_attestation, RecordKindV1::task_notepad}) {
      const auto generated = schema_json(kind);
      ut::expect(generated.has_value());
      if (!generated) continue;
      const auto schema = parse_json(*generated);
      ut::expect(schema.has_value());
      if (!schema) continue;
      ut::expect(schema->at("additionalProperties").get<bool>() == false);
      ut::expect(schema->at("$schema").get<std::string>() ==
                 "https://json-schema.org/draft/2020-12/schema");
      ut::expect(!schema->at("$id").get<std::string>().empty());
      ut::expect(has_required(*schema, "schema_version"));
      ut::expect(has_required(*schema, "record_kind"));
      const auto& version = schema->at("properties").at("schema_version");
      ut::expect(version.at("const").get<std::uint64_t>() == std::uint64_t{1});
      const auto& record_kind = schema->at("properties").at("record_kind");
      ut::expect(record_kind.contains("const"));
    }
  };
};
