#pragma once

#include <chrono>
#include <atomic>
#include <deque>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

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
  void reconfigure(std::string command, std::chrono::milliseconds read_timeout);
  [[nodiscard]] std::size_t run_count() const noexcept;

 private:
  std::deque<RunResult> results_;
  std::size_t run_count_{0};
};

class CodexAppServerRuntime final : public AgentRuntime {
 public:
  explicit CodexAppServerRuntime(
      std::string command = "codex app-server",
      std::chrono::milliseconds read_timeout = std::chrono::milliseconds{5000});
  [[nodiscard]] RunResult run(const RunRequest& request) override;
  void cancel(std::string_view session_id) override;

 private:
  std::string command_;
  std::chrono::milliseconds read_timeout_;
  std::atomic<int> active_process_{-1};
};

class JsonLineCodec {
 public:
  [[nodiscard]] static std::string frame(std::string_view json);
  [[nodiscard]] static std::string parse(std::string_view line, std::size_t max_bytes = 1024 * 1024);
};

enum class ProtocolEvent { response, notification, turn_completed, turn_failed, turn_cancelled, malformed };

struct ProtocolUpdate {
  ProtocolEvent event{ProtocolEvent::notification};
  std::string method;
  std::string thread_id;
  std::string turn_id;
  std::string error;
};

class AppServerProtocol {
 public:
  [[nodiscard]] static std::string initialize_request(std::uint64_t id = 0);
  [[nodiscard]] static std::string initialized_notification();
  [[nodiscard]] static std::string thread_start_request(
      std::uint64_t id,
      const std::filesystem::path& cwd);
  [[nodiscard]] static std::string turn_start_request(
      std::uint64_t id,
      std::string_view thread_id,
      const std::filesystem::path& cwd,
      std::string_view prompt);
  [[nodiscard]] static ProtocolUpdate decode(std::string_view line);
};

class ProtocolChannel {
 public:
  virtual ~ProtocolChannel() = default;
  virtual void write(std::string_view frame) = 0;
  [[nodiscard]] virtual std::optional<std::string> read(std::chrono::milliseconds timeout) = 0;
};

class FakeProtocolChannel final : public ProtocolChannel {
 public:
  void enqueue(std::string line);
  void write(std::string_view frame) override;
  [[nodiscard]] std::optional<std::string> read(std::chrono::milliseconds timeout) override;
  [[nodiscard]] const std::vector<std::string>& writes() const noexcept;

 private:
  std::deque<std::string> reads_;
  std::vector<std::string> writes_;
};

class AppServerConversation {
 public:
  [[nodiscard]] static RunResult run(
      ProtocolChannel& channel,
      const RunRequest& request,
      std::chrono::milliseconds read_timeout,
      std::size_t max_messages = 10000);
};

}  // namespace symphony::codex
