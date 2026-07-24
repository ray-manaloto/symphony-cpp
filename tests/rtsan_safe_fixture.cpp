#if !defined(__has_feature) || !__has_feature(realtime_sanitizer)
#error "The RTSan safe fixture must be compiled with RealtimeSanitizer"
#endif

namespace {

volatile int operation_marker = 0;

[[gnu::noinline]] void nonblocking_operation() noexcept [[clang::nonblocking]] {
  operation_marker = 1;
}

} // namespace

int main() {
  nonblocking_operation();
  return 0;
}
