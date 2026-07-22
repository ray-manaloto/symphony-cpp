#include <glaze/json/generic.hpp>
#include <ut/ut.hpp>

#include "symphony/meta/meta.hpp"

#if defined(SYMPHONY_ENABLE_REFLECTION)
namespace symphony::test {
struct ReflectedConfig {
  int poll_interval_ms;
  bool enabled;
};

glz::generic_u64 parse_json(const std::string_view input) {
  glz::generic_u64 value;
  if (const auto error = glz::read_json(value, input)) {
    throw std::runtime_error(glz::format_error(error));
  }
  return value;
}

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
    const auto json = parse_json(symphony::meta::reflected_json(value));
    ut::expect(json.at("poll_interval_ms").get<std::uint64_t>() == 250);
    ut::expect(json.at("enabled").get<bool>());
    const auto schema =
        parse_json(symphony::meta::reflected_schema<ReflectedConfig>());
    ut::expect(schema.at("properties")
                   .at("poll_interval_ms")
                   .at("type")
                   .get<std::string>() == "integer");
    ut::expect(
        schema.at("properties").at("enabled").at("type").get<std::string>() ==
        "boolean");
  };
};
} // namespace symphony::test
#endif
