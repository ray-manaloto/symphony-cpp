#include "symphony/domain/domain.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <string_view>
#include <vector>

#include <picosha2.h>

namespace symphony::domain {
namespace {
using Sha256 = picosha2::hash256_one_by_one;

void hash_size(Sha256& hasher, const std::size_t size) {
  static_assert(sizeof(std::size_t) <= sizeof(std::uint64_t));
  auto remaining = static_cast<std::uint64_t>(size);
  std::array<unsigned char, sizeof(std::uint64_t)> encoded{};
  for (auto iterator = encoded.rbegin(); iterator != encoded.rend(); ++iterator) {
    *iterator = static_cast<unsigned char>(remaining & 0xffU);
    remaining >>= 8U;
  }
  hasher.process(encoded.begin(), encoded.end());
}

void hash_uint32(Sha256& hasher, const std::uint32_t value) {
  std::array<unsigned char, sizeof(value)> encoded{};
  auto remaining = value;
  for (auto iterator = encoded.rbegin(); iterator != encoded.rend(); ++iterator) {
    *iterator = static_cast<unsigned char>(remaining & 0xffU);
    remaining >>= 8U;
  }
  hasher.process(encoded.begin(), encoded.end());
}

void hash_bytes(Sha256& hasher, const std::string_view value) {
  hash_size(hasher, value.size());
  hasher.process(value.begin(), value.end());
}

template <typename Value> void normalize(std::vector<Value>& values) {
  std::ranges::sort(values);
  values.erase(std::ranges::unique(values).begin(), values.end());
}

void hash_repository_content(Sha256& hasher, const std::vector<RepositoryContentEvidence>& values) {
  constexpr unsigned char tag{1U};
  hasher.process(&tag, &tag + 1);
  hash_size(hasher, values.size());
  for (const auto& value : values) {
    hash_bytes(hasher, value.path);
    hash_bytes(hasher, value.content_digest);
  }
}

void hash_command_results(Sha256& hasher, const std::vector<CommandExecutionEvidence>& values) {
  constexpr unsigned char tag{2U};
  hasher.process(&tag, &tag + 1);
  hash_size(hasher, values.size());
  for (const auto& value : values) {
    hash_bytes(hasher, value.command);
    hash_bytes(hasher, value.cwd);
    hash_bytes(hasher, value.toolchain);
    hash_uint32(hasher, static_cast<std::uint32_t>(value.exit_status));
    hash_size(hasher, value.artifact_digests.size());
    for (const auto& digest : value.artifact_digests) {
      hash_bytes(hasher, digest);
    }
  }
}
} // namespace

ProgressFingerprint fingerprint(const ProgressSnapshot& snapshot) {
  auto repository_content = snapshot.repository_content;
  auto command_results = snapshot.command_results;
  for (auto& result : command_results) normalize(result.artifact_digests);
  normalize(repository_content);
  normalize(command_results);

  Sha256 hasher;
  hash_bytes(hasher, "symphony-objective-progress-v2");
  hash_repository_content(hasher, repository_content);
  hash_command_results(hasher, command_results);
  hasher.finish();
  return {picosha2::get_hash_hex_string(hasher)};
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
