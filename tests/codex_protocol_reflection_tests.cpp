#include <ut/ut.hpp>

#include <array>
#include <concepts>
#include <cstddef>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "protocol_detail.hpp"
#include "symphony/meta/reflection.hpp"

#if defined(SYMPHONY_ENABLE_REFLECTION)
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
} // namespace

ut::suite codex_protocol_reflection_tests = [] {
  ut::test("Codex startup DTOs retain their exact declared field order") = [] {
    using namespace codex::protocol_detail;

    static_assert(has_exact_fields<ClientInfo>(
        std::array<std::string_view, 3>{"name", "title", "version"}));
    static_assert(has_exact_fields<InitializeParams>(
        std::array<std::string_view, 1>{"clientInfo"}));
    static_assert(has_exact_fields<ThreadStartParams>(
        std::array<std::string_view, 4>{"cwd", "approvalPolicy", "sandbox", "model"}));
    static_assert(has_exact_fields<TurnInput>(
        std::array<std::string_view, 2>{"type", "text"}));
    static_assert(has_exact_fields<TurnStartParams>(std::array<std::string_view, 7>{
        "threadId", "cwd", "input", "approvalPolicy", "sandboxPolicy", "model", "effort"}));

    static_assert(std::same_as<decltype(ClientInfo::name), std::string>);
    static_assert(std::same_as<decltype(ClientInfo::title), std::string>);
    static_assert(std::same_as<decltype(ClientInfo::version), std::string>);
    static_assert(std::same_as<decltype(InitializeParams::clientInfo), ClientInfo>);
    static_assert(std::same_as<decltype(ThreadStartParams::cwd), std::string>);
    static_assert(
        std::same_as<decltype(ThreadStartParams::approvalPolicy), std::optional<std::string>>);
    static_assert(std::same_as<decltype(ThreadStartParams::sandbox), std::optional<std::string>>);
    static_assert(std::same_as<decltype(ThreadStartParams::model), std::optional<std::string>>);
    static_assert(std::same_as<decltype(TurnInput::type), std::string>);
    static_assert(std::same_as<decltype(TurnInput::text), std::string>);
    static_assert(std::same_as<decltype(TurnStartParams::threadId), std::string>);
    static_assert(std::same_as<decltype(TurnStartParams::cwd), std::string>);
    static_assert(std::same_as<decltype(TurnStartParams::input), std::vector<TurnInput>>);
    static_assert(
        std::same_as<decltype(TurnStartParams::approvalPolicy), std::optional<std::string>>);
    static_assert(
        std::same_as<decltype(TurnStartParams::sandboxPolicy), std::optional<glz::raw_json>>);
    static_assert(std::same_as<decltype(TurnStartParams::model), std::optional<std::string>>);
    static_assert(std::same_as<decltype(TurnStartParams::effort), std::optional<std::string>>);
  };
};
} // namespace symphony::test
#endif
