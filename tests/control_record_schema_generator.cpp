#include <filesystem>
#include <fstream>
#include <iostream>
#include <string_view>

#include "symphony/control/records.hpp"

namespace {

struct SchemaOutput {
  symphony::control::RecordKindV1 kind;
  std::string_view filename;
};

constexpr SchemaOutput outputs[] = {
    {symphony::control::RecordKindV1::task_packet, "task-packet-v1.schema.json"},
    {symphony::control::RecordKindV1::task_result, "task-result-v1.schema.json"},
    {symphony::control::RecordKindV1::review_attestation, "review-attestation-v1.schema.json"},
    {symphony::control::RecordKindV1::task_notepad, "task-notepad-v1.schema.json"},
};

} // namespace

int main(const int argc, char** argv) {
  if (argc != 2) {
    std::cerr << "usage: symphony_control_record_schema_generator OUTPUT_DIRECTORY\n";
    return 64;
  }

  const std::filesystem::path output_directory{argv[1]};
  std::error_code error;
  std::filesystem::create_directories(output_directory, error);
  if (error) {
    std::cerr << "could not create schema output directory\n";
    return 1;
  }

  for (const auto& output : outputs) {
    const auto schema = symphony::control::schema_json(output.kind);
    if (!schema) {
      std::cerr << "could not generate " << output.filename << '\n';
      return 1;
    }
    std::ofstream file{output_directory / output.filename, std::ios::binary | std::ios::trunc};
    if (!file) {
      std::cerr << "could not write " << output.filename << '\n';
      return 1;
    }
    file.write(schema->data(), static_cast<std::streamsize>(schema->size()));
    file.put('\n');
    if (!file) {
      std::cerr << "could not write " << output.filename << '\n';
      return 1;
    }
  }
}
