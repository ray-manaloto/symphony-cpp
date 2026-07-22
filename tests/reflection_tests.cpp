#include <ut/ut.hpp>

#include "symphony/meta/meta.hpp"

#if defined(SYMPHONY_ENABLE_REFLECTION)
namespace {
struct ReflectedConfig {
  int poll_interval_ms;
  bool enabled;
};

ut::suite reflection_tests = [] {
  ut::test(
      "C++26 reflection enumerates schema fields without registration") = [] {
    const auto fields = symphony::meta::fields<ReflectedConfig>();
    ut::expect(fields.size() == std::size_t{2});
    ut::expect(fields[0].name == std::string{"poll_interval_ms"});
    ut::expect(fields[0].type == std::string{"int"});
    ut::expect(fields[1].name == std::string{"enabled"});
    ut::expect(fields[1].type == std::string{"bool"});

    const ReflectedConfig value{250, true};
    const auto json = symphony::meta::reflected_json(value);
    ut::expect(json.at("poll_interval_ms") == 250);
    ut::expect(json.at("enabled") == true);
    const auto schema = symphony::meta::reflected_schema<ReflectedConfig>();
    ut::expect(schema.at("properties").at("poll_interval_ms").at("type") ==
               "integer");
    ut::expect(schema.at("properties").at("enabled").at("type") == "boolean");
  };
};
} // namespace
#endif
