#include "symphony/codex/codex.hpp"

#include <filesystem>
#include <nlohmann/json.hpp>
#include <ut/ut.hpp>

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

  ut::test("app-server protocol follows initialize thread and turn schema") =
      [] {
        const auto initialize =
            nlohmann::json::parse(symphony::codex::JsonLineCodec::parse(
                symphony::codex::AppServerProtocol::initialize_request()));
        ut::expect(initialize.at("method") == "initialize");
        ut::expect(initialize.at("params").at("clientInfo").at("name") ==
                   "symphony_cpp");

        const auto turn =
            nlohmann::json::parse(symphony::codex::JsonLineCodec::parse(
                symphony::codex::AppServerProtocol::turn_start_request(
                    2, "thr_1", "/tmp/work", "Do work")));
        ut::expect(turn.at("method") == "turn/start");
        ut::expect(turn.at("params").at("threadId") == "thr_1");
        ut::expect(turn.at("params").at("input").at(0).at("text") == "Do work");
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
};
