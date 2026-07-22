#include "symphony/tracker/tracker.hpp"

#include <algorithm>
#include <cctype>

namespace symphony::tracker {
namespace {
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
}  // namespace
void FakeTracker::upsert(domain::Issue issue) { issues_.insert_or_assign(issue.id, std::move(issue)); }

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

GitHubIssuesAdapter::GitHubIssuesAdapter(const bool mutation_enabled) : mutation_enabled_(mutation_enabled) {}
std::vector<domain::Issue> GitHubIssuesAdapter::list_by_states(const std::vector<std::string>&) { return {}; }
std::optional<domain::Issue> GitHubIssuesAdapter::refresh_by_id(std::string_view) { return std::nullopt; }
bool GitHubIssuesAdapter::mutation_enabled() const noexcept { return mutation_enabled_; }

LinearAdapter::LinearAdapter(const bool mutation_enabled) : mutation_enabled_(mutation_enabled) {}
std::vector<domain::Issue> LinearAdapter::list_by_states(const std::vector<std::string>&) { return {}; }
std::optional<domain::Issue> LinearAdapter::refresh_by_id(std::string_view) { return std::nullopt; }
}  // namespace symphony::tracker
