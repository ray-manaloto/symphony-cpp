#include "symphony/codex/codex.hpp"
#include "test.hpp"

TEST("json line codec frames and validates one object") {
  REQUIRE_EQ(symphony::codex::JsonLineCodec::frame("{\"id\":1}"), std::string{"{\"id\":1}\n"});
  REQUIRE_EQ(symphony::codex::JsonLineCodec::parse("{\"id\":1}\n"), std::string{"{\"id\":1}"});
  REQUIRE_THROWS(symphony::codex::JsonLineCodec::parse("not-json\n"));
  REQUIRE_THROWS(symphony::codex::JsonLineCodec::parse("{}\n{}\n"));
}

TEST("fake runtime is deterministic and records cancellation") {
  symphony::codex::FakeAgentRuntime runtime;
  runtime.enqueue(symphony::codex::RunResult{true, false, std::nullopt, "session-1", {}});
  const auto result = runtime.run({});
  REQUIRE(result.normal_exit);
  REQUIRE_EQ(runtime.run_count(), std::size_t{1});
  runtime.cancel("session-1");
}
