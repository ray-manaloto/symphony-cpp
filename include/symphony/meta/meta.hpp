#pragma once

#include <string>
#include <string_view>
#include <vector>

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
  template for (constexpr auto member : std::meta::nonstatic_data_members_of(
                    ^^T, std::meta::access_context::current())) {
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

}  // namespace symphony::meta
