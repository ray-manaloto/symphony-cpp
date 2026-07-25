#pragma once

#include <array>
#include <cstddef>
#include <string_view>

#if defined(SYMPHONY_ENABLE_REFLECTION)
#include <meta>
#endif

namespace symphony::meta {

struct FieldDescriptor {
  std::string_view name;
  std::string_view type;
};

template <typename T> [[nodiscard]] consteval auto fields() {
#if defined(SYMPHONY_ENABLE_REFLECTION)
  static constexpr auto members = std::define_static_array(
      std::meta::nonstatic_data_members_of(^^T, std::meta::access_context::current()));
  std::array<FieldDescriptor, members.size()> result{};
  std::size_t index = 0;
  template for (constexpr auto member : members) {
    result[index++] = {
        std::meta::identifier_of(member),
        std::meta::display_string_of(std::meta::type_of(member)),
    };
  }
  return result;
#else
  static_assert(sizeof(T) == 0, "symphony_meta reflection requires SYMPHONY_ENABLE_REFLECTION");
  return std::array<FieldDescriptor, 0>{};
#endif
}

template <typename E> [[nodiscard]] consteval auto enum_names() {
#if defined(SYMPHONY_ENABLE_REFLECTION)
  static constexpr auto enumerators =
      std::define_static_array(std::meta::enumerators_of(^^E));
  std::array<std::string_view, enumerators.size()> result{};
  [[maybe_unused]] std::size_t index = 0;
  template for (constexpr auto enumerator : enumerators) {
    result[index++] = std::meta::identifier_of(enumerator);
  }
  return result;
#else
  static_assert(sizeof(E) == 0, "symphony_meta reflection requires SYMPHONY_ENABLE_REFLECTION");
  return std::array<std::string_view, 0>{};
#endif
}

} // namespace symphony::meta
