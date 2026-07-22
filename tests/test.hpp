#pragma once

#include <functional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace test {

using Function = void (*)();
struct Case { std::string name; Function function; };
inline std::vector<Case>& registry() { static std::vector<Case> value; return value; }
struct Register {
  Register(std::string name, Function function) { registry().push_back({std::move(name), function}); }
};

template <typename Left, typename Right>
void equal(const Left& left, const Right& right, const char* expression) {
  if (!(left == right)) {
    throw std::runtime_error(std::string{"equality failed: "} + expression);
  }
}

inline void require(bool condition, const char* expression) {
  if (!condition) throw std::runtime_error(std::string{"requirement failed: "} + expression);
}

template <typename Function>
void throws(Function function, const char* expression) {
  try { function(); } catch (const std::exception&) { return; }
  throw std::runtime_error(std::string{"expected exception: "} + expression);
}

}  // namespace test

#define SYMPHONY_JOIN_INNER(a, b) a##b
#define SYMPHONY_JOIN(a, b) SYMPHONY_JOIN_INNER(a, b)
#define TEST(name) \
  static void SYMPHONY_JOIN(test_case_, __LINE__)(); \
  static ::test::Register SYMPHONY_JOIN(test_registration_, __LINE__)(name, &SYMPHONY_JOIN(test_case_, __LINE__)); \
  static void SYMPHONY_JOIN(test_case_, __LINE__)()
#define REQUIRE(expression) ::test::require(static_cast<bool>(expression), #expression)
#define REQUIRE_EQ(left, right) ::test::equal((left), (right), #left " == " #right)
#define REQUIRE_THROWS(expression) ::test::throws([&] { static_cast<void>(expression); }, #expression)

