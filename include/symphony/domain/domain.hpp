#pragma once

#include <chrono>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace symphony::domain {

enum class ContextState { fresh, active, corrective_continuation, stalled_no_progress, completed, failed };
enum class ProgressDecision { progressed, corrective_continuation, stalled_no_progress };
enum class IssueActivity { active, terminal, inactive };

struct Issue {
  std::string id;
  std::string identifier;
  std::string title;
  std::string state;
  std::vector<std::string> labels;
};

struct ProgressSnapshot {
  std::string summary;
  std::string current_step;
  std::vector<std::string> changed_paths;
  std::vector<std::string> completed_checks;
};

struct ProgressFingerprint {
  std::string value;
  friend bool operator==(const ProgressFingerprint&, const ProgressFingerprint&) = default;
};

struct Attempt {
  std::uint32_t number{1};
  std::uint32_t corrective_continuations{0};
  std::uint32_t unchanged_results{0};
  std::uint32_t failure_retries{0};
  ContextState context_state{ContextState::fresh};
  std::optional<ProgressFingerprint> last_progress;
};

struct RetryState {
  std::uint32_t ordinal{0};
  std::chrono::milliseconds delay{0};
};

[[nodiscard]] ProgressFingerprint fingerprint(const ProgressSnapshot& snapshot);
[[nodiscard]] ProgressDecision observe_progress(Attempt& attempt, const ProgressFingerprint& current);
[[nodiscard]] std::chrono::milliseconds retry_delay(
    std::uint32_t ordinal,
    std::chrono::milliseconds base,
    std::chrono::milliseconds cap);
[[nodiscard]] std::string_view to_string(ContextState state) noexcept;

}  // namespace symphony::domain
