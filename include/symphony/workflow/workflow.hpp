#pragma once

#include <chrono>
#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include "symphony/domain/domain.hpp"

namespace symphony::workflow {

struct HooksConfig {
  std::chrono::milliseconds timeout{60000};
  std::vector<std::string> after_create;
  std::vector<std::string> before_run;
  std::vector<std::string> after_run;
  std::vector<std::string> before_remove;
};

struct AgentConfig {
  std::uint32_t max_concurrent{1};
  std::chrono::milliseconds max_retry_backoff{300000};
};

struct CodexConfig {
  std::string command{"codex app-server"};
};

struct WorkflowConfig {
  std::chrono::milliseconds poll_interval{5000};
  AgentConfig agent;
  HooksConfig hooks;
  CodexConfig codex;
  std::vector<std::string> active_states{"Todo", "In Progress"};
  std::vector<std::string> terminal_states{"Done", "Cancelled"};
};

struct WorkflowDocument {
  WorkflowConfig config;
  std::string prompt;
  std::filesystem::path path;
  std::string fingerprint;
};

class Environment {
 public:
  virtual ~Environment() = default;
  [[nodiscard]] virtual std::optional<std::string> get(std::string_view name) const = 0;
};

class ProcessEnvironment final : public Environment {
 public:
  [[nodiscard]] std::optional<std::string> get(std::string_view name) const override;
};

class WorkflowLoader {
 public:
  [[nodiscard]] static std::filesystem::path resolve_path(
      const std::optional<std::filesystem::path>& explicit_path,
      const std::filesystem::path& cwd);
  [[nodiscard]] WorkflowDocument load(const std::filesystem::path& path, const Environment& env) const;
};

class WorkflowWatcher {
 public:
  explicit WorkflowWatcher(WorkflowLoader loader = {});
  [[nodiscard]] std::optional<WorkflowDocument> reload_if_changed(
      const std::filesystem::path& path,
      const Environment& env);

 private:
  WorkflowLoader loader_;
  std::string last_fingerprint_;
};

[[nodiscard]] std::string render_prompt(
    std::string_view prompt,
    const domain::Issue& issue,
    const domain::Attempt& attempt);

}  // namespace symphony::workflow

