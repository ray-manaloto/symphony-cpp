#include <ut/ut.hpp>

#include <cstddef>

#include "symphony/meta/reflection.hpp"

#if !defined(SYMPHONY_ENABLE_REFLECTION)
#error "p2996 differential test requires reflection"
#endif

namespace symphony::test {
struct DifferentialConfig {
  int poll_interval_ms;
  bool enabled;
};

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
};
} // namespace symphony::test
