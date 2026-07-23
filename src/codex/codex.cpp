#include "symphony/codex/codex.hpp"

#include <array>
#include <stdexcept>
#include <thread>

#include <boost/asio.hpp>
#include <boost/filesystem/path.hpp>
#include <boost/process/v2/process.hpp>
#include <boost/process/v2/start_dir.hpp>
#include <boost/process/v2/stdio.hpp>
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
  std::optional<std::string> approvalPolicy;
  std::optional<std::string> sandbox;
};

struct TurnInput {
  std::string type;
  std::string text;
};

struct TurnStartParams {
  std::string threadId;
  std::string cwd;
  std::vector<TurnInput> input;
  std::optional<std::string> approvalPolicy;
  std::optional<glz::raw_json> sandboxPolicy;
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

struct ToolContentItem {
  std::string type{"inputText"};
  std::string text;
};

struct ToolFailureResult {
  bool success{false};
  std::string output;
  std::vector<ToolContentItem> contentItems;
};

template <typename Result> struct Response {
  std::uint64_t id;
  Result result;
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
AppServerPolicy normalized_policy(AppServerPolicy policy) {
  if (policy.turn_sandbox_policy_json) {
    policy.turn_sandbox_policy_json = JsonLineCodec::parse(
        *policy.turn_sandbox_policy_json, 1024U * 1024U);
  }
  return policy;
}

class BoostProcessProtocolChannel final : public ProtocolChannel {
public:
  BoostProcessProtocolChannel(
      const std::string& command,
      const std::filesystem::path& cwd)
      : input_(context_),
        output_(context_),
        child_(
            context_,
            boost::filesystem::path("/bin/bash"),
            {"-lc", command},
            boost::process::v2::process_start_dir(
                boost::filesystem::path(cwd.string())),
            boost::process::v2::process_stdio{input_, output_, nullptr}) {}

  ~BoostProcessProtocolChannel() override {
    boost::system::error_code ignored;
    input_.close(ignored);
    output_.close(ignored);
    ignored.clear();
    if (child_.running(ignored)) {
      ignored.clear();
      child_.terminate(ignored);
    }
    ignored.clear();
    static_cast<void>(child_.wait(ignored));
  }

  void request_exit() noexcept {
    boost::system::error_code ignored;
    if (child_.running(ignored)) {
      ignored.clear();
      child_.request_exit(ignored);
    }
  }

  void write(const std::string_view frame) override {
    boost::system::error_code error;
    boost::asio::write(input_, boost::asio::buffer(frame), error);
    if (error) {
      throw std::runtime_error("app-server stdin closed");
    }
  }

  ReadResult
  read(const std::chrono::milliseconds timeout) override {
    constexpr std::size_t max_line_bytes = 10U * 1024U * 1024U;
    const auto deadline = std::chrono::steady_clock::now() + timeout;
    while (true) {
      if (const auto newline = buffered_.find('\n');
          newline != std::string::npos) {
        auto line = buffered_.substr(0, newline + 1);
        buffered_.erase(0, newline + 1);
        return {ReadStatus::message, std::move(line)};
      }
      if (buffered_.size() > max_line_bytes)
        throw std::runtime_error("app-server line exceeds 10 MB");
      if (end_of_stream_) {
        if (!buffered_.empty()) {
          throw std::runtime_error(
              "app-server stdout closed with incomplete frame");
        }
        return {ReadStatus::end_of_stream, {}};
      }
      const auto remaining =
          std::chrono::duration_cast<std::chrono::milliseconds>(
              deadline - std::chrono::steady_clock::now());
      if (remaining <= std::chrono::milliseconds::zero())
        return {ReadStatus::timeout, {}};

      std::array<char, 8192> chunk{};
      boost::system::error_code read_error;
      std::size_t count = 0;
      bool read_finished = false;
      bool timed_out = false;
      boost::asio::steady_timer timer(context_, remaining);
      output_.async_read_some(
          boost::asio::buffer(chunk),
          [&](const boost::system::error_code& error, const std::size_t size) {
            read_error = error;
            count = size;
            read_finished = true;
            static_cast<void>(timer.cancel());
          });
      timer.async_wait([&](const boost::system::error_code& error) {
        if (!error && !read_finished) {
          timed_out = true;
          boost::system::error_code ignored;
          output_.cancel(ignored);
        }
      });
      context_.restart();
      context_.run();

      if (timed_out) return {ReadStatus::timeout, {}};
      if (read_error == boost::asio::error::eof) {
        end_of_stream_ = true;
        continue;
      }
      if (read_error) {
        throw std::runtime_error("app-server stdout failed");
      }
      buffered_.append(chunk.data(), count);
    }
  }

private:
  boost::asio::io_context context_;
  boost::asio::writable_pipe input_;
  boost::asio::readable_pipe output_;
  boost::process::v2::process child_;
  std::string buffered_;
  bool end_of_stream_{false};
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
    const std::chrono::milliseconds turn_timeout,
    AppServerPolicy policy)
    : command_(std::move(command)),
      read_timeout_(read_timeout),
      stall_timeout_(stall_timeout),
      turn_timeout_(turn_timeout),
      policy_(normalized_policy(std::move(policy))) {
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
  std::string command;
  std::chrono::milliseconds read_timeout;
  std::chrono::milliseconds stall_timeout;
  std::chrono::milliseconds turn_timeout;
  AppServerPolicy policy;
  {
    const std::scoped_lock lock(active_process_mutex_);
    command = command_;
    read_timeout = read_timeout_;
    stall_timeout = stall_timeout_;
    turn_timeout = turn_timeout_;
    policy = policy_;
  }
  BoostProcessProtocolChannel channel(command, request.workspace.path);
  {
    const std::scoped_lock lock(active_process_mutex_);
    if (cancel_active_process_) {
      throw std::runtime_error("Codex runtime already has an active process");
    }
    cancel_active_process_ = [&channel] { channel.request_exit(); };
  }
  const auto clear_active_process = [&] {
    const std::scoped_lock lock(active_process_mutex_);
    cancel_active_process_ = {};
  };
  try {
    auto result = AppServerConversation::run(
        channel,
        request,
        read_timeout,
        10000,
        stall_timeout,
        turn_timeout,
        policy);
    clear_active_process();
    return result;
  } catch (...) {
    clear_active_process();
    throw;
  }
}

void CodexAppServerRuntime::cancel(std::string_view) {
  const std::scoped_lock lock(active_process_mutex_);
  if (cancel_active_process_) cancel_active_process_();
}

void CodexAppServerRuntime::reconfigure(
    std::string command,
    const std::chrono::milliseconds read_timeout,
    const std::chrono::milliseconds stall_timeout,
    const std::chrono::milliseconds turn_timeout,
    AppServerPolicy policy) {
  auto validated_policy = normalized_policy(std::move(policy));
  const std::scoped_lock lock(active_process_mutex_);
  if (cancel_active_process_)
    throw std::runtime_error("cannot reconfigure active Codex process");
  if (command.empty() || read_timeout <= std::chrono::milliseconds::zero()) {
    throw std::invalid_argument("invalid Codex runtime configuration");
  }
  command_ = std::move(command);
  read_timeout_ = read_timeout;
  stall_timeout_ = stall_timeout;
  turn_timeout_ = turn_timeout;
  policy_ = std::move(validated_policy);
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
                                        const std::filesystem::path &cwd,
                                        const AppServerPolicy& policy) {
  return protocol_detail::encode_frame(protocol_detail::Request{
      "thread/start",
      id,
      protocol_detail::ThreadStartParams{
          cwd.native(), policy.approval_policy, policy.thread_sandbox}});
}

std::string AppServerProtocol::turn_start_request(
    const std::uint64_t id, const std::string_view thread_id,
    const std::filesystem::path &cwd,
    const std::string_view prompt,
    const AppServerPolicy& policy) {
  const auto sandbox_policy = policy.turn_sandbox_policy_json
                                  ? std::optional<glz::raw_json>{
                                        *policy.turn_sandbox_policy_json}
                                  : std::nullopt;
  return protocol_detail::encode_frame(protocol_detail::Request{
      "turn/start", id,
      protocol_detail::TurnStartParams{std::string{thread_id},
                                       cwd.native(),
                                       {{"text", std::string{prompt}}},
                                       policy.approval_policy,
                                       sandbox_policy}});
}

std::string AppServerProtocol::unsupported_tool_response(
    const std::uint64_t id) {
  constexpr std::string_view message = "Unsupported dynamic tool";
  return protocol_detail::encode_frame(protocol_detail::Response{
      id,
      protocol_detail::ToolFailureResult{
          false,
          std::string{message},
          {{"inputText", std::string{message}}}}});
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
  if (message.id && !message.method) {
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
  update.response_id = message.id;
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
  else if (update.method == "item/commandExecution/requestApproval" ||
           update.method == "item/fileChange/requestApproval" ||
           update.method == "execCommandApproval" ||
           update.method == "applyPatchApproval")
    update.event = ProtocolEvent::approval_required;
  else if (update.method == "item/tool/requestUserInput")
    update.event = ProtocolEvent::user_input_required;
  else if (update.method == "item/tool/call")
    update.event = ProtocolEvent::unsupported_tool_call;
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
void FakeProtocolChannel::close() { closed_ = true; }
ProtocolChannel::ReadResult
FakeProtocolChannel::read(const std::chrono::milliseconds timeout) {
  if (reads_.empty()) {
    if (closed_) return {ReadStatus::end_of_stream, {}};
    std::this_thread::sleep_for(timeout);
    return {ReadStatus::timeout, {}};
  }
  auto line = std::move(reads_.front());
  reads_.pop_front();
  return {ReadStatus::message, std::move(line)};
}
const std::vector<std::string> &FakeProtocolChannel::writes() const noexcept {
  return writes_;
}

RunResult
AppServerConversation::run(ProtocolChannel &channel, const RunRequest &request,
                           const std::chrono::milliseconds read_timeout,
                           const std::size_t max_messages,
                           const std::chrono::milliseconds stall_timeout,
                           const std::chrono::milliseconds turn_timeout,
                           const AppServerPolicy& policy) {
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
    const auto read = channel.read(read_timeout);
    if (read.status == ProtocolChannel::ReadStatus::end_of_stream) {
      result.error = "app-server stdout closed";
      result.session_id = thread_id.empty() || turn_id.empty()
                              ? ""
                              : thread_id + '-' + turn_id;
      return result;
    }
    if (read.status == ProtocolChannel::ReadStatus::timeout) {
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
      update = AppServerProtocol::decode(read.message);
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
    if (update.event == ProtocolEvent::approval_required) {
      result.error = "app-server approval required";
      result.session_id = thread_id.empty() || turn_id.empty()
                              ? ""
                              : thread_id + '-' + turn_id;
      return result;
    }
    if (update.event == ProtocolEvent::user_input_required) {
      result.error = "app-server user input required";
      result.session_id = thread_id.empty() || turn_id.empty()
                              ? ""
                              : thread_id + '-' + turn_id;
      return result;
    }
    if (update.event == ProtocolEvent::unsupported_tool_call) {
      if (!update.response_id) {
        result.error = "unsupported tool call has no request id";
        return result;
      }
      channel.write(AppServerProtocol::unsupported_tool_response(
          *update.response_id));
      continue;
    }
    if (update.response_id == 0 && !initialized) {
      channel.write(AppServerProtocol::initialized_notification());
      channel.write(
          AppServerProtocol::thread_start_request(
              1, request.workspace.path, policy));
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
          2, thread_id, request.workspace.path, request.prompt, policy));
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
