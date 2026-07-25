#include <glaze/json/generic.hpp>
#include <ut/ut.hpp>

#include <array>
#include <cstdint>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>
#include <type_traits>

#include "symphony/meta/meta.hpp"

#if defined(SYMPHONY_ENABLE_REFLECTION)
namespace symphony::test {
struct ReflectedConfig {
  int poll_interval_ms;
  bool enabled;
};

enum class ReflectedState { queued, running, stopped };
enum class EmptyReflectedState {};

glz::generic_u64 parse_json(const std::string_view input) {
  glz::generic_u64 value;
  if (const auto error = glz::read_json(value, input)) {
    throw std::runtime_error(glz::format_error(error));
  }
  return value;
}

std::optional<std::string> schema_property_type(const glz::generic_u64& schema,
                                                const std::string_view property_name) {
  if (!schema.contains("properties")) return std::nullopt;
  const auto& properties = schema.at("properties");
  if (!properties.contains(property_name)) return std::nullopt;
  const auto& property = properties.at(property_name);
  if (property.contains("type")) return property.at("type").get<std::string>();
  if (!property.contains("$ref") || !schema.contains("$defs")) return std::nullopt;
  const auto& reference = property.at("$ref").get<std::string>();
  const auto separator = reference.find_last_of('/');
  if (separator == std::string::npos) return std::nullopt;
  const auto definition_name = std::string_view{reference}.substr(separator + 1);
  const auto& definitions = schema.at("$defs");
  if (!definitions.contains(definition_name)) return std::nullopt;
  const auto& definition = definitions.at(definition_name);
  if (!definition.contains("type")) return std::nullopt;
  return definition.at("type").get<std::string>();
}

ut::suite reflection_tests = [] {
  ut::test("C++26 reflection enumerates schema fields without registration") = [] {
    static constexpr auto fields = symphony::meta::fields<ReflectedConfig>();
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

    const ReflectedConfig value{250, true};
    const auto json = parse_json(symphony::meta::reflected_json(value));
    ut::expect(json.at("poll_interval_ms").get<std::uint64_t>() == 250);
    ut::expect(json.at("enabled").get<bool>());
    const auto schema = parse_json(symphony::meta::reflected_schema<ReflectedConfig>());
    ut::expect(schema_property_type(schema, "poll_interval_ms") ==
               std::optional<std::string>{"integer"});
    ut::expect(schema_property_type(schema, "enabled") == std::optional<std::string>{"boolean"});
  };

  ut::test("C++26 reflection generates exhaustive runtime-allocation-free enum names") = [] {
    static constexpr auto names = symphony::meta::enum_names<ReflectedState>();
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

    static constexpr auto empty_names = symphony::meta::enum_names<EmptyReflectedState>();
    static_assert(
        std::is_same_v<decltype(empty_names), const std::array<std::string_view, std::size_t{0}>>);
    static_assert(empty_names.empty());
    ut::expect(empty_names.empty());
  };
};
} // namespace symphony::test
#endif
