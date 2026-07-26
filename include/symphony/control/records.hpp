#pragma once

#include <cstddef>
#include <cstdint>
#include <expected>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace symphony::control {

struct PacketIdentityV1 {
  std::string packet_id;
  std::optional<std::string> issue_id;
  std::optional<std::string> issue_identifier;
  std::string repository_url;
  std::string worktree;
  std::string branch;
  std::string base_sha;
  std::string plan_digest;
  std::string spec_digest;
  std::string created_at;
  std::optional<std::string> expires_at;
  friend bool operator==(const PacketIdentityV1&, const PacketIdentityV1&) = default;
};

struct TaskObjectiveV1 {
  std::string observable_contract;
  std::string acceptance_boundary;
  std::string atomic_action;
  std::vector<std::string> stop_conditions;
  std::vector<std::string> split_conditions;
  friend bool operator==(const TaskObjectiveV1&, const TaskObjectiveV1&) = default;
};

struct TaskAuthorityV1 {
  bool read_only{true};
  bool tracker_mutation{false};
  bool publication{false};
  bool deployment{false};
  std::vector<std::string> allowed_paths;
  std::vector<std::string> denied_paths;
  std::vector<std::string> serialized_paths;
  std::vector<std::string> resource_keys;
  friend bool operator==(const TaskAuthorityV1&, const TaskAuthorityV1&) = default;
};

struct DependencyGateV1 {
  std::string decision_status;
  std::string provider;
  std::string seam;
  std::string decision_record;
  friend bool operator==(const DependencyGateV1&, const DependencyGateV1&) = default;
};

struct FailureFirstV1 {
  std::string fixture_id;
  std::string focused_command;
  std::string expected_initial_outcome;
  friend bool operator==(const FailureFirstV1&, const FailureFirstV1&) = default;
};

struct AcceptanceRequirementV1 {
  std::string command;
  std::string cwd;
  std::int32_t expected_exit{};
  std::optional<std::string> artifact_path;
  std::optional<std::string> artifact_digest;
  std::string toolchain;
  std::string commit;
  friend bool operator==(const AcceptanceRequirementV1&, const AcceptanceRequirementV1&) = default;
};

struct ReviewPolicyV1 {
  std::vector<std::string> risk_triggers;
  std::vector<std::string> required_kinds;
  bool independent_reviewer_required{true};
  friend bool operator==(const ReviewPolicyV1&, const ReviewPolicyV1&) = default;
};

struct ExecutionBudgetV1 {
  std::uint32_t max_turns{};
  std::uint32_t max_sessions{};
  std::uint64_t deadline_seconds{};
  std::uint32_t no_progress_limit{};
  std::uint32_t repeated_failure_limit{};
  friend bool operator==(const ExecutionBudgetV1&, const ExecutionBudgetV1&) = default;
};

struct ModelRouteV1 {
  std::string model;
  std::string effort;
  std::string reason;
  friend bool operator==(const ModelRouteV1&, const ModelRouteV1&) = default;
};

struct CheckpointPolicyV1 {
  std::string notepad_path;
  std::uint32_t notepad_schema_version{1};
  std::string context_telemetry_source;
  std::uint32_t checkpoint_percent{45};
  std::uint32_t handoff_percent{50};
  std::uint32_t hard_stop_percent{55};
  std::string next_owner;
  friend bool operator==(const CheckpointPolicyV1&, const CheckpointPolicyV1&) = default;
};

struct TaskPacketV1 {
  std::uint32_t schema_version{1};
  std::string record_kind{"task_packet"};
  PacketIdentityV1 identity;
  std::string role;
  TaskObjectiveV1 objective;
  TaskAuthorityV1 authority;
  DependencyGateV1 dependency;
  FailureFirstV1 failure_first;
  std::vector<AcceptanceRequirementV1> acceptance;
  ReviewPolicyV1 review;
  ExecutionBudgetV1 budget;
  ModelRouteV1 model_route;
  CheckpointPolicyV1 checkpoint;
  friend bool operator==(const TaskPacketV1&, const TaskPacketV1&) = default;
};

struct RepositoryIdentityV1 {
  std::string repository_url;
  std::string worktree;
  std::string branch;
  std::string base_sha;
  std::string head_sha;
  friend bool operator==(const RepositoryIdentityV1&, const RepositoryIdentityV1&) = default;
};

struct CommandResultV1 {
  std::string command;
  std::string cwd;
  std::int32_t exit_status{};
  std::string toolchain;
  std::string environment_digest;
  std::string redacted_log_digest;
  std::vector<std::string> artifact_digests;
  friend bool operator==(const CommandResultV1&, const CommandResultV1&) = default;
};

struct FailureEvidenceV1 {
  std::string signature;
  std::string family;
  std::uint32_t recurrence{};
  std::optional<std::string> correction;
  std::optional<std::string> guard_reference;
  friend bool operator==(const FailureEvidenceV1&, const FailureEvidenceV1&) = default;
};

struct TaskResultV1 {
  std::uint32_t schema_version{1};
  std::string record_kind{"task_result"};
  std::string packet_id;
  std::string packet_digest;
  std::string role;
  std::string actor_id;
  std::string session_id;
  std::string role_history_digest;
  RepositoryIdentityV1 repository;
  std::string changed_path_digest;
  std::string progress_fingerprint;
  std::vector<CommandResultV1> command_results;
  std::optional<FailureEvidenceV1> failure;
  std::vector<std::string> files_touched;
  std::vector<std::string> resources_touched;
  std::vector<std::string> unresolved_risks;
  std::vector<std::string> blockers;
  std::string next_action;
  std::string next_owner;
  std::string notepad_digest;
  std::string terminal_reason;
  bool partial{false};
  std::string redaction_summary;
  friend bool operator==(const TaskResultV1&, const TaskResultV1&) = default;
};

enum class ReviewFindingDispositionV1 { unresolved, resolved, not_applicable };

struct ReviewFindingV1 {
  std::string id;
  std::string severity;
  std::string path;
  std::optional<std::uint32_t> line;
  std::string evidence;
  ReviewFindingDispositionV1 disposition{ReviewFindingDispositionV1::unresolved};
  std::vector<std::string> rerun_evidence_ids;
  friend bool operator==(const ReviewFindingV1&, const ReviewFindingV1&) = default;
};

struct ReviewIndependenceV1 {
  bool designed_change{false};
  bool authored_change{false};
  bool materially_shaped_change{false};
  friend bool operator==(const ReviewIndependenceV1&, const ReviewIndependenceV1&) = default;
};

struct ReviewAttestationV1 {
  std::uint32_t schema_version{1};
  std::string record_kind{"review_attestation"};
  std::string review_id;
  std::string packet_id;
  std::string review_kind;
  std::string reviewer_id;
  std::string reviewer_session_id;
  std::string role_history_digest;
  ReviewIndependenceV1 independence;
  std::string reviewed_sha;
  std::string reviewed_diff_digest;
  std::string reviewed_path_digest;
  std::vector<ReviewFindingV1> findings;
  std::vector<std::string> required_check_ids;
  bool required_checks_fresh{false};
  bool reviewed_path_bytes_unchanged{false};
  bool passed{false};
  std::string created_at;
  std::string redaction_summary;
  friend bool operator==(const ReviewAttestationV1&, const ReviewAttestationV1&) = default;
};

struct DecisionEvidenceV1 {
  std::string decision;
  std::vector<std::string> evidence_references;
  friend bool operator==(const DecisionEvidenceV1&, const DecisionEvidenceV1&) = default;
};

struct NotepadCommandV1 {
  std::string command;
  std::string cwd;
  std::int32_t exit_status{};
  std::string result_summary;
  std::string redacted_log_digest;
  friend bool operator==(const NotepadCommandV1&, const NotepadCommandV1&) = default;
};

struct ContextTelemetryV1 {
  std::string thread_id;
  std::string turn_id;
  std::uint64_t context_window{};
  std::uint64_t last_input_tokens{};
  std::uint64_t cumulative_input_tokens{};
  std::uint64_t cumulative_output_tokens{};
  std::uint64_t cumulative_cached_tokens{};
  std::uint32_t compaction_count{};
  friend bool operator==(const ContextTelemetryV1&, const ContextTelemetryV1&) = default;
};

struct TaskItemV1 {
  std::string id;
  std::string description;
  std::string state;
  friend bool operator==(const TaskItemV1&, const TaskItemV1&) = default;
};

struct TaskNotepadV1 {
  std::uint32_t schema_version{1};
  std::string record_kind{"task_notepad"};
  std::string task_id;
  std::string packet_id;
  std::string objective;
  std::vector<std::string> constraints;
  std::vector<DecisionEvidenceV1> decisions;
  std::vector<NotepadCommandV1> commands;
  RepositoryIdentityV1 repository;
  std::vector<std::string> files_claimed;
  std::vector<std::string> resources_claimed;
  std::string progress_fingerprint;
  std::optional<std::string> failure_signature;
  std::optional<std::string> failure_family;
  std::uint32_t consecutive_failure_count{};
  std::vector<std::string> blockers;
  std::vector<std::string> unresolved_risks;
  std::string role;
  std::string model;
  std::string effort;
  std::uint32_t turn_number{};
  std::string session_id;
  std::optional<ContextTelemetryV1> context;
  std::vector<TaskItemV1> task_items;
  std::string next_action;
  std::string next_owner;
  std::string created_at;
  std::string updated_at;
  std::string content_digest;
  std::string redaction_summary;
  friend bool operator==(const TaskNotepadV1&, const TaskNotepadV1&) = default;
};

enum class RecordKindV1 { task_packet, task_result, review_attestation, task_notepad };

enum class RecordErrorCode {
  invalid_json,
  record_too_large,
  unsupported_schema_version,
  wrong_record_kind,
  invalid_record_state,
  serialization_failed,
  schema_generation_failed,
  unsupported_record_kind
};

struct RecordError {
  RecordErrorCode code{RecordErrorCode::invalid_json};
  std::string message;
  std::size_t byte_offset{};
  friend bool operator==(const RecordError&, const RecordError&) = default;
};

[[nodiscard]] std::expected<std::string, RecordError> encode_json(const TaskPacketV1& value);
[[nodiscard]] std::expected<std::string, RecordError> encode_json(const TaskResultV1& value);
[[nodiscard]] std::expected<std::string, RecordError> encode_json(const ReviewAttestationV1& value);
[[nodiscard]] std::expected<std::string, RecordError> encode_json(const TaskNotepadV1& value);

[[nodiscard]] std::expected<TaskPacketV1, RecordError>
decode_task_packet_v1(std::string_view input);
[[nodiscard]] std::expected<TaskResultV1, RecordError>
decode_task_result_v1(std::string_view input);
[[nodiscard]] std::expected<ReviewAttestationV1, RecordError>
decode_review_attestation_v1(std::string_view input);
[[nodiscard]] std::expected<TaskNotepadV1, RecordError>
decode_task_notepad_v1(std::string_view input);

[[nodiscard]] std::expected<std::string, RecordError> schema_json(RecordKindV1 kind);

} // namespace symphony::control
