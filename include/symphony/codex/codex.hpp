#pragma once

#include <chrono>
#include <cstdint>
#include <deque>
#include <functional>
#include <mutex>
#include <optional>
#include <stop_token>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "symphony/domain/domain.hpp"
#include "symphony/workspace/workspace.hpp"

namespace symphony::codex {

struct TokenUsage {
  std::uint64_t input_tokens{0};
  std::uint64_t cached_input_tokens{0};
  std::uint64_t output_tokens{0};
  std::uint64_t reasoning_output_tokens{0};
  std::uint64_t total_tokens{0};
  std::optional<std::int64_t> model_context_window;
};

struct RateLimitWindow {
  std::int32_t used_percent{0};
  std::optional<std::int64_t> window_duration_minutes;
  std::optional<std::int64_t> resets_at;
};

struct RateLimits {
  RateLimits() = default;
  RateLimits(
      std::optional<std::string> id,
      std::optional<RateLimitWindow> primary_window,
      std::optional<RateLimitWindow> secondary_window)
      : limit_id(std::move(id)),
        primary(std::move(primary_window)),
        secondary(std::move(secondary_window)) {}

  std::optional<std::string> limit_id;
  std::optional<std::string> limit_name;
  std::optional<std::string> plan_type;
  std::optional<std::string> reached_type;
  std::optional<bool> spend_control_reached;
  std::optional<RateLimitWindow> primary;
  std::optional<RateLimitWindow> secondary;
};

void merge_rate_limits(RateLimits& current, const RateLimits& update);

struct RunRequest {
  domain::Issue issue;
  domain::Attempt attempt;
  workspace::Workspace workspace;
  std::string prompt;
  std::optional<std::string> model;
  std::optional<std::string> reasoning_effort;
  std::optional<std::uint32_t> context_rollover_percent;
  std::uint32_t max_turns{1};
  std::function<std::optional<std::string>(std::uint32_t completed_turns)>
      continuation_prompt_after_turn;
};

struct ProcessDiagnostic {
  std::string text;
  std::uint64_t bytes_seen{0};
  bool truncated{false};
};

struct RunResult {
  RunResult() = default;
  RunResult(
      bool exited_normally,
      bool was_cancelled,
      std::optional<domain::ProgressSnapshot> progress_snapshot,
      std::string session,
      std::string error_message)
      : normal_exit(exited_normally),
        cancelled(was_cancelled),
        progress(std::move(progress_snapshot)),
        session_id(std::move(session)),
        error(std::move(error_message)) {}

  bool normal_exit{false};
  bool cancelled{false};
  bool stalled{false};
  bool timed_out{false};
  std::optional<domain::ProgressSnapshot> progress;
  std::string session_id;
  std::string error;
  std::optional<TokenUsage> token_usage;
  std::optional<RateLimits> rate_limits;
  std::optional<ProcessDiagnostic> process_diagnostic;
  std::uint32_t compaction_count{0};
  bool context_pressure_rollover{false};
  std::uint32_t turns_completed{0};
};

struct AppServerPolicy {
  std::optional<std::string> approval_policy;
  std::optional<std::string> thread_sandbox;
  std::optional<std::string> turn_sandbox_policy_json;
  std::optional<std::string> model;
  std::optional<std::string> reasoning_effort;
};

class AgentRuntime {
 public:
  virtual ~AgentRuntime() = default;
  [[nodiscard]] virtual RunResult run(
      const RunRequest& request,
      std::stop_token stop_token = {}) = 0;
};

class FakeAgentRuntime final : public AgentRuntime {
 public:
  void enqueue(RunResult result);
  [[nodiscard]] RunResult run(
      const RunRequest& request,
      std::stop_token stop_token = {}) override;
  [[nodiscard]] std::size_t run_count() const;
  [[nodiscard]] std::optional<std::string> last_model() const;
  [[nodiscard]] std::optional<std::string> last_reasoning_effort() const;
  [[nodiscard]] std::optional<std::uint32_t>
  last_context_rollover_percent() const;

 private:
  mutable std::mutex mutex_;
  std::deque<RunResult> results_;
  std::size_t run_count_{0};
  std::optional<std::string> last_model_;
  std::optional<std::string> last_reasoning_effort_;
  std::optional<std::uint32_t> last_context_rollover_percent_;
};

class CodexAppServerRuntime final : public AgentRuntime {
 public:
  explicit CodexAppServerRuntime(
      std::string command = "codex app-server",
      std::chrono::milliseconds read_timeout = std::chrono::milliseconds{5000},
      std::chrono::milliseconds stall_timeout = std::chrono::milliseconds{300000},
      std::chrono::milliseconds turn_timeout = std::chrono::milliseconds{3600000},
      AppServerPolicy policy = {},
      std::vector<std::string> excluded_environment_variables = {});
  [[nodiscard]] RunResult run(
      const RunRequest& request,
      std::stop_token stop_token = {}) override;
  void reconfigure(
      std::string command,
      std::chrono::milliseconds read_timeout,
      std::chrono::milliseconds stall_timeout,
      std::chrono::milliseconds turn_timeout,
      AppServerPolicy policy);

 private:
  std::string command_;
  std::chrono::milliseconds read_timeout_;
  std::chrono::milliseconds stall_timeout_;
  std::chrono::milliseconds turn_timeout_;
  AppServerPolicy policy_;
  std::vector<std::string> child_environment_;
  std::mutex config_mutex_;
};

class JsonLineCodec {
 public:
  [[nodiscard]] static std::string frame(std::string_view json);
  [[nodiscard]] static std::string parse(std::string_view line, std::size_t max_bytes = 1024 * 1024);
};

enum class ProtocolEvent {
  response,
  notification,
  turn_completed,
  turn_failed,
  turn_cancelled,
  approval_required,
  user_input_required,
  unsupported_tool_call,
  context_compacted,
  malformed
};

struct ProtocolUpdate {
  ProtocolEvent event{ProtocolEvent::notification};
  std::optional<std::uint64_t> response_id;
  std::string method;
  std::string thread_id;
  std::string turn_id;
  std::string error;
  std::optional<TokenUsage> token_usage;
  std::optional<RateLimits> rate_limits;
};

class AppServerProtocol {
 public:
  [[nodiscard]] static std::string initialize_request(std::uint64_t id = 0);
  [[nodiscard]] static std::string initialized_notification();
  [[nodiscard]] static std::string thread_start_request(
      std::uint64_t id,
      const std::filesystem::path& cwd,
      const AppServerPolicy& policy = {});
  [[nodiscard]] static std::string turn_start_request(
      std::uint64_t id,
      std::string_view thread_id,
      const std::filesystem::path& cwd,
      std::string_view prompt,
      const AppServerPolicy& policy = {});
  [[nodiscard]] static std::string unsupported_tool_response(std::uint64_t id);
  [[nodiscard]] static ProtocolUpdate decode(std::string_view line);
};

class ProtocolChannel {
 public:
  enum class ReadStatus { message, timeout, end_of_stream };
  struct ReadResult {
    ReadStatus status{ReadStatus::timeout};
    std::string message;
  };

  virtual ~ProtocolChannel() = default;
  virtual void write(std::string_view frame) = 0;
  [[nodiscard]] virtual ReadResult read(std::chrono::milliseconds timeout) = 0;
  virtual void request_stop() noexcept = 0;
};

class FakeProtocolChannel final : public ProtocolChannel {
 public:
  void enqueue(std::string line);
  void close();
  void write(std::string_view frame) override;
  [[nodiscard]] ReadResult read(std::chrono::milliseconds timeout) override;
  void request_stop() noexcept override;
  [[nodiscard]] const std::vector<std::string>& writes() const noexcept;

 private:
  std::deque<std::string> reads_;
  std::vector<std::string> writes_;
  bool closed_{false};
};

class AppServerConversation {
 public:
  [[nodiscard]] static RunResult run(
      ProtocolChannel& channel,
      const RunRequest& request,
      std::chrono::milliseconds read_timeout,
      std::size_t max_messages = 10000,
      std::chrono::milliseconds stall_timeout = std::chrono::milliseconds::zero(),
      std::chrono::milliseconds turn_timeout = std::chrono::milliseconds::zero(),
      const AppServerPolicy& policy = {},
      std::stop_token stop_token = {});
};

}  // namespace symphony::codex
