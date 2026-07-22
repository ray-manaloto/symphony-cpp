#include "symphony/meta/meta.hpp"

#include <cstdio>

namespace symphony::meta {
std::string json_escape(const std::string_view input) {
  std::string result;
  result.reserve(input.size());
  for (const unsigned char character : input) {
    switch (character) {
      case '"': result += "\\\""; break;
      case '\\': result += "\\\\"; break;
      case '\b': result += "\\b"; break;
      case '\f': result += "\\f"; break;
      case '\n': result += "\\n"; break;
      case '\r': result += "\\r"; break;
      case '\t': result += "\\t"; break;
      default:
        if (character < 0x20U) {
          char encoded[7]{};
          std::snprintf(encoded, sizeof(encoded), "\\u%04x", character);
          result += encoded;
        } else {
          result += static_cast<char>(character);
        }
    }
  }
  return result;
}
}  // namespace symphony::meta

