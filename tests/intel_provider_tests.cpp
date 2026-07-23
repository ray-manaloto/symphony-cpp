#include <async/concepts.hpp>
#include <async/just.hpp>
#include <conc/concurrency.hpp>
#include <stdx/ct_string.hpp>

#include <ut/ut.hpp>

using namespace stdx::ct_string_literals;

static_assert("symphony"_cts.size() == 8U);
static_assert(
    async::sender_of<decltype(async::just(42)), async::set_value_t(int)>);

static ut::suite intel_provider_tests = [] {
  ut::test("Intel hosted concurrency policy enters a critical section") = [] {
    const auto value =
        conc::call_in_critical_section([] { return 42; });
    ut::expect(value == 42);
  };
};
