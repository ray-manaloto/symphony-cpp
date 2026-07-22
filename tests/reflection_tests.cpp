#include "symphony/meta/meta.hpp"
#include "test.hpp"

#if defined(SYMPHONY_ENABLE_REFLECTION)
namespace {
struct ReflectedConfig {
  int poll_interval_ms;
  bool enabled;
};
}  // namespace

TEST("C++26 reflection enumerates schema fields without registration") {
  const auto fields = symphony::meta::fields<ReflectedConfig>();
  REQUIRE_EQ(fields.size(), std::size_t{2});
  REQUIRE_EQ(fields[0].name, std::string{"poll_interval_ms"});
  REQUIRE_EQ(fields[0].type, std::string{"int"});
  REQUIRE_EQ(fields[1].name, std::string{"enabled"});
  REQUIRE_EQ(fields[1].type, std::string{"bool"});

  const ReflectedConfig value{250, true};
  const auto json = symphony::meta::reflected_json(value);
  REQUIRE_EQ(json.at("poll_interval_ms"), 250);
  REQUIRE_EQ(json.at("enabled"), true);
  const auto schema = symphony::meta::reflected_schema<ReflectedConfig>();
  REQUIRE_EQ(schema.at("properties").at("poll_interval_ms").at("type"), "integer");
  REQUIRE_EQ(schema.at("properties").at("enabled").at("type"), "boolean");
}
#endif
