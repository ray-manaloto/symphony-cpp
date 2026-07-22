#include "symphony/codex/codex.hpp"

#include <array>
#include <cerrno>
#include <stdexcept>
#include <thread>

#include <csignal>
#include <poll.h>
#include <sys/wait.h>
#include <unistd.h>

#include <glaze/glaze.hpp>
#include <glaze/json/generic.hpp>

namespace symphony::codex {
namespace protocol_detail {
struct ClientInfo {
  std::string name;
  std::string title;
  std::string version;
};

struct InitializeParams {
  ClientInfo clientInfo;
};

struct EmptyParams {};

struct ThreadStartParams {
  std::string cwd;
};

struct TurnInput {
  std::string type;
  std::string text;
};

struct TurnStartParams {
  std::string threadId;
  std::string cwd;
  std::vector<TurnInput> input;
};

template <typename Params> struct Request {
  std::string method;
  std::uint64_t id;
  Params params;
};

template <typename Params> struct Notification {
  std::string method;
  Params params;
};

struct Identity {
  std::string id;
};

struct ResultBody {
  std::optional<Identity> thread;
  std::optional<Identity> turn;
  struct TokenUsageBreakdown {
    std::uint64_t inputTokens{0};
    std::uint64_t cachedInputTokens{0};
    std::uint64_t outputTokens{0};
    std::uint64_t reasoningOutputTokens{0};
    std::uint64_t totalTokens{0};
    std::uint64_t cacheWriteInputTokens{0};
  };
  struct ThreadTokenUsage {
    TokenUsageBreakdown last;
    TokenUsageBreakdown total;
    std::optional<std::int64_t> modelContextWindow;
  };
  struct RateLimitWindowBody {
    std::int32_t usedPercent{0};
    std::optional<std::int64_t> windowDurationMins;
    std::optional<std::int64_t> resetsAt;
  };
  struct RateLimitSnapshotBody {
    std::optional<std::string> limitId;
    std::optional<std::string> limitName;
    std::optional<std::string> planType;
    std::optional<std::string> rateLimitReachedType;
    std::optional<bool> spendControlReached;
    std::optional<RateLimitWindowBody> primary;
    std::optional<RateLimitWindowBody> secondary;
  };
  std::optional<ThreadTokenUsage> tokenUsage;
  std::optional<RateLimitSnapshotBody> rateLimits;
};

struct ErrorBody {
  std::string message{"app-server error"};
};

struct ProtocolMessage {
  std::optional<std::uint64_t> id;
  std::optional<std::string> method;
  std::optional<ResultBody> result;
  std::optional<ResultBody> params;
  std::optional<ErrorBody> error;
};

template <typename T> std::string encode_frame(const T &value) {
  auto json = glz::write_json(value);
  if (!json) {
    throw std::runtime_error("cannot encode app-server message: " +
                             glz::format_error(json.error()));
  }
  return JsonLineCodec::frame(*json);
}
} // namespace protocol_detail

void merge_rate_limits(RateLimits& current, const RateLimits& update) {
  if (update.limit_id) current.limit_id = update.limit_id;
  if (update.limit_name) current.limit_name = update.limit_name;
  if (update.plan_type) current.plan_type = update.plan_type;
  if (update.reached_type) current.reached_type = update.reached_type;
  if (update.spend_control_reached.has_value()) {
    current.spend_control_reached = update.spend_control_reached;
  }
  if (update.primary) current.primary = update.primary;
  if (update.secondary) current.secondary = update.secondary;
}

namespace {
class PosixProtocolChannel final : public ProtocolChannel {
public:
  PosixProtocolChannel(const std::string &command,
                       const std::filesystem::path &cwd,
                       std::atomic<int> &active_process)
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
      if (::chdir(cwd.c_str()) != 0)
        _exit(126);
      ::dup2(input_pipe[0], STDIN_FILENO);
      ::dup2(output_pipe[1], STDOUT_FILENO);
      ::close(input_pipe[0]);
      ::close(input_pipe[1]);
      ::close(output_pipe[0]);
      ::close(output_pipe[1]);
      ::execl("/bin/bash", "bash", "-lc", command.c_str(),
              static_cast<char *>(nullptr));
      _exit(127);
    }
    ::close(input_pipe[0]);
    ::close(output_pipe[1]);
    input_ = input_pipe[1];
    output_ = output_pipe[0];
    active_process_.store(child_);
  }

  ~PosixProtocolChannel() override {
    if (input_ >= 0)
      ::close(input_);
    if (output_ >= 0)
      ::close(output_);
    if (child_ > 0) {
      int status = 0;
      if (::waitpid(child_, &status, WNOHANG) == 0) {
        static_cast<void>(::kill(-child_, SIGTERM));
        for (int count = 0;
             count < 20 && ::waitpid(child_, &status, WNOHANG) == 0; ++count) {
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
      const auto count =
          ::write(input_, frame.data() + offset, frame.size() - offset);
      if (count < 0 && errno == EINTR)
        continue;
      if (count <= 0)
        throw std::runtime_error("app-server stdin closed");
      offset += static_cast<std::size_t>(count);
    }
  }

  std::optional<std::string>
  read(const std::chrono::milliseconds timeout) override {
    constexpr std::size_t max_line_bytes = 10U * 1024U * 1024U;
    const auto deadline = std::chrono::steady_clock::now() + timeout;
    while (true) {
      if (const auto newline = buffered_.find('\n');
          newline != std::string::npos) {
        auto line = buffered_.substr(0, newline + 1);
        buffered_.erase(0, newline + 1);
        return line;
      }
      if (buffered_.size() > max_line_bytes)
        throw std::runtime_error("app-server line exceeds 10 MB");
      const auto remaining =
          std::chrono::duration_cast<std::chrono::milliseconds>(
              deadline - std::chrono::steady_clock::now());
      if (remaining <= std::chrono::milliseconds::zero())
        return std::nullopt;
      pollfd descriptor{output_, POLLIN, 0};
      const auto ready =
          ::poll(&descriptor, 1, static_cast<int>(remaining.count()));
      if (ready == 0)
        return std::nullopt;
      if (ready < 0 && errno == EINTR)
        continue;
      if (ready < 0)
        throw std::runtime_error("app-server poll failed");
      std::array<char, 8192> chunk{};
      const auto count = ::read(output_, chunk.data(), chunk.size());
      if (count == 0)
        return std::nullopt;
      if (count < 0 && errno == EINTR)
        continue;
      if (count < 0)
        throw std::runtime_error("app-server stdout failed");
      buffered_.append(chunk.data(), static_cast<std::size_t>(count));
    }
  }

private:
  std::atomic<int> &active_process_;
  int child_{-1};
  int input_{-1};
  int output_{-1};
  std::string buffered_;
};
} // namespace

void FakeAgentRuntime::enqueue(RunResult result) {
  results_.push_back(std::move(result));
}

RunResult FakeAgentRuntime::run(const RunRequest &) {
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
    const std::chrono::milliseconds read_timeout,
    const std::chrono::milliseconds stall_timeout,
    const std::chrono::milliseconds turn_timeout)
    : command_(std::move(command)),
      read_timeout_(read_timeout),
      stall_timeout_(stall_timeout),
      turn_timeout_(turn_timeout) {
  if (command_.empty())
    throw std::invalid_argument("Codex command must not be empty");
  if (read_timeout_ <= std::chrono::milliseconds::zero()) {
    throw std::invalid_argument("Codex read timeout must be positive");
  }
}

RunResult CodexAppServerRuntime::run(const RunRequest &request) {
  if (request.workspace.path.empty() ||
      !std::filesystem::is_directory(request.workspace.path) ||
      !request.workspace.path.is_absolute()) {
    return RunResult{
        false, false, std::nullopt, {}, "invalid app-server workspace"};
  }
  PosixProtocolChannel channel(command_, request.workspace.path,
                               active_process_);
  return AppServerConversation::run(
      channel, request, read_timeout_, 10000, stall_timeout_, turn_timeout_);
}

void CodexAppServerRuntime::cancel(std::string_view) {
  const auto process = active_process_.load();
  if (process > 0)
    static_cast<void>(::kill(-process, SIGTERM));
}

void CodexAppServerRuntime::reconfigure(
    std::string command,
    const std::chrono::milliseconds read_timeout,
    const std::chrono::milliseconds stall_timeout,
    const std::chrono::milliseconds turn_timeout) {
  if (active_process_.load() > 0)
    throw std::runtime_error("cannot reconfigure active Codex process");
  if (command.empty() || read_timeout <= std::chrono::milliseconds::zero()) {
    throw std::invalid_argument("invalid Codex runtime configuration");
  }
  command_ = std::move(command);
  read_timeout_ = read_timeout;
  stall_timeout_ = stall_timeout;
  turn_timeout_ = turn_timeout;
}

std::string JsonLineCodec::frame(const std::string_view json) {
  if (json.find('\n') != std::string_view::npos)
    throw std::runtime_error("JSON frame contains newline");
  static_cast<void>(parse(json));
  return std::string{json} + '\n';
}

std::string JsonLineCodec::parse(std::string_view line,
                                 const std::size_t max_bytes) {
  if (line.size() > max_bytes)
    throw std::runtime_error("JSON frame exceeds limit");
  if (!line.empty() && line.back() == '\n')
    line.remove_suffix(1);
  if (line.find('\n') != std::string_view::npos ||
      line.find('\r') != std::string_view::npos) {
    throw std::runtime_error("JSON-RPC frame contains multiple lines");
  }
  glz::generic_u64 parsed;
  const std::string buffer{line};
  if (const auto error = glz::read_json(parsed, buffer);
      error || !parsed.is_object()) {
    throw std::runtime_error("JSON-RPC frame must be one valid object");
  }
  auto normalized = glz::write_json(parsed);
  if (!normalized)
    throw std::runtime_error("JSON-RPC frame cannot be normalized");
  return std::move(*normalized);
}

std::string AppServerProtocol::initialize_request(const std::uint64_t id) {
  return protocol_detail::encode_frame(protocol_detail::Request{
      "initialize", id,
      protocol_detail::InitializeParams{protocol_detail::ClientInfo{
          "symphony_cpp", "Symphony C++", "0.1.0"}}});
}

std::string AppServerProtocol::initialized_notification() {
  return protocol_detail::encode_frame(protocol_detail::Notification{
      "initialized", protocol_detail::EmptyParams{}});
}

std::string
AppServerProtocol::thread_start_request(const std::uint64_t id,
                                        const std::filesystem::path &cwd) {
  return protocol_detail::encode_frame(protocol_detail::Request{
      "thread/start", id, protocol_detail::ThreadStartParams{cwd.native()}});
}

std::string AppServerProtocol::turn_start_request(
    const std::uint64_t id, const std::string_view thread_id,
    const std::filesystem::path &cwd, const std::string_view prompt) {
  return protocol_detail::encode_frame(protocol_detail::Request{
      "turn/start", id,
      protocol_detail::TurnStartParams{std::string{thread_id},
                                       cwd.native(),
                                       {{"text", std::string{prompt}}}}});
}

ProtocolUpdate AppServerProtocol::decode(const std::string_view line) {
  ProtocolUpdate update;
  const auto normalized = JsonLineCodec::parse(line, 10U * 1024U * 1024U);
  protocol_detail::ProtocolMessage message;
  constexpr auto options = glz::opts{.error_on_unknown_keys = false};
  if (const auto error = glz::read<options>(message, normalized)) {
    throw std::runtime_error("invalid app-server message: " +
                             glz::format_error(error));
  }
  if (message.error) {
    update.event = ProtocolEvent::turn_failed;
    update.error = message.error->message;
    return update;
  }
  if (message.id) {
    update.event = ProtocolEvent::response;
    update.response_id = message.id;
    if (message.result) {
      if (message.result->thread)
        update.thread_id = message.result->thread->id;
      if (message.result->turn)
        update.turn_id = message.result->turn->id;
    }
    return update;
  }
  update.method = message.method.value_or("");
  if (update.method.empty()) {
    update.event = ProtocolEvent::malformed;
    update.error = "notification has no method";
    return update;
  }
  if (message.params) {
    if (message.params->thread)
      update.thread_id = message.params->thread->id;
    if (message.params->turn)
      update.turn_id = message.params->turn->id;
    if (message.params->tokenUsage) {
      const auto& total = message.params->tokenUsage->total;
      update.token_usage = TokenUsage{
          total.inputTokens,
          total.cachedInputTokens,
          total.outputTokens,
          total.reasoningOutputTokens,
          total.totalTokens};
    }
    if (message.params->rateLimits) {
      const auto map_window = [](const auto& source)
          -> std::optional<RateLimitWindow> {
        if (!source) return std::nullopt;
        return RateLimitWindow{
            source->usedPercent, source->windowDurationMins, source->resetsAt};
      };
      const auto& source = *message.params->rateLimits;
      RateLimits limits{source.limitId, map_window(source.primary),
                        map_window(source.secondary)};
      limits.limit_name = source.limitName;
      limits.plan_type = source.planType;
      limits.reached_type = source.rateLimitReachedType;
      limits.spend_control_reached = source.spendControlReached;
      update.rate_limits = std::move(limits);
    }
  }
  if (update.method == "turn/completed")
    update.event = ProtocolEvent::turn_completed;
  else if (update.method == "turn/failed")
    update.event = ProtocolEvent::turn_failed;
  else if (update.method == "turn/cancelled")
    update.event = ProtocolEvent::turn_cancelled;
  else
    update.event = ProtocolEvent::notification;
  return update;
}

void FakeProtocolChannel::enqueue(std::string line) {
  reads_.push_back(std::move(line));
}
void FakeProtocolChannel::write(const std::string_view frame) {
  writes_.emplace_back(frame);
}
std::optional<std::string>
FakeProtocolChannel::read(const std::chrono::milliseconds timeout) {
  if (reads_.empty()) {
    std::this_thread::sleep_for(timeout);
    return std::nullopt;
  }
  auto line = std::move(reads_.front());
  reads_.pop_front();
  return line;
}
const std::vector<std::string> &FakeProtocolChannel::writes() const noexcept {
  return writes_;
}

RunResult
AppServerConversation::run(ProtocolChannel &channel, const RunRequest &request,
                           const std::chrono::milliseconds read_timeout,
                           const std::size_t max_messages,
                           const std::chrono::milliseconds stall_timeout,
                           const std::chrono::milliseconds turn_timeout) {
  RunResult result;
  channel.write(AppServerProtocol::initialize_request(0));
  std::string thread_id;
  std::string turn_id;
  bool initialized = false;
  bool thread_requested = false;
  bool turn_started = false;
  const auto started_at = std::chrono::steady_clock::now();
  auto last_event = started_at;
  for (std::size_t count = 0; count < max_messages; ++count) {
    const auto line = channel.read(read_timeout);
    if (!line) {
      const auto now = std::chrono::steady_clock::now();
      if (turn_timeout > std::chrono::milliseconds::zero() &&
          now - started_at > turn_timeout) {
        result.timed_out = true;
        result.error = "app-server turn timeout";
        result.session_id = thread_id.empty() || turn_id.empty()
                                ? ""
                                : thread_id + '-' + turn_id;
        return result;
      }
      if (stall_timeout > std::chrono::milliseconds::zero()) {
        if (now - last_event > stall_timeout) {
          result.stalled = true;
          result.error = "app-server stalled";
          result.session_id = thread_id.empty() || turn_id.empty()
                                  ? ""
                                  : thread_id + '-' + turn_id;
          return result;
        }
        continue;
      }
      if (turn_timeout > std::chrono::milliseconds::zero()) continue;
      result.error = "app-server read timeout";
      return result;
    }
    last_event = std::chrono::steady_clock::now();
    ProtocolUpdate update;
    try {
      update = AppServerProtocol::decode(*line);
    } catch (const std::exception &error) {
      result.error =
          std::string{"malformed app-server message: "} + error.what();
      return result;
    }
    if (!update.thread_id.empty())
      thread_id = update.thread_id;
    if (!update.turn_id.empty())
      turn_id = update.turn_id;
    if (update.token_usage) result.token_usage = update.token_usage;
    if (update.rate_limits) {
      if (!result.rate_limits) result.rate_limits.emplace();
      merge_rate_limits(*result.rate_limits, *update.rate_limits);
    }
    if (update.event == ProtocolEvent::malformed) {
      result.error =
          update.error.empty() ? "malformed app-server message" : update.error;
      return result;
    }
    if (update.response_id == 0 && !initialized) {
      channel.write(AppServerProtocol::initialized_notification());
      channel.write(
          AppServerProtocol::thread_start_request(1, request.workspace.path));
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
    if (update.event == ProtocolEvent::turn_failed ||
        update.event == ProtocolEvent::turn_cancelled) {
      result.cancelled = update.event == ProtocolEvent::turn_cancelled;
      result.error = update.error.empty() ? update.method : update.error;
      result.session_id =
          thread_id.empty() || turn_id.empty() ? "" : thread_id + '-' + turn_id;
      return result;
    }
  }
  result.error = "app-server message limit exceeded";
  return result;
}
} // namespace symphony::codex
