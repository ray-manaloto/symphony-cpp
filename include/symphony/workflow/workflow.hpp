#pragma once

#include <chrono>
#include <filesystem>
#include <optional>
#include <map>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include "symphony/domain/domain.hpp"

namespace symphony::workflow {

struct HooksConfig {
  std::chrono::milliseconds timeout{60000};
  std::optional<std::string> after_create;
  std::optional<std::string> before_run;
  std::optional<std::string> after_run;
  std::optional<std::string> before_remove;
};

struct AgentConfig {
  std::uint32_t max_concurrent_agents{10};
  std::uint32_t max_turns{20};
  std::chrono::milliseconds max_retry_backoff{300000};
  std::map<std::string, std::uint32_t> max_concurrent_agents_by_state;
};

struct CodexConfig {
  std::string command{"codex app-server"};
  std::optional<std::string> approval_policy;
  std::optional<std::string> thread_sandbox;
  std::optional<std::string> turn_sandbox_policy;
  std::chrono::milliseconds turn_timeout{3600000};
  std::chrono::milliseconds read_timeout{5000};
  std::chrono::milliseconds stall_timeout{300000};
};

struct TrackerConfig {
  std::string kind;
  std::string provider_yaml{"{}"};
  std::vector<std::string> required_labels;
  std::vector<std::string> active_states;
  std::vector<std::string> terminal_states;
};

struct PollingConfig {
  std::chrono::milliseconds interval{30000};
};

struct WorkspaceConfig {
  std::filesystem::path root{std::filesystem::temp_directory_path() / "symphony_workspaces"};
};

struct WorkflowConfig {
  TrackerConfig tracker;
  PollingConfig polling;
  WorkspaceConfig workspace;
  AgentConfig agent;
  HooksConfig hooks;
  CodexConfig codex;
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
  void accept(const WorkflowDocument& document);

 private:
  WorkflowLoader loader_;
  std::string last_fingerprint_;
};

[[nodiscard]] std::string render_prompt(
    std::string_view prompt,
    const domain::Issue& issue,
    const domain::Attempt& attempt);
void validate_for_dispatch(
    const WorkflowConfig& config,
    const std::vector<std::string>& supported_tracker_kinds);

}  // namespace symphony::workflow
