#include <algorithm>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include <ut/ut.hpp>

#include "symphony/tracker/tracker.hpp"

namespace {
symphony::tracker::IssueRecord record(std::string id, std::string identifier, std::string title,
                                      std::string state, const bool dispatchable) {
  symphony::tracker::IssueRecord value;
  value.id = std::move(id);
  value.identifier = std::move(identifier);
  value.title = std::move(title);
  value.state = std::move(state);
  value.dispatchable = dispatchable;
  return value;
}
} // namespace

static ut::suite tracker_tests = [] {
  ut::test("tracker normalization maps complete issue fields and canonical labels") = [] {
    symphony::tracker::IssueRecord record;
    record.id = "opaque-1";
    record.identifier = "SYM-1";
    record.title = "Implement adapter";
    record.description = "Fixture only";
    record.priority = 2;
    record.state = " In Progress ";
    record.branch_name = "feature/adapter";
    record.url = "https://example.invalid/SYM-1";
    record.assignee_id = "user-1";
    record.labels = {" Backend ", "backend", "READY", "  "};
    record.native_ref = {{"project_id", "project-1"}};
    record.blocked_by = {{"blocker-1", "SYM-0", "Done"}};
    record.dispatchable = true;

    const auto normalized = symphony::tracker::normalize_issue(record);

    ut::expect(normalized.has_value());
    ut::expect(normalized->id == std::string{"opaque-1"});
    ut::expect(normalized->description == std::optional<std::string>{"Fixture only"});
    ut::expect(normalized->labels == std::vector<std::string>({"backend", "ready"}));
    ut::expect(normalized->native_ref.at("project_id") == "project-1");
    ut::expect(normalized->blocked_by.size() == std::size_t{1});
    ut::expect(normalized->dispatchable);
  };

  ut::test("paged tracker collection follows cursors once in stable page order") = [] {
    std::vector<std::optional<std::string>> cursors;
    const auto result = symphony::tracker::collect_issue_pages(
        [&](const std::optional<std::string>& cursor) -> symphony::tracker::IssuePageResult {
          cursors.push_back(cursor);
          if (!cursor) {
            return symphony::tracker::IssuePage{{record("1", "SYM-1", "First", "Todo", true)},
                                                "next"};
          }
          return symphony::tracker::IssuePage{{record("2", "SYM-2", "Second", "Todo", true)},
                                              std::nullopt};
        });

    ut::expect(result.has_value());
    ut::expect(result->size() == std::size_t{2});
    ut::expect(result->at(0).identifier == std::string{"SYM-1"});
    ut::expect(result->at(1).identifier == std::string{"SYM-2"});
    ut::expect(cursors ==
               std::vector<std::optional<std::string>>({std::nullopt, std::string{"next"}}));
  };

  ut::test("paged tracker collection fails closed on malformed records and cursor cycles") = [] {
    const auto malformed = symphony::tracker::collect_issue_pages(
        [](const std::optional<std::string>&) -> symphony::tracker::IssuePageResult {
          return symphony::tracker::IssuePage{{record("", "SYM-1", "Missing id", "Todo", true)},
                                              std::nullopt};
        });
    ut::expect(!malformed.has_value());
    ut::expect(malformed.error().code == symphony::tracker::TrackerErrorCode::malformed_response);

    const auto cycle = symphony::tracker::collect_issue_pages(
        [](const std::optional<std::string>&) -> symphony::tracker::IssuePageResult {
          return symphony::tracker::IssuePage{{}, "same"};
        });
    ut::expect(!cycle.has_value());
    ut::expect(cycle.error().code == symphony::tracker::TrackerErrorCode::malformed_response);
  };

  ut::test("adapter profiles and HTTP failures map to portable contracts") = [] {
    const auto linear = symphony::tracker::adapter_profile("linear");
    const auto github = symphony::tracker::adapter_profile(" GITHUB ");
    ut::expect(linear.has_value());
    ut::expect(linear->active_states == std::vector<std::string>({"Todo", "In Progress"}));
    ut::expect(linear->terminal_states == std::vector<std::string>({"Done", "Cancelled"}));
    ut::expect(github.has_value());
    ut::expect(github->active_states == std::vector<std::string>({"open"}));
    ut::expect(github->terminal_states == std::vector<std::string>({"closed"}));
    const auto secret_names = symphony::tracker::all_tracker_secret_environment_names();
    ut::expect(std::ranges::find(secret_names, std::string{"LINEAR_API_KEY"}) !=
               secret_names.end());
    ut::expect(std::ranges::find(secret_names, std::string{"GITHUB_TOKEN"}) != secret_names.end());

    const auto authentication = symphony::tracker::map_http_error(401);
    const auto forbidden = symphony::tracker::map_http_error(403);
    const auto missing = symphony::tracker::map_http_error(404);
    const auto unexpected = symphony::tracker::map_http_error(418);
    const auto throttled = symphony::tracker::map_http_error(429);
    const auto unavailable = symphony::tracker::map_http_error(503);
    ut::expect(authentication.code == symphony::tracker::TrackerErrorCode::authentication);
    ut::expect(!authentication.retryable);
    ut::expect(forbidden.code == symphony::tracker::TrackerErrorCode::permission);
    ut::expect(!forbidden.retryable);
    ut::expect(missing.code == symphony::tracker::TrackerErrorCode::not_found);
    ut::expect(!missing.retryable);
    ut::expect(unexpected.code == symphony::tracker::TrackerErrorCode::malformed_response);
    ut::expect(!unexpected.retryable);
    ut::expect(throttled.code == symphony::tracker::TrackerErrorCode::rate_limited);
    ut::expect(throttled.retryable);
    ut::expect(unavailable.code == symphony::tracker::TrackerErrorCode::unavailable);
    ut::expect(unavailable.retryable);
  };
};
