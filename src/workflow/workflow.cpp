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

void validate_keys(
    const YAML::Node& node,
    const std::initializer_list<std::string_view> allowed,
    const std::string_view prefix) {
  if (!node || !node.IsMap()) throw std::runtime_error(std::string{prefix} + " must be a YAML mapping");
  for (const auto& entry : node) {
    const auto key = entry.first.as<std::string>();
    if (std::ranges::find(allowed, key) == allowed.end()) {
      throw std::runtime_error("unknown workflow key: " + std::string{prefix} + key);
    }
  }
}

std::string scalar(const YAML::Node& node, const Environment& env, const std::string_view key) {
  if (!node || !node.IsScalar()) throw std::runtime_error(std::string{key} + " must be a scalar");
  return expand(node.as<std::string>(), env);
}

std::vector<std::string> string_list(
    const YAML::Node& node,
    const Environment& env,
    const std::string_view key) {
  if (!node || !node.IsSequence()) throw std::runtime_error(std::string{key} + " must be a sequence");
  std::vector<std::string> result;
  for (const auto& item : node) result.push_back(scalar(item, env, key));
  return result;
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
  validate_keys(root, {"poll_interval_ms", "agent", "hooks", "codex", "tracker"}, "");

  if (const auto node = root["poll_interval_ms"]) {
    document.config.poll_interval = std::chrono::milliseconds{
        unsigned_value(scalar(node, env, "poll_interval_ms"), "poll_interval_ms")};
  }
  if (const auto agent = root["agent"]) {
    validate_keys(agent, {"max_concurrent", "max_retry_backoff_ms"}, "agent.");
    if (const auto node = agent["max_concurrent"]) {
      document.config.agent.max_concurrent = static_cast<std::uint32_t>(
          unsigned_value(scalar(node, env, "agent.max_concurrent"), "agent.max_concurrent"));
    }
    if (const auto node = agent["max_retry_backoff_ms"]) {
      document.config.agent.max_retry_backoff = std::chrono::milliseconds{unsigned_value(
          scalar(node, env, "agent.max_retry_backoff_ms"), "agent.max_retry_backoff_ms")};
    }
  }
  if (const auto hooks = root["hooks"]) {
    validate_keys(hooks, {"timeout_ms", "after_create", "before_run", "after_run", "before_remove"}, "hooks.");
    if (const auto node = hooks["timeout_ms"]) {
      document.config.hooks.timeout = std::chrono::milliseconds{
          unsigned_value(scalar(node, env, "hooks.timeout_ms"), "hooks.timeout_ms")};
    }
    if (const auto node = hooks["after_create"]) document.config.hooks.after_create = string_list(node, env, "hooks.after_create");
    if (const auto node = hooks["before_run"]) document.config.hooks.before_run = string_list(node, env, "hooks.before_run");
    if (const auto node = hooks["after_run"]) document.config.hooks.after_run = string_list(node, env, "hooks.after_run");
    if (const auto node = hooks["before_remove"]) document.config.hooks.before_remove = string_list(node, env, "hooks.before_remove");
  }
  if (const auto codex = root["codex"]) {
    validate_keys(codex, {"command"}, "codex.");
    if (const auto node = codex["command"]) document.config.codex.command = scalar(node, env, "codex.command");
  }
  if (const auto tracker = root["tracker"]) {
    validate_keys(tracker, {"active_states", "terminal_states"}, "tracker.");
    if (const auto node = tracker["active_states"]) document.config.active_states = string_list(node, env, "tracker.active_states");
    if (const auto node = tracker["terminal_states"]) document.config.terminal_states = string_list(node, env, "tracker.terminal_states");
  }
  document.prompt.assign(std::istreambuf_iterator<char>{input}, std::istreambuf_iterator<char>{});
  if (trim(document.prompt).empty()) throw std::runtime_error("workflow prompt must not be empty");
  if (document.config.poll_interval <= std::chrono::milliseconds::zero() ||
      document.config.agent.max_concurrent == 0 ||
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
  last_fingerprint_ = document.fingerprint;
  return document;
}

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
}  // namespace symphony::workflow
