#include <ut/ut.hpp>

#include <array>
#include <concepts>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "symphony/meta/reflection.hpp"
#include "workflow_detail.hpp"

namespace symphony::test {
namespace {
template <typename T, std::size_t Size>
consteval bool has_exact_fields(const std::array<std::string_view, Size>& expected) {
  constexpr auto actual = meta::fields<T>();
  if constexpr (actual.size() != Size) {
    return false;
  }
  for (std::size_t index = 0; index < Size; ++index) {
    if (actual[index].name != expected[index]) {
      return false;
    }
  }
  return true;
}

template <typename Member>
concept OptionalString = std::same_as<Member, std::optional<std::string>>;

template <typename Member>
concept OptionalUnsigned = std::same_as<Member, std::optional<std::uint64_t>>;
} // namespace

ut::suite workflow_dto_reflection_tests = [] {
  ut::test("workflow DTOs retain exact known decoded fields") = [] {
    using namespace workflow::detail;

    static_assert(has_exact_fields<RawPolling>(
        std::array<std::string_view, 1>{"interval_ms"}));
    static_assert(has_exact_fields<RawWorkspace>(
        std::array<std::string_view, 1>{"root"}));
    static_assert(has_exact_fields<RawAgent>(std::array<std::string_view, 4>{
        "max_concurrent_agents", "max_turns", "max_retry_backoff_ms",
        "max_concurrent_agents_by_state"}));
    static_assert(has_exact_fields<RawHooks>(std::array<std::string_view, 5>{
        "timeout_ms", "after_create", "before_run", "after_run", "before_remove"}));
    static_assert(has_exact_fields<RawCodex>(std::array<std::string_view, 13>{
        "command", "model", "reasoning_effort", "escalation_model",
        "escalation_reasoning_effort", "repeated_failure_reasoning_effort",
        "context_rollover_percent", "approval_policy", "thread_sandbox",
        "turn_sandbox_policy", "turn_timeout_ms", "read_timeout_ms", "stall_timeout_ms"}));
    static_assert(has_exact_fields<RawTracker>(std::array<std::string_view, 5>{
        "kind", "provider", "required_labels", "active_states", "terminal_states"}));
    static_assert(has_exact_fields<RawWorkflow>(std::array<std::string_view, 6>{
        "tracker", "polling", "workspace", "agent", "hooks", "codex"}));

    static_assert(OptionalUnsigned<decltype(RawPolling::interval_ms)>);
    static_assert(OptionalString<decltype(RawWorkspace::root)>);
    static_assert(OptionalUnsigned<decltype(RawAgent::max_concurrent_agents)>);
    static_assert(OptionalUnsigned<decltype(RawAgent::max_turns)>);
    static_assert(OptionalUnsigned<decltype(RawAgent::max_retry_backoff_ms)>);
    static_assert(std::same_as<decltype(RawAgent::max_concurrent_agents_by_state),
                               std::optional<glz::generic_u64>>);
    static_assert(OptionalUnsigned<decltype(RawHooks::timeout_ms)>);
    static_assert(OptionalString<decltype(RawHooks::after_create)>);
    static_assert(OptionalString<decltype(RawHooks::before_run)>);
    static_assert(OptionalString<decltype(RawHooks::after_run)>);
    static_assert(OptionalString<decltype(RawHooks::before_remove)>);
    static_assert(OptionalString<decltype(RawCodex::command)>);
    static_assert(OptionalString<decltype(RawCodex::model)>);
    static_assert(OptionalString<decltype(RawCodex::reasoning_effort)>);
    static_assert(OptionalString<decltype(RawCodex::escalation_model)>);
    static_assert(OptionalString<decltype(RawCodex::escalation_reasoning_effort)>);
    static_assert(OptionalString<decltype(RawCodex::repeated_failure_reasoning_effort)>);
    static_assert(OptionalUnsigned<decltype(RawCodex::context_rollover_percent)>);
    static_assert(OptionalString<decltype(RawCodex::approval_policy)>);
    static_assert(OptionalString<decltype(RawCodex::thread_sandbox)>);
    static_assert(OptionalString<decltype(RawCodex::turn_sandbox_policy)>);
    static_assert(OptionalUnsigned<decltype(RawCodex::turn_timeout_ms)>);
    static_assert(OptionalUnsigned<decltype(RawCodex::read_timeout_ms)>);
    static_assert(
        std::same_as<decltype(RawCodex::stall_timeout_ms), std::optional<std::int64_t>>);
    static_assert(OptionalString<decltype(RawTracker::kind)>);
    static_assert(
        std::same_as<decltype(RawTracker::provider), std::optional<glz::generic_u64>>);
    static_assert(std::same_as<decltype(RawTracker::required_labels),
                               std::optional<std::vector<std::string>>>);
    static_assert(std::same_as<decltype(RawTracker::active_states),
                               std::optional<std::vector<std::string>>>);
    static_assert(std::same_as<decltype(RawTracker::terminal_states),
                               std::optional<std::vector<std::string>>>);
    static_assert(std::same_as<decltype(RawWorkflow::tracker), std::optional<RawTracker>>);
    static_assert(std::same_as<decltype(RawWorkflow::polling), std::optional<RawPolling>>);
    static_assert(std::same_as<decltype(RawWorkflow::workspace), std::optional<RawWorkspace>>);
    static_assert(std::same_as<decltype(RawWorkflow::agent), std::optional<RawAgent>>);
    static_assert(std::same_as<decltype(RawWorkflow::hooks), std::optional<RawHooks>>);
    static_assert(std::same_as<decltype(RawWorkflow::codex), std::optional<RawCodex>>);
  };
};
} // namespace symphony::test
