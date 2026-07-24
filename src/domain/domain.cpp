#include "symphony/domain/domain.hpp"

#include <algorithm>
#include <iomanip>
#include <limits>
#include <sstream>

namespace symphony::domain {
namespace {
void hash_bytes(std::uint64_t& hash, std::string_view value) {
  constexpr std::uint64_t prime = 1099511628211ULL;
  for (const auto byte : value) {
    hash ^= static_cast<unsigned char>(byte);
    hash *= prime;
  }
  hash ^= 0xffU;
  hash *= prime;
}
} // namespace

ProgressFingerprint fingerprint(const ProgressSnapshot& snapshot) {
  auto paths = snapshot.changed_paths;
  auto checks = snapshot.completed_checks;
  std::ranges::sort(paths);
  std::ranges::sort(checks);
  std::uint64_t hash = 14695981039346656037ULL;
  hash_bytes(hash, snapshot.summary);
  hash_bytes(hash, snapshot.current_step);
  for (const auto& path : paths) hash_bytes(hash, path);
  for (const auto& check : checks) hash_bytes(hash, check);
  std::ostringstream value;
  value << std::hex << std::setfill('0') << std::setw(16) << hash;
  return {value.str()};
}

ProgressDecision observe_progress(Attempt& attempt, const ProgressFingerprint& current) {
  if (!attempt.last_progress || *attempt.last_progress != current) {
    attempt.last_progress = current;
    attempt.unchanged_results = 0;
    attempt.repeated_failures = 0;
    attempt.last_failure_signature.reset();
    attempt.context_state = ContextState::active;
    return ProgressDecision::progressed;
  }
  ++attempt.unchanged_results;
  if (attempt.corrective_continuations == 0) {
    ++attempt.corrective_continuations;
    attempt.context_state = ContextState::corrective_continuation;
    return ProgressDecision::corrective_continuation;
  }
  attempt.context_state = ContextState::stalled_no_progress;
  return ProgressDecision::stalled_no_progress;
}

std::chrono::milliseconds retry_delay(const std::uint32_t ordinal,
                                      const std::chrono::milliseconds base,
                                      const std::chrono::milliseconds cap) {
  if (base <= std::chrono::milliseconds::zero() || cap <= std::chrono::milliseconds::zero()) {
    return std::chrono::milliseconds::zero();
  }
  auto delay = base;
  for (std::uint32_t count = 0; count < ordinal && delay < cap; ++count) {
    if (delay > cap / 2) return cap;
    delay *= 2;
  }
  return std::min(delay, cap);
}

std::string_view to_string(const ContextState state) noexcept {
  switch (state) {
  case ContextState::fresh:
    return "fresh";
  case ContextState::active:
    return "active";
  case ContextState::corrective_continuation:
    return "corrective_continuation";
  case ContextState::stalled_no_progress:
    return "stalled_no_progress";
  case ContextState::completed:
    return "completed";
  case ContextState::failed:
    return "failed";
  }
  return "unknown";
}
} // namespace symphony::domain
