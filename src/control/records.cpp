#include "symphony/control/records.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <expected>
#include <span>
#include <spanstream>
#include <string>
#include <string_view>
#include <utility>

#include <glaze/core/ostream_buffer.hpp>
#include <glaze/glaze.hpp>
#include <glaze/json/schema.hpp>

template <> struct glz::json_schema<symphony::control::TaskPacketV1> {
  glz::schema schema_version{.constant = std::uint64_t{1}};
  glz::schema record_kind{.constant = std::string_view{"task_packet"}};
};

template <> struct glz::json_schema<symphony::control::TaskResultV1> {
  glz::schema schema_version{.constant = std::uint64_t{1}};
  glz::schema record_kind{.constant = std::string_view{"task_result"}};
};

template <> struct glz::json_schema<symphony::control::ReviewAttestationV1> {
  glz::schema schema_version{.constant = std::uint64_t{1}};
  glz::schema record_kind{.constant = std::string_view{"review_attestation"}};
};

template <> struct glz::json_schema<symphony::control::TaskNotepadV1> {
  glz::schema schema_version{.constant = std::uint64_t{1}};
  glz::schema record_kind{.constant = std::string_view{"task_notepad"}};
};

namespace symphony::control {
namespace {

struct StrictJsonOptions : glz::opts {
  bool validate_skipped{true};
  bool validate_trailing_whitespace{true};
};

constexpr StrictJsonOptions strict_json_options = [] {
  StrictJsonOptions options;
  options.null_terminated = false;
  options.error_on_unknown_keys = true;
  options.error_on_missing_keys = true;
  options.validate_skipped = true;
  options.validate_trailing_whitespace = true;
  return options;
}();

constexpr std::size_t maximum_record_bytes = 1024 * 1024;
constexpr std::size_t inline_record_bytes = 4096;

template <typename T> std::expected<void, RecordError> validate_record_state(const T&) {
  return {};
}

template <>
std::expected<void, RecordError> validate_record_state(const ReviewAttestationV1& value) {
  if (!value.passed) return {};

  const auto invalid_finding =
      std::ranges::any_of(value.findings, [](const ReviewFindingV1& finding) {
        return finding.disposition == ReviewFindingDispositionV1::unresolved ||
               (finding.disposition == ReviewFindingDispositionV1::resolved &&
                finding.rerun_evidence_ids.empty());
      });
  const auto reviewer_contributed = value.independence.designed_change ||
                                    value.independence.authored_change ||
                                    value.independence.materially_shaped_change;
  if (invalid_finding || !value.required_checks_fresh || !value.reviewed_path_bytes_unchanged ||
      reviewer_contributed) {
    return std::unexpected(RecordError{
        .code = RecordErrorCode::invalid_record_state,
        .message = "passed review attestation has contradictory evidence",
        .byte_offset = 0,
    });
  }
  return {};
}

template <typename T> std::expected<std::string, RecordError> write_bounded_record(const T& value) {
  std::array<char, inline_record_bytes> inline_output{};
  std::span<char> inline_buffer{inline_output};
  auto result = glz::write<strict_json_options>(value, inline_buffer);
  if (!result) {
    return std::string{inline_output.data(), result.count};
  }
  if (result.ec != glz::error_code::buffer_overflow) {
    return std::unexpected(RecordError{
        .code = RecordErrorCode::serialization_failed,
        .message = "control record serialization failed",
        .byte_offset = result.count,
    });
  }

  std::string output(maximum_record_bytes, '\0');
  std::ospanstream output_stream{std::span<char>{output}};
  glz::basic_ostream_buffer<std::ospanstream, inline_record_bytes> bounded_buffer{output_stream};
  result = glz::write<strict_json_options>(value, bounded_buffer);
  if (output_stream.fail()) {
    return std::unexpected(RecordError{
        .code = RecordErrorCode::record_too_large,
        .message = "control record exceeds the one MiB output limit",
        .byte_offset = maximum_record_bytes,
    });
  }
  if (result) {
    return std::unexpected(RecordError{
        .code = RecordErrorCode::serialization_failed,
        .message = "control record serialization failed",
        .byte_offset = result.count,
    });
  }
  output.resize(output_stream.span().size());
  return output;
}

template <typename T>
std::expected<std::string, RecordError> encode_record(const T& value,
                                                      const std::string_view expected_kind) {
  if (value.schema_version != 1) {
    return std::unexpected(RecordError{
        .code = RecordErrorCode::unsupported_schema_version,
        .message = "unsupported control record schema version",
        .byte_offset = 0,
    });
  }
  if (value.record_kind != expected_kind) {
    return std::unexpected(RecordError{
        .code = RecordErrorCode::wrong_record_kind,
        .message = "control record kind does not match the requested V1 type",
        .byte_offset = 0,
    });
  }
  if (const auto state = validate_record_state(value); !state) {
    return std::unexpected(state.error());
  }

  return write_bounded_record(value);
}

template <typename T>
std::expected<T, RecordError> decode_record(const std::string_view input,
                                            const std::string_view expected_kind) {
  if (input.size() > maximum_record_bytes) {
    return std::unexpected(RecordError{
        .code = RecordErrorCode::record_too_large,
        .message = "control record exceeds the one MiB input limit",
        .byte_offset = maximum_record_bytes,
    });
  }
  T value;
  if (const auto error = glz::read<strict_json_options>(value, input)) {
    return std::unexpected(RecordError{
        .code = RecordErrorCode::invalid_json,
        .message = "control record JSON did not satisfy the strict V1 codec contract",
        .byte_offset = error.count,
    });
  }
  if (value.schema_version != 1) {
    return std::unexpected(RecordError{
        .code = RecordErrorCode::unsupported_schema_version,
        .message = "unsupported control record schema version",
        .byte_offset = 0,
    });
  }
  if (value.record_kind != expected_kind) {
    return std::unexpected(RecordError{
        .code = RecordErrorCode::wrong_record_kind,
        .message = "control record kind does not match the requested V1 type",
        .byte_offset = 0,
    });
  }
  if (const auto state = validate_record_state(value); !state) {
    return std::unexpected(state.error());
  }
  return value;
}

template <typename T>
std::expected<std::string, RecordError> generate_schema(const std::string_view schema_id) {
  auto schema = glz::write_json_schema<T, strict_json_options>();
  if (!schema) {
    return std::unexpected(RecordError{
        .code = RecordErrorCode::schema_generation_failed,
        .message = "control record schema generation failed",
        .byte_offset = schema.error().count,
    });
  }
  std::string enveloped;
  enveloped.reserve(schema->size() + schema_id.size() + 80);
  enveloped.append(R"({"$schema":"https://json-schema.org/draft/2020-12/schema","$id":")");
  enveloped.append(schema_id);
  enveloped.append(R"(",)");
  enveloped.append(std::string_view{*schema}.substr(1));
  return enveloped;
}

} // namespace

std::expected<std::string, RecordError> encode_json(const TaskPacketV1& value) {
  return encode_record(value, "task_packet");
}

std::expected<std::string, RecordError> encode_json(const TaskResultV1& value) {
  return encode_record(value, "task_result");
}

std::expected<std::string, RecordError> encode_json(const ReviewAttestationV1& value) {
  return encode_record(value, "review_attestation");
}

std::expected<std::string, RecordError> encode_json(const TaskNotepadV1& value) {
  return encode_record(value, "task_notepad");
}

std::expected<TaskPacketV1, RecordError> decode_task_packet_v1(const std::string_view input) {
  return decode_record<TaskPacketV1>(input, "task_packet");
}

std::expected<TaskResultV1, RecordError> decode_task_result_v1(const std::string_view input) {
  return decode_record<TaskResultV1>(input, "task_result");
}

std::expected<ReviewAttestationV1, RecordError>
decode_review_attestation_v1(const std::string_view input) {
  return decode_record<ReviewAttestationV1>(input, "review_attestation");
}

std::expected<TaskNotepadV1, RecordError> decode_task_notepad_v1(const std::string_view input) {
  return decode_record<TaskNotepadV1>(input, "task_notepad");
}

std::expected<std::string, RecordError> schema_json(const RecordKindV1 kind) {
  switch (kind) {
  case RecordKindV1::task_packet:
    return generate_schema<TaskPacketV1>(
        "urn:ray-manaloto:symphony-cpp:control-records:task-packet:v1");
  case RecordKindV1::task_result:
    return generate_schema<TaskResultV1>(
        "urn:ray-manaloto:symphony-cpp:control-records:task-result:v1");
  case RecordKindV1::review_attestation:
    return generate_schema<ReviewAttestationV1>(
        "urn:ray-manaloto:symphony-cpp:control-records:review-attestation:v1");
  case RecordKindV1::task_notepad:
    return generate_schema<TaskNotepadV1>(
        "urn:ray-manaloto:symphony-cpp:control-records:task-notepad:v1");
  }
  return std::unexpected(RecordError{
      .code = RecordErrorCode::unsupported_record_kind,
      .message = "unsupported control record kind",
      .byte_offset = 0,
  });
}

} // namespace symphony::control
