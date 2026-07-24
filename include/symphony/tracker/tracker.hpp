#pragma once

#include <chrono>
#include <cstddef>
#include <expected>
#include <functional>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include "symphony/domain/domain.hpp"

namespace symphony::tracker {

enum class TrackerErrorCode {
  configuration,
  authentication,
  permission,
  not_found,
  rate_limited,
  unavailable,
  malformed_response
};

struct TrackerError {
  TrackerErrorCode code{TrackerErrorCode::unavailable};
  bool retryable{false};
  std::string message;
};

struct IssueRecord {
  std::string id;
  std::string identifier;
  std::string title;
  std::string state;
  std::optional<bool> dispatchable;
  std::optional<std::string> description;
  std::vector<std::string> labels;
  std::map<std::string, std::string> native_ref;
  std::optional<std::string> branch_name;
  std::optional<std::string> url;
  std::optional<std::string> assignee_id;
  std::vector<domain::Issue::BlockerRef> blocked_by;
  std::optional<int> priority;
  std::optional<std::chrono::system_clock::time_point> created_at;
  std::optional<std::chrono::system_clock::time_point> updated_at;
};

struct IssuePage {
  std::vector<IssueRecord> records;
  std::optional<std::string> next_cursor;
};

using IssueResult = std::expected<domain::Issue, TrackerError>;
using IssuePageResult = std::expected<IssuePage, TrackerError>;
using IssueListResult = std::expected<std::vector<domain::Issue>, TrackerError>;
using PageFetcher = std::function<IssuePageResult(const std::optional<std::string>& cursor)>;

struct AdapterProfile {
  std::string kind;
  std::vector<std::string> active_states;
  std::vector<std::string> terminal_states;
  std::vector<std::string> required_provider_keys;
  std::vector<std::string> secret_environment_names;
};

[[nodiscard]] IssueResult normalize_issue(const IssueRecord& record);
[[nodiscard]] IssueListResult collect_issue_pages(const PageFetcher& fetch_page,
                                                  std::size_t max_pages = 1000);
[[nodiscard]] std::optional<AdapterProfile> adapter_profile(std::string_view kind);
[[nodiscard]] std::vector<std::string> all_tracker_secret_environment_names();
[[nodiscard]] TrackerError map_http_error(int status_code);

class IssueTracker {
public:
  virtual ~IssueTracker() = default;
  [[nodiscard]] virtual std::vector<domain::Issue>
  list_by_states(const std::vector<std::string>& states) = 0;
  [[nodiscard]] virtual std::optional<domain::Issue> refresh_by_id(std::string_view id) = 0;
};

class FakeTracker final : public IssueTracker {
public:
  void upsert(domain::Issue issue);
  [[nodiscard]] std::vector<domain::Issue>
  list_by_states(const std::vector<std::string>& states) override;
  [[nodiscard]] std::optional<domain::Issue> refresh_by_id(std::string_view id) override;

private:
  std::unordered_map<std::string, domain::Issue> issues_;
};

class GitHubIssuesAdapter final : public IssueTracker {
public:
  explicit GitHubIssuesAdapter(bool mutation_enabled = false);
  [[nodiscard]] std::vector<domain::Issue>
  list_by_states(const std::vector<std::string>& states) override;
  [[nodiscard]] std::optional<domain::Issue> refresh_by_id(std::string_view id) override;
  [[nodiscard]] bool mutation_enabled() const noexcept;

private:
  bool mutation_enabled_;
};

class LinearAdapter final : public IssueTracker {
public:
  explicit LinearAdapter(bool mutation_enabled = false);
  [[nodiscard]] std::vector<domain::Issue>
  list_by_states(const std::vector<std::string>& states) override;
  [[nodiscard]] std::optional<domain::Issue> refresh_by_id(std::string_view id) override;

private:
  bool mutation_enabled_;
};

} // namespace symphony::tracker
