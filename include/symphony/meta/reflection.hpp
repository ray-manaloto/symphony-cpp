#pragma once

#include <string>
#include <vector>

#if defined(SYMPHONY_ENABLE_REFLECTION)
#include <meta>
#endif

namespace symphony::meta {

struct FieldDescriptor {
  std::string name;
  std::string type;
};

template <typename T> [[nodiscard]] std::vector<FieldDescriptor> fields() {
#if defined(SYMPHONY_ENABLE_REFLECTION)
  std::vector<FieldDescriptor> result;
  static constexpr auto members =
      std::define_static_array(std::meta::nonstatic_data_members_of(
          ^^T, std::meta::access_context::current()));
  template for (constexpr auto member : members) {
    result.push_back({std::string{std::meta::identifier_of(member)},
                      std::string{std::meta::display_string_of(
                          std::meta::type_of(member))}});
  }
  return result;
#else
  static_assert(sizeof(T) == 0,
                "symphony_meta reflection requires SYMPHONY_ENABLE_REFLECTION");
  return {};
#endif
}

} // namespace symphony::meta
