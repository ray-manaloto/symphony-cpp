#include "symphony/codex/codex.hpp"

#include <stdexcept>

namespace symphony::codex {
void FakeAgentRuntime::enqueue(RunResult result) { results_.push_back(std::move(result)); }

RunResult FakeAgentRuntime::run(const RunRequest&) {
  ++run_count_;
  if (results_.empty()) {
    RunResult result;
    result.error = "no fixture result queued";
    return result;
  }
  auto result = std::move(results_.front());
  results_.pop_front();
  return result;
}

void FakeAgentRuntime::cancel(std::string_view) {}
std::size_t FakeAgentRuntime::run_count() const noexcept { return run_count_; }

std::string JsonLineCodec::frame(const std::string_view json) {
  if (json.find('\n') != std::string_view::npos) throw std::runtime_error("JSON frame contains newline");
  static_cast<void>(parse(json));
  return std::string{json} + '\n';
}

std::string JsonLineCodec::parse(std::string_view line, const std::size_t max_bytes) {
  if (line.size() > max_bytes) throw std::runtime_error("JSON frame exceeds limit");
  if (!line.empty() && line.back() == '\n') line.remove_suffix(1);
  if (line.empty() || line.front() != '{' || line.back() != '}') {
    throw std::runtime_error("JSON-RPC frame must be one object");
  }
  if (line.find('\n') != std::string_view::npos || line.find('\r') != std::string_view::npos) {
    throw std::runtime_error("JSON-RPC frame contains multiple lines");
  }
  bool quoted = false;
  bool escaped = false;
  int depth = 0;
  for (const char character : line) {
    if (escaped) { escaped = false; continue; }
    if (quoted && character == '\\') { escaped = true; continue; }
    if (character == '"') { quoted = !quoted; continue; }
    if (!quoted && character == '{') ++depth;
    if (!quoted && character == '}' && --depth < 0) throw std::runtime_error("malformed JSON object");
  }
  if (quoted || depth != 0) throw std::runtime_error("malformed JSON object");
  return std::string{line};
}
}  // namespace symphony::codex
