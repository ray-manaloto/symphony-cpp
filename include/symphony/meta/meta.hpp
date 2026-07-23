#pragma once

#include <concepts>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#include <glaze/glaze.hpp>
#include <glaze/json/schema.hpp>

#include "symphony/meta/reflection.hpp"

namespace symphony::meta {

template <typename T>
[[nodiscard]] std::string reflected_json(const T &object) {
  auto result = glz::write_json(object);
  if (!result) {
    throw std::runtime_error("Glaze could not serialize reflected object: " +
                             glz::format_error(result.error()));
  }
  return std::move(*result);
}

template <typename T> [[nodiscard]] std::string reflected_schema() {
  auto result = glz::write_json_schema<T>();
  if (!result) {
    throw std::runtime_error("Glaze could not generate reflected schema: " +
                             glz::format_error(result.error()));
  }
  return std::move(*result);
}

} // namespace symphony::meta
