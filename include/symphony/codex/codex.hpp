#pragma once

#include <chrono>
#include <deque>
#include <optional>
#include <string>
#include <string_view>

#include "symphony/domain/domain.hpp"
#include "symphony/workspace/workspace.hpp"

namespace symphony::codex {

struct RunRequest {
  domain::Issue issue;
  domain::Attempt attempt;
  workspace::Workspace workspace;
  std::string prompt;
};

struct RunResult {
  bool normal_exit{false};
  bool cancelled{false};
  std::optional<domain::ProgressSnapshot> progress;
  std::string session_id;
  std::string error;
};

class AgentRuntime {
 public:
  virtual ~AgentRuntime() = default;
  [[nodiscard]] virtual RunResult run(const RunRequest& request) = 0;
  virtual void cancel(std::string_view session_id) = 0;
};

class FakeAgentRuntime final : public AgentRuntime {
 public:
  void enqueue(RunResult result);
  [[nodiscard]] RunResult run(const RunRequest& request) override;
  void cancel(std::string_view session_id) override;
  [[nodiscard]] std::size_t run_count() const noexcept;

 private:
  std::deque<RunResult> results_;
  std::size_t run_count_{0};
};

class JsonLineCodec {
 public:
  [[nodiscard]] static std::string frame(std::string_view json);
  [[nodiscard]] static std::string parse(std::string_view line, std::size_t max_bytes = 1024 * 1024);
};

}  // namespace symphony::codex

