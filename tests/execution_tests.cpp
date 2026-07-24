#include <ut/ut.hpp>

#include <atomic>
#include <chrono>
#include <cstddef>
#include <latch>
#include <stdexcept>
#include <string_view>
#include <thread>
#include <tuple>
#include <utility>

#include <exec/static_thread_pool.hpp>
#include <stdexec/execution.hpp>

#include "symphony/execution/execution.hpp"

static ut::suite execution_tests = [] {
  ut::test("stdexec keyed executor serializes and carries queued cancellation") = [] {
    symphony::execution::StdexecTaskExecutor executor{1};
    std::latch first_started{1};
    std::latch release_first{1};
    std::atomic<bool> first_finished{false};
    std::atomic<bool> second_saw_stop{false};
    std::atomic<bool> second_after_first{false};

    executor.submit("first", [&](std::stop_token) noexcept {
      first_started.count_down();
      release_first.wait();
      first_finished.store(true);
    });
    first_started.wait();

    executor.submit("second", [&](const std::stop_token stop_token) noexcept {
      second_saw_stop.store(stop_token.stop_requested());
      second_after_first.store(first_finished.load());
    });
    ut::expect(executor.request_stop("second"));
    release_first.count_down();
    executor.drain();

    ut::expect(second_saw_stop.load());
    ut::expect(second_after_first.load());
    ut::expect(!executor.request_stop("second"));
  };

  ut::test("stdexec parallel pool propagates completion channels") = [] {
    exec::static_thread_pool pool{2};
    const auto scheduler = pool.get_scheduler();
    std::atomic<int> active{0};
    std::atomic<int> peak{0};

    const auto task = [&](const int value) {
      return stdexec::schedule(scheduler) | stdexec::then([&, value] {
               active.fetch_add(1);
               const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds{2};
               while (active.load() < 2 && std::chrono::steady_clock::now() < deadline) {
                 std::this_thread::yield();
               }
               const auto current = active.load();
               auto observed = peak.load();
               while (observed < current && !peak.compare_exchange_weak(observed, current)) {
               }
               active.fetch_sub(1);
               return value;
             });
    };

    const auto values = stdexec::sync_wait(stdexec::when_all(task(2), task(3)));

    ut::expect(values.has_value());
    ut::expect(std::get<0>(*values) == 2);
    ut::expect(std::get<1>(*values) == 3);
    ut::expect(peak.load() == 2);

    bool received_error = false;
    try {
      static_cast<void>(stdexec::sync_wait(stdexec::just() | stdexec::then([]() -> int {
                                             throw std::runtime_error("fixture execution failure");
                                           })));
    } catch (const std::runtime_error& error) {
      received_error = std::string_view{error.what()} == "fixture execution failure";
    }
    ut::expect(received_error);

    const auto recovered =
        stdexec::sync_wait(stdexec::just_stopped() | stdexec::upon_stopped([] { return 7; }));
    ut::expect(recovered.has_value());
    ut::expect(std::get<0>(*recovered) == 7);
  };
};
