#include <meta>
#include <string_view>

struct reflection_probe {
  int value;
};

consteval bool reflection_works() {
  static constexpr auto members =
      std::define_static_array(std::meta::nonstatic_data_members_of(
          ^^reflection_probe, std::meta::access_context::current()));
  static_assert(members.size() == 1);
  template for (constexpr auto member : members) {
    static_assert(
        std::meta::identifier_of(member) == std::string_view{"value"});
  }
  return true;
}

static_assert(reflection_works());

int main() {}
