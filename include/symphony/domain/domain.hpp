#pragma once

#include <chrono>
#include <cstdint>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace symphony::domain {

enum class ContextState {
  fresh,
  active,
  corrective_continuation,
  stalled_no_progress,
  completed,
  failed
};
enum class ProgressDecision { progressed, corrective_continuation, stalled_no_progress };
enum class IssueActivity { active, terminal, inactive };

struct Issue {
  Issue() = default;
  Issue(std::string issue_id, std::string issue_identifier, std::string issue_title,
        std::string issue_state, std::vector<std::string> issue_labels)
      : id(std::move(issue_id)), identifier(std::move(issue_identifier)),
        title(std::move(issue_title)), state(std::move(issue_state)),
        labels(std::move(issue_labels)) {}

  std::string id;
  std::string identifier;
  std::string title;
  std::optional<std::string> description;
  std::string state;
  std::vector<std::string> labels;
  std::map<std::string, std::string> native_ref;
  std::optional<std::string> branch_name;
  std::optional<std::string> url;
  std::optional<std::string> assignee_id;
  struct BlockerRef {
    std::optional<std::string> id;
    std::optional<std::string> identifier;
    std::optional<std::string> state;
  };
  std::vector<BlockerRef> blocked_by;
  std::optional<int> priority;
  std::optional<std::chrono::system_clock::time_point> created_at;
  std::optional<std::chrono::system_clock::time_point> updated_at;
  bool dispatchable{true};
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
  std::uint32_t repeated_failures{0};
  ContextState context_state{ContextState::fresh};
  std::optional<ProgressFingerprint> last_progress;
  std::optional<std::uint64_t> last_failure_signature;
};

struct RetryState {
  std::uint32_t ordinal{0};
  std::chrono::milliseconds delay{0};
};

[[nodiscard]] ProgressFingerprint fingerprint(const ProgressSnapshot& snapshot);
[[nodiscard]] ProgressDecision observe_progress(Attempt& attempt,
                                                const ProgressFingerprint& current);
[[nodiscard]] std::chrono::milliseconds
retry_delay(std::uint32_t ordinal, std::chrono::milliseconds base, std::chrono::milliseconds cap);
[[nodiscard]] std::string_view to_string(ContextState state) noexcept;

} // namespace symphony::domain
