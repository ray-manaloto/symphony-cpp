#include <cstdlib>
#include <string_view>

#if !defined(__has_feature) || !__has_feature(realtime_sanitizer)
#error "The RTSan violation fixture must be compiled with RealtimeSanitizer"
#endif

namespace {

volatile int blocking_marker = 0;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wfunction-effects"

[[gnu::noinline]] void allocate_in_nonblocking_context() noexcept [[clang::nonblocking]] {
  void* storage = std::malloc(64);
  if (storage != nullptr) {
    static_cast<volatile unsigned char*>(storage)[0] = 1;
  }
  std::free(storage);
}

[[gnu::noinline]] void explicitly_blocking_operation() noexcept [[clang::blocking]] {
  blocking_marker = 1;
}

[[gnu::noinline]] void call_blocking_operation() noexcept [[clang::nonblocking]] {
  explicitly_blocking_operation();
}

#pragma clang diagnostic pop

} // namespace

int main(int argc, char** argv) {
  if (argc != 2) {
    return 64;
  }

  const std::string_view mode{argv[1]};
  if (mode == "allocation") {
    allocate_in_nonblocking_context();
    return 0;
  }
  if (mode == "blocking") {
    call_blocking_operation();
    return 0;
  }
  return 64;
}
