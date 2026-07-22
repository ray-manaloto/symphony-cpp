#include "symphony/workflow/workflow.hpp"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <limits>
#include <sstream>
#include <stdexcept>

#include <yaml-cpp/yaml.h>

namespace symphony::workflow {
namespace {
std::string trim(std::string value) {
  const auto first = std::ranges::find_if(value, [](const unsigned char character) {
    return std::isspace(character) == 0;
  });
  value.erase(value.begin(), first);
  while (!value.empty() && std::isspace(static_cast<unsigned char>(value.back())) != 0) value.pop_back();
  return value;
}

std::string expand(std::string value, const Environment& env) {
  if (value.empty() || value.front() != '$') return value;
  std::string name;
  if (value.size() > 3 && value[1] == '{' && value.back() == '}') {
    name = value.substr(2, value.size() - 3);
  } else {
    name = value.substr(1);
  }
  if (name.empty() || !std::ranges::all_of(name, [](const unsigned char character) {
        return std::isalnum(character) != 0 || character == '_';
      })) {
    throw std::runtime_error("invalid environment reference");
  }
  const auto result = env.get(name);
  if (!result) throw std::runtime_error("missing environment variable: " + name);
  return *result;
}

std::uint64_t unsigned_value(const std::string& text, const std::string_view key) {
  std::size_t consumed = 0;
  const auto result = std::stoull(text, &consumed);
  if (consumed != text.size()) throw std::runtime_error("invalid integer for " + std::string{key});
  return result;
}

void require_map(const YAML::Node& node, const std::string_view key) {
  if (!node || !node.IsMap()) throw std::runtime_error(std::string{key} + " must be a YAML mapping");
}

std::string scalar(const YAML::Node& node, const std::string_view key) {
  if (!node || !node.IsScalar()) throw std::runtime_error(std::string{key} + " must be a scalar");
  return node.as<std::string>();
}

std::vector<std::string> string_list(
    const YAML::Node& node,
    const std::string_view key) {
  if (!node || !node.IsSequence()) throw std::runtime_error(std::string{key} + " must be a sequence");
  std::vector<std::string> result;
  for (const auto& item : node) result.push_back(scalar(item, key));
  return result;
}

std::string normalized_state(std::string value) {
  value = trim(std::move(value));
  std::ranges::transform(value, value.begin(), [](const unsigned char character) {
    return static_cast<char>(std::tolower(character));
  });
  return value;
}

std::filesystem::path workspace_root(
    const YAML::Node& node,
    const Environment& env,
    const std::filesystem::path& workflow_path) {
  auto value = scalar(node, "workspace.root");
  if (value.starts_with('$')) value = expand(std::move(value), env);
  if (value == "~" || value.starts_with("~/")) {
    const auto home = env.get("HOME");
    if (!home || home->empty()) throw std::runtime_error("HOME is required for workspace.root '~'");
    value = *home + value.substr(1);
  }
  std::filesystem::path root{value};
  if (root.is_relative()) root = workflow_path.parent_path() / root;
  return std::filesystem::absolute(root).lexically_normal();
}

std::string content_fingerprint(const std::string_view content) {
  std::uint64_t hash = 14695981039346656037ULL;
  for (const unsigned char byte : content) {
    hash ^= byte;
    hash *= 1099511628211ULL;
  }
  std::ostringstream encoded;
  encoded << std::hex << std::setfill('0') << std::setw(16) << hash;
  return encoded.str();
}

void replace_all(std::string& value, const std::string_view needle, const std::string_view replacement) {
  for (std::size_t position = 0; (position = value.find(needle, position)) != std::string::npos;) {
    value.replace(position, needle.size(), replacement);
    position += replacement.size();
  }
}
}  // namespace

std::optional<std::string> ProcessEnvironment::get(const std::string_view name) const {
  const auto* value = std::getenv(std::string{name}.c_str());
  return value == nullptr ? std::nullopt : std::optional<std::string>{value};
}

std::filesystem::path WorkflowLoader::resolve_path(
    const std::optional<std::filesystem::path>& explicit_path,
    const std::filesystem::path& cwd) {
  return explicit_path.value_or(cwd / "WORKFLOW.md");
}

WorkflowDocument WorkflowLoader::load(const std::filesystem::path& path, const Environment& env) const {
  std::ifstream stream(path);
  if (!stream) throw std::runtime_error("cannot open workflow: " + path.native());
  const std::string content{std::istreambuf_iterator<char>{stream}, std::istreambuf_iterator<char>{}};
  std::istringstream input(content);
  std::string line;
  if (!std::getline(input, line) || trim(line) != "---") {
    throw std::runtime_error("WORKFLOW.md must begin with YAML front matter");
  }

  WorkflowDocument document;
  document.path = path;
  document.fingerprint = content_fingerprint(content);
  std::ostringstream yaml_text;
  bool closed = false;
  while (std::getline(input, line)) {
    if (trim(line) == "---") { closed = true; break; }
    yaml_text << line << '\n';
  }
  if (!closed) throw std::runtime_error("unterminated YAML front matter");
  const auto root = YAML::Load(yaml_text.str());
  require_map(root, "workflow front matter");
  if (const auto polling = root["polling"]) {
    require_map(polling, "polling");
    if (const auto node = polling["interval_ms"]) {
      document.config.polling.interval = std::chrono::milliseconds{
          unsigned_value(scalar(node, "polling.interval_ms"), "polling.interval_ms")};
    }
  }
  if (const auto workspace = root["workspace"]) {
    require_map(workspace, "workspace");
    if (const auto node = workspace["root"]) {
      document.config.workspace.root = workspace_root(node, env, path);
    }
  }
  if (const auto agent = root["agent"]) {
    require_map(agent, "agent");
    if (const auto node = agent["max_concurrent_agents"]) {
      document.config.agent.max_concurrent_agents = static_cast<std::uint32_t>(unsigned_value(
          scalar(node, "agent.max_concurrent_agents"), "agent.max_concurrent_agents"));
    }
    if (const auto node = agent["max_turns"]) {
      document.config.agent.max_turns = static_cast<std::uint32_t>(
          unsigned_value(scalar(node, "agent.max_turns"), "agent.max_turns"));
    }
    if (const auto node = agent["max_retry_backoff_ms"]) {
      document.config.agent.max_retry_backoff = std::chrono::milliseconds{unsigned_value(
          scalar(node, "agent.max_retry_backoff_ms"), "agent.max_retry_backoff_ms")};
    }
    if (const auto limits = agent["max_concurrent_agents_by_state"]) {
      require_map(limits, "agent.max_concurrent_agents_by_state");
      for (const auto& entry : limits) {
        try {
          const auto limit = unsigned_value(entry.second.as<std::string>(), "state concurrency");
          if (limit > 0) {
            document.config.agent.max_concurrent_agents_by_state.emplace(
                normalized_state(entry.first.as<std::string>()),
                static_cast<std::uint32_t>(limit));
          }
        } catch (const std::exception&) {
          // The specification requires invalid per-state entries to be ignored.
        }
      }
    }
  }
  if (const auto hooks = root["hooks"]) {
    require_map(hooks, "hooks");
    if (const auto node = hooks["timeout_ms"]) {
      document.config.hooks.timeout = std::chrono::milliseconds{
          unsigned_value(scalar(node, "hooks.timeout_ms"), "hooks.timeout_ms")};
    }
    if (const auto node = hooks["after_create"]; node && !node.IsNull()) document.config.hooks.after_create = scalar(node, "hooks.after_create");
    if (const auto node = hooks["before_run"]; node && !node.IsNull()) document.config.hooks.before_run = scalar(node, "hooks.before_run");
    if (const auto node = hooks["after_run"]; node && !node.IsNull()) document.config.hooks.after_run = scalar(node, "hooks.after_run");
    if (const auto node = hooks["before_remove"]; node && !node.IsNull()) document.config.hooks.before_remove = scalar(node, "hooks.before_remove");
  }
  if (const auto codex = root["codex"]) {
    require_map(codex, "codex");
    if (const auto node = codex["command"]) document.config.codex.command = scalar(node, "codex.command");
    if (const auto node = codex["approval_policy"]) document.config.codex.approval_policy = scalar(node, "codex.approval_policy");
    if (const auto node = codex["thread_sandbox"]) document.config.codex.thread_sandbox = scalar(node, "codex.thread_sandbox");
    if (const auto node = codex["turn_sandbox_policy"]) document.config.codex.turn_sandbox_policy = scalar(node, "codex.turn_sandbox_policy");
    if (const auto node = codex["turn_timeout_ms"]) document.config.codex.turn_timeout = std::chrono::milliseconds{unsigned_value(scalar(node, "codex.turn_timeout_ms"), "codex.turn_timeout_ms")};
    if (const auto node = codex["read_timeout_ms"]) document.config.codex.read_timeout = std::chrono::milliseconds{unsigned_value(scalar(node, "codex.read_timeout_ms"), "codex.read_timeout_ms")};
    if (const auto node = codex["stall_timeout_ms"]) document.config.codex.stall_timeout = std::chrono::milliseconds{std::stoll(scalar(node, "codex.stall_timeout_ms"))};
  }
  if (const auto tracker = root["tracker"]) {
    require_map(tracker, "tracker");
    if (const auto node = tracker["kind"]) document.config.tracker.kind = scalar(node, "tracker.kind");
    if (const auto node = tracker["provider"]) {
      if (!node.IsMap()) throw std::runtime_error("tracker.provider must be a YAML mapping");
      document.config.tracker.provider_yaml = YAML::Dump(node);
    }
    if (const auto node = tracker["required_labels"]) document.config.tracker.required_labels = string_list(node, "tracker.required_labels");
    if (const auto node = tracker["active_states"]) document.config.tracker.active_states = string_list(node, "tracker.active_states");
    if (const auto node = tracker["terminal_states"]) document.config.tracker.terminal_states = string_list(node, "tracker.terminal_states");
  }
  document.prompt.assign(std::istreambuf_iterator<char>{input}, std::istreambuf_iterator<char>{});
  if (trim(document.prompt).empty()) throw std::runtime_error("workflow prompt must not be empty");
  if (document.config.polling.interval <= std::chrono::milliseconds::zero() ||
      document.config.agent.max_concurrent_agents == 0 ||
      document.config.agent.max_turns == 0 ||
      document.config.hooks.timeout <= std::chrono::milliseconds::zero()) {
    throw std::runtime_error("workflow durations and concurrency must be positive");
  }
  return document;
}

WorkflowWatcher::WorkflowWatcher(WorkflowLoader loader) : loader_(std::move(loader)) {}
std::optional<WorkflowDocument> WorkflowWatcher::reload_if_changed(
    const std::filesystem::path& path,
    const Environment& env) {
  auto document = loader_.load(path, env);
  if (document.fingerprint == last_fingerprint_) return std::nullopt;
  return document;
}

void WorkflowWatcher::accept(const WorkflowDocument& document) { last_fingerprint_ = document.fingerprint; }

std::string render_prompt(
    const std::string_view prompt,
    const domain::Issue& issue,
    const domain::Attempt& attempt) {
  std::string rendered{prompt};
  replace_all(rendered, "{{ issue.id }}", issue.id);
  replace_all(rendered, "{{ issue.identifier }}", issue.identifier);
  replace_all(rendered, "{{ issue.title }}", issue.title);
  replace_all(rendered, "{{ issue.state }}", issue.state);
  replace_all(rendered, "{{ attempt }}", std::to_string(attempt.number));
  if (rendered.find("{{") != std::string::npos || rendered.find("}}") != std::string::npos) {
    throw std::runtime_error("unknown or malformed prompt variable");
  }
  return rendered;
}

void validate_for_dispatch(
    const WorkflowConfig& config,
    const std::vector<std::string>& supported_tracker_kinds) {
  if (trim(config.tracker.kind).empty()) throw std::runtime_error("tracker.kind is required for dispatch");
  if (std::ranges::find(supported_tracker_kinds, config.tracker.kind) == supported_tracker_kinds.end()) {
    throw std::runtime_error("unsupported tracker.kind: " + config.tracker.kind);
  }
  if (config.tracker.active_states.empty() || config.tracker.terminal_states.empty()) {
    throw std::runtime_error("tracker active_states and terminal_states are required");
  }
  if (trim(config.codex.command).empty()) throw std::runtime_error("codex.command must not be empty");
}
}  // namespace symphony::workflow
