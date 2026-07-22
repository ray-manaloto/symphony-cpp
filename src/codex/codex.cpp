#include "symphony/codex/codex.hpp"

#include <stdexcept>
#include <array>
#include <cerrno>

#include <csignal>
#include <poll.h>
#include <sys/wait.h>
#include <unistd.h>

#include <nlohmann/json.hpp>

namespace symphony::codex {
namespace {
class PosixProtocolChannel final : public ProtocolChannel {
 public:
  PosixProtocolChannel(
      const std::string& command,
      const std::filesystem::path& cwd,
      std::atomic<int>& active_process)
      : active_process_(active_process) {
    int input_pipe[2]{};
    int output_pipe[2]{};
    if (::pipe(input_pipe) != 0 || ::pipe(output_pipe) != 0) {
      throw std::runtime_error("cannot create app-server pipes");
    }
    child_ = ::fork();
    if (child_ < 0) {
      ::close(input_pipe[0]);
      ::close(input_pipe[1]);
      ::close(output_pipe[0]);
      ::close(output_pipe[1]);
      throw std::runtime_error("cannot fork app-server");
    }
    if (child_ == 0) {
      static_cast<void>(::setpgid(0, 0));
      if (::chdir(cwd.c_str()) != 0) _exit(126);
      ::dup2(input_pipe[0], STDIN_FILENO);
      ::dup2(output_pipe[1], STDOUT_FILENO);
      ::close(input_pipe[0]);
      ::close(input_pipe[1]);
      ::close(output_pipe[0]);
      ::close(output_pipe[1]);
      ::execl("/bin/bash", "bash", "-lc", command.c_str(), static_cast<char*>(nullptr));
      _exit(127);
    }
    ::close(input_pipe[0]);
    ::close(output_pipe[1]);
    input_ = input_pipe[1];
    output_ = output_pipe[0];
    active_process_.store(child_);
  }

  ~PosixProtocolChannel() override {
    if (input_ >= 0) ::close(input_);
    if (output_ >= 0) ::close(output_);
    if (child_ > 0) {
      int status = 0;
      if (::waitpid(child_, &status, WNOHANG) == 0) {
        static_cast<void>(::kill(-child_, SIGTERM));
        for (int count = 0; count < 20 && ::waitpid(child_, &status, WNOHANG) == 0; ++count) {
          ::usleep(5000);
        }
        if (::waitpid(child_, &status, WNOHANG) == 0) {
          static_cast<void>(::kill(-child_, SIGKILL));
          static_cast<void>(::waitpid(child_, &status, 0));
        }
      }
    }
    active_process_.store(-1);
  }

  [[nodiscard]] int process_id() const noexcept { return child_; }

  void write(const std::string_view frame) override {
    std::size_t offset = 0;
    while (offset < frame.size()) {
      const auto count = ::write(input_, frame.data() + offset, frame.size() - offset);
      if (count < 0 && errno == EINTR) continue;
      if (count <= 0) throw std::runtime_error("app-server stdin closed");
      offset += static_cast<std::size_t>(count);
    }
  }

  std::optional<std::string> read(const std::chrono::milliseconds timeout) override {
    constexpr std::size_t max_line_bytes = 10U * 1024U * 1024U;
    const auto deadline = std::chrono::steady_clock::now() + timeout;
    while (true) {
      if (const auto newline = buffered_.find('\n'); newline != std::string::npos) {
        auto line = buffered_.substr(0, newline + 1);
        buffered_.erase(0, newline + 1);
        return line;
      }
      if (buffered_.size() > max_line_bytes) throw std::runtime_error("app-server line exceeds 10 MB");
      const auto remaining = std::chrono::duration_cast<std::chrono::milliseconds>(
          deadline - std::chrono::steady_clock::now());
      if (remaining <= std::chrono::milliseconds::zero()) return std::nullopt;
      pollfd descriptor{output_, POLLIN, 0};
      const auto ready = ::poll(&descriptor, 1, static_cast<int>(remaining.count()));
      if (ready == 0) return std::nullopt;
      if (ready < 0 && errno == EINTR) continue;
      if (ready < 0) throw std::runtime_error("app-server poll failed");
      std::array<char, 8192> chunk{};
      const auto count = ::read(output_, chunk.data(), chunk.size());
      if (count == 0) return std::nullopt;
      if (count < 0 && errno == EINTR) continue;
      if (count < 0) throw std::runtime_error("app-server stdout failed");
      buffered_.append(chunk.data(), static_cast<std::size_t>(count));
    }
  }

 private:
  std::atomic<int>& active_process_;
  int child_{-1};
  int input_{-1};
  int output_{-1};
  std::string buffered_;
};
}  // namespace

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

CodexAppServerRuntime::CodexAppServerRuntime(
    std::string command,
    const std::chrono::milliseconds read_timeout)
    : command_(std::move(command)), read_timeout_(read_timeout) {
  if (command_.empty()) throw std::invalid_argument("Codex command must not be empty");
  if (read_timeout_ <= std::chrono::milliseconds::zero()) {
    throw std::invalid_argument("Codex read timeout must be positive");
  }
}

RunResult CodexAppServerRuntime::run(const RunRequest& request) {
  if (request.workspace.path.empty() ||
      !std::filesystem::is_directory(request.workspace.path) ||
      !request.workspace.path.is_absolute()) {
    return RunResult{false, false, std::nullopt, {}, "invalid app-server workspace"};
  }
  PosixProtocolChannel channel(command_, request.workspace.path, active_process_);
  return AppServerConversation::run(channel, request, read_timeout_);
}

void CodexAppServerRuntime::cancel(std::string_view) {
  const auto process = active_process_.load();
  if (process > 0) static_cast<void>(::kill(-process, SIGTERM));
}

void CodexAppServerRuntime::reconfigure(
    std::string command,
    const std::chrono::milliseconds read_timeout) {
  if (active_process_.load() > 0) throw std::runtime_error("cannot reconfigure active Codex process");
  if (command.empty() || read_timeout <= std::chrono::milliseconds::zero()) {
    throw std::invalid_argument("invalid Codex runtime configuration");
  }
  command_ = std::move(command);
  read_timeout_ = read_timeout;
}

std::string JsonLineCodec::frame(const std::string_view json) {
  if (json.find('\n') != std::string_view::npos) throw std::runtime_error("JSON frame contains newline");
  static_cast<void>(parse(json));
  return std::string{json} + '\n';
}

std::string JsonLineCodec::parse(std::string_view line, const std::size_t max_bytes) {
  if (line.size() > max_bytes) throw std::runtime_error("JSON frame exceeds limit");
  if (!line.empty() && line.back() == '\n') line.remove_suffix(1);
  if (line.find('\n') != std::string_view::npos || line.find('\r') != std::string_view::npos) {
    throw std::runtime_error("JSON-RPC frame contains multiple lines");
  }
  const auto parsed = nlohmann::json::parse(line, nullptr, false);
  if (parsed.is_discarded() || !parsed.is_object()) {
    throw std::runtime_error("JSON-RPC frame must be one valid object");
  }
  return parsed.dump();
}

std::string AppServerProtocol::initialize_request(const std::uint64_t id) {
  return JsonLineCodec::frame(nlohmann::json{
      {"method", "initialize"},
      {"id", id},
      {"params", {{"clientInfo", {
          {"name", "symphony_cpp"},
          {"title", "Symphony C++"},
          {"version", "0.1.0"}}}}}}.dump());
}

std::string AppServerProtocol::initialized_notification() {
  return JsonLineCodec::frame(nlohmann::json{
      {"method", "initialized"}, {"params", nlohmann::json::object()}}.dump());
}

std::string AppServerProtocol::thread_start_request(
    const std::uint64_t id,
    const std::filesystem::path& cwd) {
  return JsonLineCodec::frame(nlohmann::json{
      {"method", "thread/start"},
      {"id", id},
      {"params", {{"cwd", cwd.native()}}}}.dump());
}

std::string AppServerProtocol::turn_start_request(
    const std::uint64_t id,
    const std::string_view thread_id,
    const std::filesystem::path& cwd,
    const std::string_view prompt) {
  return JsonLineCodec::frame(nlohmann::json{
      {"method", "turn/start"},
      {"id", id},
      {"params", {
          {"threadId", thread_id},
          {"cwd", cwd.native()},
          {"input", nlohmann::json::array({{{"type", "text"}, {"text", prompt}}})}}}}.dump());
}

ProtocolUpdate AppServerProtocol::decode(const std::string_view line) {
  ProtocolUpdate update;
  const auto normalized = JsonLineCodec::parse(line, 10U * 1024U * 1024U);
  const auto message = nlohmann::json::parse(normalized);
  if (message.contains("error")) {
    update.event = ProtocolEvent::turn_failed;
    update.error = message["error"].value("message", "app-server error");
    return update;
  }
  if (message.contains("id")) {
    update.event = ProtocolEvent::response;
    if (!message["id"].is_number_unsigned()) {
      update.event = ProtocolEvent::malformed;
      update.error = "response id must be an unsigned integer";
      return update;
    }
    update.response_id = message["id"].get<std::uint64_t>();
    if (const auto result = message.find("result"); result != message.end()) {
      if (const auto thread = result->find("thread"); thread != result->end()) {
        update.thread_id = thread->value("id", "");
      }
      if (const auto turn = result->find("turn"); turn != result->end()) {
        update.turn_id = turn->value("id", "");
      }
    }
    return update;
  }
  update.method = message.value("method", "");
  if (update.method.empty()) {
    update.event = ProtocolEvent::malformed;
    update.error = "notification has no method";
    return update;
  }
  const auto params = message.value("params", nlohmann::json::object());
  if (const auto thread = params.find("thread"); thread != params.end()) {
    update.thread_id = thread->value("id", "");
  }
  if (const auto turn = params.find("turn"); turn != params.end()) {
    update.turn_id = turn->value("id", "");
  }
  if (update.method == "turn/completed") update.event = ProtocolEvent::turn_completed;
  else if (update.method == "turn/failed") update.event = ProtocolEvent::turn_failed;
  else if (update.method == "turn/cancelled") update.event = ProtocolEvent::turn_cancelled;
  else update.event = ProtocolEvent::notification;
  return update;
}

void FakeProtocolChannel::enqueue(std::string line) { reads_.push_back(std::move(line)); }
void FakeProtocolChannel::write(const std::string_view frame) { writes_.emplace_back(frame); }
std::optional<std::string> FakeProtocolChannel::read(std::chrono::milliseconds) {
  if (reads_.empty()) return std::nullopt;
  auto line = std::move(reads_.front());
  reads_.pop_front();
  return line;
}
const std::vector<std::string>& FakeProtocolChannel::writes() const noexcept { return writes_; }

RunResult AppServerConversation::run(
    ProtocolChannel& channel,
    const RunRequest& request,
    const std::chrono::milliseconds read_timeout,
    const std::size_t max_messages) {
  RunResult result;
  channel.write(AppServerProtocol::initialize_request(0));
  std::string thread_id;
  std::string turn_id;
  bool initialized = false;
  bool thread_requested = false;
  bool turn_started = false;
  for (std::size_t count = 0; count < max_messages; ++count) {
    const auto line = channel.read(read_timeout);
    if (!line) {
      result.error = "app-server read timeout";
      return result;
    }
    ProtocolUpdate update;
    try {
      update = AppServerProtocol::decode(*line);
    } catch (const std::exception& error) {
      result.error = std::string{"malformed app-server message: "} + error.what();
      return result;
    }
    if (!update.thread_id.empty()) thread_id = update.thread_id;
    if (!update.turn_id.empty()) turn_id = update.turn_id;
    if (update.event == ProtocolEvent::malformed) {
      result.error = update.error.empty() ? "malformed app-server message" : update.error;
      return result;
    }
    if (update.response_id == 0 && !initialized) {
      channel.write(AppServerProtocol::initialized_notification());
      channel.write(AppServerProtocol::thread_start_request(1, request.workspace.path));
      initialized = true;
      thread_requested = true;
      continue;
    }
    if (update.response_id == 1 && thread_requested && !turn_started) {
      if (thread_id.empty()) {
        result.error = "thread/start response has no thread identity";
        return result;
      }
      channel.write(AppServerProtocol::turn_start_request(
          2, thread_id, request.workspace.path, request.prompt));
      turn_started = true;
      continue;
    }
    if (update.event == ProtocolEvent::turn_completed) {
      if (thread_id.empty() || turn_id.empty()) {
        result.error = "turn completed without thread and turn identities";
        return result;
      }
      result.normal_exit = true;
      result.session_id = thread_id + '-' + turn_id;
      return result;
    }
    if (update.event == ProtocolEvent::turn_failed || update.event == ProtocolEvent::turn_cancelled) {
      result.cancelled = update.event == ProtocolEvent::turn_cancelled;
      result.error = update.error.empty() ? update.method : update.error;
      result.session_id = thread_id.empty() || turn_id.empty() ? "" : thread_id + '-' + turn_id;
      return result;
    }
  }
  result.error = "app-server message limit exceeded";
  return result;
}
}  // namespace symphony::codex
