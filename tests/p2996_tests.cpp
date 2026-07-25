#include <ut/ut.hpp>

#include <array>
#include <cstddef>
#include <string_view>
#include <type_traits>

#include "symphony/meta/reflection.hpp"

#if !defined(SYMPHONY_ENABLE_REFLECTION)
#error "p2996 differential test requires reflection"
#endif

namespace symphony::test {
struct DifferentialConfig {
  int poll_interval_ms;
  bool enabled;
};

enum class DifferentialState { queued, running, stopped };
enum class EmptyDifferentialState {};

ut::suite p2996_tests = [] {
  ut::test("P2996 differential enumerates fields without registration") = [] {
    static constexpr auto fields = symphony::meta::fields<DifferentialConfig>();
    static_assert(fields.size() == std::size_t{2});
    static_assert(fields[0].name == "poll_interval_ms");
    static_assert(fields[0].type == "int");
    static_assert(fields[1].name == "enabled");
    static_assert(fields[1].type == "bool");

    ut::expect(fields.size() == std::size_t{2});
    ut::expect(fields[0].name == "poll_interval_ms");
    ut::expect(fields[0].type == "int");
    ut::expect(fields[1].name == "enabled");
    ut::expect(fields[1].type == "bool");
  };

  ut::test("P2996 differential generates exhaustive runtime-allocation-free enum names") = [] {
    static constexpr auto names = symphony::meta::enum_names<DifferentialState>();
    static_assert(
        std::is_same_v<decltype(names), const std::array<std::string_view, std::size_t{3}>>);
    static_assert(names.size() == std::size_t{3});
    static_assert(names[0] == std::string_view{"queued"});
    static_assert(names[1] == std::string_view{"running"});
    static_assert(names[2] == std::string_view{"stopped"});

    ut::expect(names.size() == std::size_t{3});
    ut::expect(names[0] == std::string_view{"queued"});
    ut::expect(names[1] == std::string_view{"running"});
    ut::expect(names[2] == std::string_view{"stopped"});

    static constexpr auto empty_names = symphony::meta::enum_names<EmptyDifferentialState>();
    static_assert(
        std::is_same_v<decltype(empty_names), const std::array<std::string_view, std::size_t{0}>>);
    static_assert(empty_names.empty());
    ut::expect(empty_names.empty());
  };
};
} // namespace symphony::test
