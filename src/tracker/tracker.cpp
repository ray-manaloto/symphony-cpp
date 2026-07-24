#include "symphony/tracker/tracker.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <set>

#include <lookup/entry.hpp>
#include <lookup/input.hpp>
#include <lookup/lookup.hpp>
#include <stdx/utility.hpp>

namespace symphony::tracker {
namespace {
struct HttpErrorProfile {
  TrackerErrorCode code;
  bool retryable;
  std::string_view message;
};

constexpr auto http_error_profiles = lookup::make(CX_VALUE(lookup::input<int, HttpErrorProfile, 4>{
    {TrackerErrorCode::malformed_response, false, "unexpected tracker response"},
    std::array{lookup::entry{401, HttpErrorProfile{TrackerErrorCode::authentication, false,
                                                   "tracker authentication failed"}},
               lookup::entry{403, HttpErrorProfile{TrackerErrorCode::permission, false,
                                                   "tracker permission denied"}},
               lookup::entry{404, HttpErrorProfile{TrackerErrorCode::not_found, false,
                                                   "tracker resource was not found"}},
               lookup::entry{429, HttpErrorProfile{TrackerErrorCode::rate_limited, true,
                                                   "tracker rate limit exceeded"}}}}));

static_assert(http_error_profiles[401].code == TrackerErrorCode::authentication);
static_assert(http_error_profiles[429].retryable);
static_assert(http_error_profiles[418].code == TrackerErrorCode::malformed_response);

std::string normalized(const std::string_view value) {
  const auto first = value.find_first_not_of(" \t\r\n");
  const auto last = value.find_last_not_of(" \t\r\n");
  if (first == std::string_view::npos) return {};
  std::string result{value.substr(first, last - first + 1)};
  std::ranges::transform(result, result.begin(), [](const unsigned char character) {
    return static_cast<char>(std::tolower(character));
  });
  return result;
}

std::string trimmed(const std::string_view value) {
  const auto first = value.find_first_not_of(" \t\r\n");
  const auto last = value.find_last_not_of(" \t\r\n");
  if (first == std::string_view::npos) return {};
  return std::string{value.substr(first, last - first + 1)};
}

const std::array<AdapterProfile, 2>& adapter_profiles() {
  static const std::array profiles{
      AdapterProfile{"linear",
                     {"Todo", "In Progress"},
                     {"Done", "Cancelled"},
                     {"project_slug"},
                     {"LINEAR_API_KEY"}},
      AdapterProfile{"github", {"open"}, {"closed"}, {"owner", "repository"}, {"GITHUB_TOKEN"}}};
  return profiles;
}
} // namespace

IssueResult normalize_issue(const IssueRecord& record) {
  if (trimmed(record.id).empty() || trimmed(record.identifier).empty() ||
      trimmed(record.title).empty() || trimmed(record.state).empty() ||
      !record.dispatchable.has_value()) {
    return std::unexpected(TrackerError{TrackerErrorCode::malformed_response, false,
                                        "tracker record is missing a required scheduling field"});
  }

  domain::Issue issue{record.id, record.identifier, record.title, record.state, {}};
  issue.description = record.description;
  issue.native_ref = record.native_ref;
  issue.branch_name = record.branch_name;
  issue.url = record.url;
  issue.assignee_id = record.assignee_id;
  issue.blocked_by = record.blocked_by;
  issue.priority = record.priority;
  issue.created_at = record.created_at;
  issue.updated_at = record.updated_at;
  issue.dispatchable = *record.dispatchable;

  for (const auto& label : record.labels) {
    auto canonical = normalized(label);
    if (canonical.empty() || std::ranges::find(issue.labels, canonical) != issue.labels.end()) {
      continue;
    }
    issue.labels.push_back(std::move(canonical));
  }
  return issue;
}

IssueListResult collect_issue_pages(const PageFetcher& fetch_page, const std::size_t max_pages) {
  if (!fetch_page || max_pages == 0) {
    return std::unexpected(
        TrackerError{TrackerErrorCode::configuration, false, "invalid tracker page source"});
  }
  std::vector<domain::Issue> issues;
  std::optional<std::string> cursor;
  std::set<std::string> visited_cursors;
  for (std::size_t page_number = 0; page_number < max_pages; ++page_number) {
    if (cursor && !visited_cursors.insert(*cursor).second) {
      return std::unexpected(TrackerError{TrackerErrorCode::malformed_response, false,
                                          "tracker pagination cursor repeated"});
    }
    auto page = fetch_page(cursor);
    if (!page) return std::unexpected(std::move(page.error()));
    for (const auto& record : page->records) {
      auto issue = normalize_issue(record);
      if (!issue) return std::unexpected(std::move(issue.error()));
      issues.push_back(std::move(*issue));
    }
    if (!page->next_cursor) return issues;
    if (page->next_cursor->empty()) {
      return std::unexpected(TrackerError{TrackerErrorCode::malformed_response, false,
                                          "tracker pagination cursor is blank"});
    }
    cursor = std::move(page->next_cursor);
  }
  return std::unexpected(TrackerError{TrackerErrorCode::malformed_response, false,
                                      "tracker pagination exceeded the page limit"});
}

std::optional<AdapterProfile> adapter_profile(const std::string_view kind) {
  const auto canonical = normalized(kind);
  const auto found = std::ranges::find(adapter_profiles(), canonical, &AdapterProfile::kind);
  if (found == adapter_profiles().end()) {
    return std::nullopt;
  }
  return *found;
}

std::vector<std::string> all_tracker_secret_environment_names() {
  std::vector<std::string> names;
  for (const auto& profile : adapter_profiles()) {
    for (const auto& name : profile.secret_environment_names) {
      if (std::ranges::find(names, name) == names.end()) {
        names.push_back(name);
      }
    }
  }
  return names;
}

TrackerError map_http_error(const int status_code) {
  if (status_code >= 500 && status_code <= 599) {
    return {TrackerErrorCode::unavailable, true, "tracker service is unavailable"};
  }
  const auto profile = http_error_profiles[status_code];
  return {profile.code, profile.retryable, std::string{profile.message}};
}

void FakeTracker::upsert(domain::Issue issue) {
  issues_.insert_or_assign(issue.id, std::move(issue));
}

std::vector<domain::Issue> FakeTracker::list_by_states(const std::vector<std::string>& states) {
  std::vector<domain::Issue> result;
  for (const auto& [id, issue] : issues_) {
    static_cast<void>(id);
    if (std::ranges::any_of(states, [&](const auto& state) {
          return normalized(state) == normalized(issue.state);
        })) {
      result.push_back(issue);
    }
  }
  std::ranges::sort(result, {}, &domain::Issue::identifier);
  return result;
}

std::optional<domain::Issue> FakeTracker::refresh_by_id(const std::string_view id) {
  const auto found = issues_.find(std::string{id});
  return found == issues_.end() ? std::nullopt : std::optional{found->second};
}

GitHubIssuesAdapter::GitHubIssuesAdapter(const bool mutation_enabled)
    : mutation_enabled_(mutation_enabled) {}
std::vector<domain::Issue> GitHubIssuesAdapter::list_by_states(const std::vector<std::string>&) {
  return {};
}
std::optional<domain::Issue> GitHubIssuesAdapter::refresh_by_id(std::string_view) {
  return std::nullopt;
}
bool GitHubIssuesAdapter::mutation_enabled() const noexcept {
  return mutation_enabled_;
}

LinearAdapter::LinearAdapter(const bool mutation_enabled) : mutation_enabled_(mutation_enabled) {}
std::vector<domain::Issue> LinearAdapter::list_by_states(const std::vector<std::string>&) {
  return {};
}
std::optional<domain::Issue> LinearAdapter::refresh_by_id(std::string_view) {
  return std::nullopt;
}
} // namespace symphony::tracker
