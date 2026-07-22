#pragma once

#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include "symphony/domain/domain.hpp"

namespace symphony::tracker {

class IssueTracker {
 public:
  virtual ~IssueTracker() = default;
  [[nodiscard]] virtual std::vector<domain::Issue> list_by_states(
      const std::vector<std::string>& states) = 0;
  [[nodiscard]] virtual std::optional<domain::Issue> refresh_by_id(std::string_view id) = 0;
};

class FakeTracker final : public IssueTracker {
 public:
  void upsert(domain::Issue issue);
  [[nodiscard]] std::vector<domain::Issue> list_by_states(
      const std::vector<std::string>& states) override;
  [[nodiscard]] std::optional<domain::Issue> refresh_by_id(std::string_view id) override;

 private:
  std::unordered_map<std::string, domain::Issue> issues_;
};

class GitHubIssuesAdapter final : public IssueTracker {
 public:
  explicit GitHubIssuesAdapter(bool mutation_enabled = false);
  [[nodiscard]] std::vector<domain::Issue> list_by_states(
      const std::vector<std::string>& states) override;
  [[nodiscard]] std::optional<domain::Issue> refresh_by_id(std::string_view id) override;
  [[nodiscard]] bool mutation_enabled() const noexcept;

 private:
  bool mutation_enabled_;
};

class LinearAdapter final : public IssueTracker {
 public:
  explicit LinearAdapter(bool mutation_enabled = false);
  [[nodiscard]] std::vector<domain::Issue> list_by_states(
      const std::vector<std::string>& states) override;
  [[nodiscard]] std::optional<domain::Issue> refresh_by_id(std::string_view id) override;

 private:
  bool mutation_enabled_;
};

}  // namespace symphony::tracker

