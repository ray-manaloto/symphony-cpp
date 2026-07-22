#pragma once

#include <string>
#include <concepts>
#include <string_view>
#include <vector>
#include <type_traits>
#include <utility>

#include <nlohmann/json.hpp>

#if defined(SYMPHONY_ENABLE_REFLECTION)
#include <meta>
#endif

namespace symphony::meta {

struct FieldDescriptor {
  std::string name;
  std::string type;
};

template <typename T>
[[nodiscard]] std::vector<FieldDescriptor> fields() {
#if defined(SYMPHONY_ENABLE_REFLECTION)
  std::vector<FieldDescriptor> result;
  static constexpr auto members = std::define_static_array(
      std::meta::nonstatic_data_members_of(
          ^^T, std::meta::access_context::current()));
  template for (constexpr auto member : members) {
    result.push_back({
        std::string{std::meta::identifier_of(member)},
        std::string{std::meta::display_string_of(std::meta::type_of(member))}});
  }
  return result;
#else
  static_assert(sizeof(T) == 0, "symphony_meta reflection requires SYMPHONY_ENABLE_REFLECTION");
  return {};
#endif
}

[[nodiscard]] std::string json_escape(std::string_view input);

template <typename T>
[[nodiscard]] nlohmann::json reflected_json(const T& object) {
#if defined(SYMPHONY_ENABLE_REFLECTION)
  nlohmann::json result = nlohmann::json::object();
  static constexpr auto members = std::define_static_array(
      std::meta::nonstatic_data_members_of(
          ^^T, std::meta::access_context::current()));
  template for (constexpr auto member : members) {
    result[std::string{std::meta::identifier_of(member)}] = object.[:member:];
  }
  return result;
#else
  static_assert(sizeof(T) == 0, "reflected JSON requires SYMPHONY_ENABLE_REFLECTION");
  return {};
#endif
}

template <typename T>
[[nodiscard]] nlohmann::json reflected_schema() {
#if defined(SYMPHONY_ENABLE_REFLECTION)
  nlohmann::json properties = nlohmann::json::object();
  nlohmann::json required = nlohmann::json::array();
  static constexpr auto members = std::define_static_array(
      std::meta::nonstatic_data_members_of(
          ^^T, std::meta::access_context::current()));
  template for (constexpr auto member : members) {
    using Member = std::remove_cvref_t<decltype(std::declval<T>().[:member:])>;
    std::string type = "object";
    if constexpr (std::same_as<Member, bool>) type = "boolean";
    else if constexpr (std::integral<Member>) type = "integer";
    else if constexpr (std::floating_point<Member>) type = "number";
    else if constexpr (std::convertible_to<Member, std::string_view>) type = "string";
    const std::string name{std::meta::identifier_of(member)};
    properties[name] = {{"type", type}};
    required.push_back(name);
  }
  return {{"type", "object"}, {"properties", properties}, {"required", required}};
#else
  static_assert(sizeof(T) == 0, "reflected schema requires SYMPHONY_ENABLE_REFLECTION");
  return {};
#endif
}

}  // namespace symphony::meta
