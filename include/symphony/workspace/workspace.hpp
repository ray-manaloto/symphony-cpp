#pragma once

#include <chrono>
#include <filesystem>
#include <string>
#include <string_view>
#include <vector>

#include "symphony/domain/domain.hpp"

namespace symphony::workspace {

struct Workspace {
  std::filesystem::path path;
  std::string issue_id;
};

class WorkspaceExecutor {
 public:
  virtual ~WorkspaceExecutor() = default;
  [[nodiscard]] virtual Workspace create(const domain::Issue& issue) = 0;
  virtual void run_hook(
      const Workspace& workspace,
      std::string_view hook_name,
      const std::vector<std::string>& command,
      std::chrono::milliseconds timeout) = 0;
  virtual void remove(const Workspace& workspace) = 0;
};

class FixtureWorkspaceExecutor final : public WorkspaceExecutor {
 public:
  explicit FixtureWorkspaceExecutor(std::filesystem::path root);
  [[nodiscard]] Workspace create(const domain::Issue& issue) override;
  void run_hook(
      const Workspace& workspace,
      std::string_view hook_name,
      const std::vector<std::string>& command,
      std::chrono::milliseconds timeout) override;
  void remove(const Workspace& workspace) override;
  [[nodiscard]] const std::vector<std::string>& hook_history() const noexcept;

 private:
  [[nodiscard]] std::filesystem::path contained(std::string_view leaf) const;
  std::filesystem::path root_;
  std::vector<std::string> hook_history_;
};

[[nodiscard]] std::string workspace_leaf(const domain::Issue& issue);

}  // namespace symphony::workspace

