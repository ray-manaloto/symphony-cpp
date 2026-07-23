#include <ut/ut.hpp>

#include <cstddef>
#include <string>

#include "symphony/meta/reflection.hpp"

#if defined(SYMPHONY_ENABLE_REFLECTION)
namespace symphony::test {
struct DifferentialConfig {
  int poll_interval_ms;
  bool enabled;
};

ut::suite p2996_tests = [] {
  ut::test("P2996 differential enumerates fields without registration") = [] {
    const auto fields = symphony::meta::fields<DifferentialConfig>();
    ut::expect(fields.size() == std::size_t{2});
    ut::expect(fields[0].name == std::string{"poll_interval_ms"});
    ut::expect(fields[0].type == std::string{"int"});
    ut::expect(fields[1].name == std::string{"enabled"});
    ut::expect(fields[1].type == std::string{"bool"});
  };
};
} // namespace symphony::test
#endif
