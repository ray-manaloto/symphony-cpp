#include "symphony/codex/codex.hpp"

#include <filesystem>
#include <glaze/json/generic.hpp>
#include <ut/ut.hpp>

namespace {
glz::generic_u64 parse_json(const std::string_view input) {
  glz::generic_u64 value;
  if (const auto error = glz::read_json(value, input)) {
    throw std::runtime_error(glz::format_error(error));
  }
  return value;
}
} // namespace

static ut::suite codex_tests = [] {
  ut::test("json line codec frames and validates one object") = [] {
    ut::expect(symphony::codex::JsonLineCodec::frame("{\"id\":1}") ==
               std::string{"{\"id\":1}\n"});
    ut::expect(symphony::codex::JsonLineCodec::parse("{\"id\":1}\n") ==
               std::string{"{\"id\":1}"});
    ut::expect(ut::throws([] {
      static_cast<void>(symphony::codex::JsonLineCodec::parse("not-json\n"));
    }));
    ut::expect(ut::throws([] {
      static_cast<void>(symphony::codex::JsonLineCodec::parse("{}\n{}\n"));
    }));
    ut::expect(ut::throws([] {
      static_cast<void>(
          symphony::codex::JsonLineCodec::parse("{\"unterminated\":true"));
    }));
    ut::expect(ut::throws([] {
      static_cast<void>(symphony::codex::JsonLineCodec::parse("[]"));
    }));
  };

  ut::test("fake runtime is deterministic and records cancellation") = [] {
    symphony::codex::FakeAgentRuntime runtime;
    runtime.enqueue(
        symphony::codex::RunResult{true, false, std::nullopt, "session-1", {}});
    const auto result = runtime.run({});
    ut::expect(result.normal_exit);
    ut::expect(runtime.run_count() == std::size_t{1});
    runtime.cancel("session-1");
  };

  ut::test(
      "app-server protocol follows initialize thread and turn schema") = [] {
    const auto initialize = parse_json(symphony::codex::JsonLineCodec::parse(
        symphony::codex::AppServerProtocol::initialize_request()));
    ut::expect(initialize.at("method").get<std::string>() == "initialize");
    ut::expect(initialize.at("params")
                   .at("clientInfo")
                   .at("name")
                   .get<std::string>() == "symphony_cpp");

    const auto turn = parse_json(symphony::codex::JsonLineCodec::parse(
        symphony::codex::AppServerProtocol::turn_start_request(
            2, "thr_1", "/tmp/work", "Do work")));
    ut::expect(turn.at("method").get<std::string>() == "turn/start");
    ut::expect(turn.at("params").at("threadId").get<std::string>() == "thr_1");
    ut::expect(turn.at("params").at("input")[0].at("text").get<std::string>() ==
               "Do work");

    const symphony::codex::AppServerPolicy policy{
        "never",
        "workspace-write",
        R"({"type":"workspaceWrite","networkAccess":false,"writableRoots":[]})"};
    const auto configured_thread = parse_json(
        symphony::codex::JsonLineCodec::parse(
            symphony::codex::AppServerProtocol::thread_start_request(
                1, "/tmp/work", policy)));
    ut::expect(configured_thread.at("params")
                   .at("approvalPolicy")
                   .get<std::string>() == "never");
    ut::expect(configured_thread.at("params")
                   .at("sandbox")
                   .get<std::string>() == "workspace-write");

    const auto configured_turn = parse_json(
        symphony::codex::JsonLineCodec::parse(
            symphony::codex::AppServerProtocol::turn_start_request(
                2, "thr_1", "/tmp/work", "Do work", policy)));
    ut::expect(configured_turn.at("params")
                   .at("approvalPolicy")
                   .get<std::string>() == "never");
    ut::expect(configured_turn.at("params")
                   .at("sandboxPolicy")
                   .at("type")
                   .get<std::string>() == "workspaceWrite");
  };

  ut::test(
      "app-server protocol extracts identities and terminal notifications") =
      [] {
        const auto thread = symphony::codex::AppServerProtocol::decode(
            R"({"id":1,"result":{"thread":{"id":"thr_1"}}})");
        ut::expect(thread.response_id == std::optional<std::uint64_t>{1});
        ut::expect(thread.thread_id == std::string{"thr_1"});
        const auto completed = symphony::codex::AppServerProtocol::decode(
            R"({"method":"turn/completed","params":{"turn":{"id":"turn_2"}}})");
        ut::expect(completed.event ==
                   symphony::codex::ProtocolEvent::turn_completed);
        ut::expect(completed.turn_id == std::string{"turn_2"});
      };

  ut::test("app-server protocol decodes token and sparse rate-limit telemetry") = [] {
    const auto usage = symphony::codex::AppServerProtocol::decode(
        R"({"method":"thread/tokenUsage/updated","params":{"threadId":"thr_1","turnId":"turn_2","tokenUsage":{"last":{"inputTokens":7,"cachedInputTokens":3,"outputTokens":5,"reasoningOutputTokens":2,"totalTokens":12},"total":{"inputTokens":17,"cachedInputTokens":6,"outputTokens":9,"reasoningOutputTokens":4,"totalTokens":26},"modelContextWindow":200000}}})");
    ut::expect(usage.token_usage.has_value());
    ut::expect(usage.token_usage->input_tokens == std::uint64_t{17});
    ut::expect(usage.token_usage->cached_input_tokens == std::uint64_t{6});
    ut::expect(usage.token_usage->output_tokens == std::uint64_t{9});
    ut::expect(usage.token_usage->total_tokens == std::uint64_t{26});
    ut::expect(usage.token_usage->model_context_window ==
               std::optional<std::int64_t>{200000});

    const auto limits = symphony::codex::AppServerProtocol::decode(
        R"({"method":"account/rateLimits/updated","params":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":42,"windowDurationMins":300,"resetsAt":1234}}}})");
    ut::expect(limits.rate_limits.has_value());
    ut::expect(limits.rate_limits->limit_id == std::optional<std::string>{"codex"});
    ut::expect(limits.rate_limits->primary.has_value());
    ut::expect(limits.rate_limits->primary->used_percent == 42);
  };

  ut::test("app-server protocol recognizes both compaction event shapes") = [] {
    const auto legacy = symphony::codex::AppServerProtocol::decode(
        R"({"method":"thread/compacted","params":{"threadId":"thr_1","turnId":"turn_2"}})");
    ut::expect(legacy.event ==
               symphony::codex::ProtocolEvent::context_compacted);

    const auto current = symphony::codex::AppServerProtocol::decode(
        R"({"method":"item/completed","params":{"completedAtMs":1,"threadId":"thr_1","turnId":"turn_2","item":{"id":"item_3","type":"contextCompaction"}}})");
    ut::expect(current.event ==
               symphony::codex::ProtocolEvent::context_compacted);
  };

  ut::test("app-server protocol tolerates additive fields but rejects bad "
           "ids") = [] {
    const auto additive = symphony::codex::AppServerProtocol::decode(
        R"({"id":1,"result":{"thread":{"id":"thr_1","newField":true}},"future":{}})");
    ut::expect(additive.response_id == std::optional<std::uint64_t>{1});
    ut::expect(additive.thread_id == std::string{"thr_1"});
    ut::expect(ut::throws([] {
      static_cast<void>(symphony::codex::AppServerProtocol::decode(
          R"({"id":"1","result":{}})"));
    }));
  };

  ut::test("app-server conversation performs handshake and completes a turn") =
      [] {
        symphony::codex::FakeProtocolChannel channel;
        channel.enqueue(R"({"id":0,"result":{"userAgent":"codex"}})");
        channel.enqueue(R"({"id":1,"result":{"thread":{"id":"thr_1"}}})");
        channel.enqueue(
            R"({"method":"turn/started","params":{"turn":{"id":"turn_2"}}})");
        channel.enqueue(
            R"({"method":"turn/completed","params":{"turn":{"id":"turn_2"}}})");
        symphony::codex::RunRequest request;
        request.workspace.path = "/tmp/work";
        request.prompt = "Do work";
        const auto result = symphony::codex::AppServerConversation::run(
            channel, request, std::chrono::seconds{1});
        ut::expect(result.normal_exit);
        ut::expect(result.session_id == std::string{"thr_1-turn_2"});
        ut::expect(channel.writes().size() == std::size_t{4});
      };

  ut::test("app-server conversation reuses one thread up to max turns") = [] {
    symphony::codex::FakeProtocolChannel channel;
    channel.enqueue(R"({"id":0,"result":{}})");
    channel.enqueue(R"({"id":1,"result":{"thread":{"id":"thr_1"}}})");
    channel.enqueue(
        R"({"method":"turn/started","params":{"turn":{"id":"turn_1"}}})");
    channel.enqueue(
        R"({"method":"turn/completed","params":{"turn":{"id":"turn_1"}}})");
    channel.enqueue(
        R"({"method":"turn/started","params":{"turn":{"id":"turn_2"}}})");
    channel.enqueue(
        R"({"method":"turn/completed","params":{"turn":{"id":"turn_2"}}})");
    symphony::codex::RunRequest request;
    request.workspace.path = "/tmp/work";
    request.prompt = "Full issue prompt";
    request.max_turns = 2;
    request.continuation_prompt_after_turn =
        [](const std::uint32_t completed_turns) {
          return std::optional<std::string>{
              "Continue with turn " + std::to_string(completed_turns + 1)};
        };

    const auto result = symphony::codex::AppServerConversation::run(
        channel, request, std::chrono::seconds{1});

    ut::expect(result.normal_exit);
    ut::expect(result.turns_completed == std::uint32_t{2});
    ut::expect(result.session_id == std::string{"thr_1-turn_2"});
    ut::expect(channel.writes().size() == std::size_t{5});
    const auto continuation = parse_json(
        symphony::codex::JsonLineCodec::parse(channel.writes().back()));
    ut::expect(continuation.at("method").get<std::string>() == "turn/start");
    ut::expect(continuation.at("params")
                   .at("threadId")
                   .get<std::string>() == "thr_1");
    ut::expect(continuation.at("params")
                   .at("input")[0]
                   .at("text")
                   .get<std::string>() == "Continue with turn 2");
  };

  ut::test("app-server conversation returns latest telemetry with completion") = [] {
    symphony::codex::FakeProtocolChannel channel;
    channel.enqueue(R"({"id":0,"result":{}})");
    channel.enqueue(R"({"id":1,"result":{"thread":{"id":"thr_1"}}})");
    channel.enqueue(
        R"({"method":"turn/started","params":{"turn":{"id":"turn_2"}}})");
    channel.enqueue(
        R"({"method":"thread/tokenUsage/updated","params":{"threadId":"thr_1","turnId":"turn_2","tokenUsage":{"last":{"inputTokens":4,"cachedInputTokens":1,"outputTokens":2,"reasoningOutputTokens":1,"totalTokens":6},"total":{"inputTokens":4,"cachedInputTokens":1,"outputTokens":2,"reasoningOutputTokens":1,"totalTokens":6}}}})");
    channel.enqueue(
        R"({"method":"account/rateLimits/updated","params":{"rateLimits":{"primary":{"usedPercent":9}}}})");
    channel.enqueue(
        R"({"method":"item/completed","params":{"completedAtMs":1,"threadId":"thr_1","turnId":"turn_2","item":{"id":"item_3","type":"contextCompaction"}}})");
    channel.enqueue(
        R"({"method":"turn/completed","params":{"turn":{"id":"turn_2"}}})");
    symphony::codex::RunRequest request;
    request.workspace.path = "/tmp/work";
    request.prompt = "Do work";

    const auto result = symphony::codex::AppServerConversation::run(
        channel, request, std::chrono::seconds{1});

    ut::expect(result.normal_exit);
    ut::expect(result.token_usage.has_value());
    ut::expect(result.token_usage->total_tokens == std::uint64_t{6});
    ut::expect(result.rate_limits.has_value());
    ut::expect(result.rate_limits->primary->used_percent == 9);
    ut::expect(result.compaction_count == std::uint32_t{1});
  };

  ut::test(
      "app-server conversation fails closed on timeout and malformed output") =
      [] {
        symphony::codex::RunRequest request;
        request.workspace.path = "/tmp/work";
        symphony::codex::FakeProtocolChannel timeout;
        const auto timed_out = symphony::codex::AppServerConversation::run(
            timeout, request, std::chrono::milliseconds{1});
        ut::expect(timed_out.error.find("timeout") != std::string::npos);
        symphony::codex::FakeProtocolChannel malformed;
        malformed.enqueue("not-json");
        const auto bad = symphony::codex::AppServerConversation::run(
            malformed, request, std::chrono::milliseconds{1});
        ut::expect(bad.error.find("malformed") != std::string::npos);
      };

  ut::test("app-server conversation reports stdout closure without spinning") = [] {
    symphony::codex::RunRequest request;
    request.workspace.path = "/tmp/work";
    symphony::codex::FakeProtocolChannel closed;
    closed.close();

    const auto result = symphony::codex::AppServerConversation::run(
        closed,
        request,
        std::chrono::milliseconds{1},
        100,
        std::chrono::seconds{1},
        std::chrono::seconds{1});

    ut::expect(!result.normal_exit);
    ut::expect(result.error == std::string{"app-server stdout closed"});
  };

  ut::test("app-server rejects unsupported tools and continues the turn") = [] {
    symphony::codex::FakeProtocolChannel channel;
    channel.enqueue(R"({"id":0,"result":{}})");
    channel.enqueue(R"({"id":1,"result":{"thread":{"id":"thr_1"}}})");
    channel.enqueue(
        R"({"method":"turn/started","params":{"turn":{"id":"turn_2"}}})");
    channel.enqueue(
        R"({"id":101,"method":"item/tool/call","params":{"tool":"not_advertised","arguments":{}}})");
    channel.enqueue(
        R"({"method":"turn/completed","params":{"turn":{"id":"turn_2"}}})");
    symphony::codex::RunRequest request;
    request.workspace.path = "/tmp/work";

    const auto result = symphony::codex::AppServerConversation::run(
        channel, request, std::chrono::seconds{1});

    ut::expect(result.normal_exit);
    ut::expect(channel.writes().size() == std::size_t{5});
    const auto response = parse_json(symphony::codex::JsonLineCodec::parse(
        channel.writes().back()));
    ut::expect(response.at("id").get<std::uint64_t>() == std::uint64_t{101});
    ut::expect(!response.at("result").at("success").get<bool>());
  };

  ut::test("app-server fails closed on approval and user input requests") = [] {
    const auto run_request = [](const std::string& request_message) {
      symphony::codex::FakeProtocolChannel channel;
      channel.enqueue(R"({"id":0,"result":{}})");
      channel.enqueue(R"({"id":1,"result":{"thread":{"id":"thr_1"}}})");
      channel.enqueue(
          R"({"method":"turn/started","params":{"turn":{"id":"turn_2"}}})");
      channel.enqueue(request_message);
      symphony::codex::RunRequest request;
      request.workspace.path = "/tmp/work";
      return symphony::codex::AppServerConversation::run(
          channel, request, std::chrono::seconds{1});
    };

    const auto approval = run_request(
        R"({"id":102,"method":"item/commandExecution/requestApproval","params":{}})");
    ut::expect(approval.error == std::string{"app-server approval required"});

    const auto input = run_request(
        R"({"id":103,"method":"item/tool/requestUserInput","params":{}})");
    ut::expect(input.error == std::string{"app-server user input required"});
  };

  ut::test("app-server conversation distinguishes a stalled session") = [] {
    symphony::codex::FakeProtocolChannel channel;
    channel.enqueue(R"({"id":0,"result":{}})");
    channel.enqueue(R"({"id":1,"result":{"thread":{"id":"thr_1"}}})");
    channel.enqueue(
        R"({"method":"turn/started","params":{"turn":{"id":"turn_2"}}})");
    symphony::codex::RunRequest request;
    request.workspace.path = "/tmp/work";
    request.prompt = "Do work";

    const auto result = symphony::codex::AppServerConversation::run(
        channel,
        request,
        std::chrono::milliseconds{1},
        100,
        std::chrono::milliseconds{2});

    ut::expect(result.stalled);
    ut::expect(!result.normal_exit);
    ut::expect(result.error == std::string{"app-server stalled"});
    ut::expect(result.session_id == std::string{"thr_1-turn_2"});
  };

  ut::test("disabled stall detection retains the independent turn deadline") = [] {
    symphony::codex::FakeProtocolChannel channel;
    symphony::codex::RunRequest request;
    request.workspace.path = "/tmp/work";

    const auto result = symphony::codex::AppServerConversation::run(
        channel,
        request,
        std::chrono::milliseconds{1},
        100,
        std::chrono::milliseconds{0},
        std::chrono::milliseconds{2});

    ut::expect(!result.stalled);
    ut::expect(result.timed_out);
    ut::expect(result.error == std::string{"app-server turn timeout"});
  };

  ut::test(
      "Codex runtime launches JSONL app-server in the issue workspace") = [] {
    const auto root =
        std::filesystem::temp_directory_path() / "symphony-codex-runtime-test";
    std::filesystem::create_directories(root);
    const std::string command =
        "printf '%s\\n' "
        "'{\"id\":0,\"result\":{}}' "
        "'{\"id\":1,\"result\":{\"thread\":{\"id\":\"thr_fixture\"}}}' "
        "'{\"method\":\"turn/"
        "started\",\"params\":{\"turn\":{\"id\":\"turn_fixture\"}}}' "
        "'{\"method\":\"turn/"
        "completed\",\"params\":{\"turn\":{\"id\":\"turn_fixture\"}}}'; "
        "cat >/dev/null";
    symphony::codex::CodexAppServerRuntime runtime(command,
                                                   std::chrono::seconds{1});
    symphony::codex::RunRequest request;
    request.workspace.path = std::filesystem::absolute(root);
    request.prompt = "fixture";
    const auto result = runtime.run(request);
    ut::expect(result.normal_exit);
    ut::expect(result.session_id == std::string{"thr_fixture-turn_fixture"});
    std::filesystem::remove_all(root);
  };

  ut::test("Codex runtime rejects non-object turn sandbox policy") = [] {
    ut::expect(ut::throws([] {
      static_cast<void>(symphony::codex::CodexAppServerRuntime{
          "true",
          std::chrono::seconds{1},
          std::chrono::seconds{1},
          std::chrono::seconds{1},
          symphony::codex::AppServerPolicy{
              std::nullopt, std::nullopt, "[]"}});
    }));
  };

};
