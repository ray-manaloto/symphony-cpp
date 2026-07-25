#include "symphony/workflow/workflow.hpp"

#include "workflow_detail.hpp"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <limits>
#include <map>
#include <sstream>
#include <stdexcept>
#include <utility>
#include <vector>

#include <glaze/yaml.hpp>

template <> struct glz::meta<symphony::workflow::detail::RawPolling> {
  using T = symphony::workflow::detail::RawPolling;
  static constexpr auto value = object("interval_ms", &T::interval_ms);
};

template <> struct glz::meta<symphony::workflow::detail::RawWorkspace> {
  using T = symphony::workflow::detail::RawWorkspace;
  static constexpr auto value = object("root", &T::root);
};

template <> struct glz::meta<symphony::workflow::detail::RawAgent> {
  using T = symphony::workflow::detail::RawAgent;
  static constexpr auto value =
      object("max_concurrent_agents", &T::max_concurrent_agents, "max_turns", &T::max_turns,
             "max_retry_backoff_ms", &T::max_retry_backoff_ms, "max_concurrent_agents_by_state",
             &T::max_concurrent_agents_by_state);
};

template <> struct glz::meta<symphony::workflow::detail::RawHooks> {
  using T = symphony::workflow::detail::RawHooks;
  static constexpr auto value =
      object("timeout_ms", &T::timeout_ms, "after_create", &T::after_create, "before_run",
             &T::before_run, "after_run", &T::after_run, "before_remove", &T::before_remove);
};

template <> struct glz::meta<symphony::workflow::detail::RawCodex> {
  using T = symphony::workflow::detail::RawCodex;
  static constexpr auto value =
      object("command", &T::command, "model", &T::model, "reasoning_effort", &T::reasoning_effort,
             "escalation_model", &T::escalation_model, "escalation_reasoning_effort",
             &T::escalation_reasoning_effort, "repeated_failure_reasoning_effort",
             &T::repeated_failure_reasoning_effort, "context_rollover_percent",
             &T::context_rollover_percent, "approval_policy", &T::approval_policy, "thread_sandbox",
             &T::thread_sandbox, "turn_sandbox_policy", &T::turn_sandbox_policy, "turn_timeout_ms",
             &T::turn_timeout_ms, "read_timeout_ms", &T::read_timeout_ms, "stall_timeout_ms",
             &T::stall_timeout_ms);
};

template <> struct glz::meta<symphony::workflow::detail::RawTracker> {
  using T = symphony::workflow::detail::RawTracker;
  static constexpr auto value =
      object("kind", &T::kind, "provider", &T::provider, "required_labels", &T::required_labels,
             "active_states", &T::active_states, "terminal_states", &T::terminal_states);
};

template <> struct glz::meta<symphony::workflow::detail::RawWorkflow> {
  using T = symphony::workflow::detail::RawWorkflow;
  static constexpr auto value =
      object("tracker", &T::tracker, "polling", &T::polling, "workspace", &T::workspace, "agent",
             &T::agent, "hooks", &T::hooks, "codex", &T::codex);
};

namespace symphony::workflow {
namespace {
std::string trim(std::string value) {
  const auto first = std::ranges::find_if(
      value, [](const unsigned char character) { return std::isspace(character) == 0; });
  value.erase(value.begin(), first);
  while (!value.empty() && std::isspace(static_cast<unsigned char>(value.back())) != 0)
    value.pop_back();
  return value;
}

bool is_front_matter_delimiter(const std::string_view line) {
  return line == "---" || line == "---\r";
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

std::uint32_t uint32_value(const std::uint64_t value, const std::string_view key) {
  if (!std::in_range<std::uint32_t>(value)) {
    throw std::runtime_error(std::string{key} + " exceeds the supported range");
  }
  return static_cast<std::uint32_t>(value);
}

std::string normalized_state(std::string value) {
  value = trim(std::move(value));
  std::ranges::transform(value, value.begin(), [](const unsigned char character) {
    return static_cast<char>(std::tolower(character));
  });
  return value;
}

std::filesystem::path workspace_root(std::string value, const Environment& env,
                                     const std::filesystem::path& workflow_path) {
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

void replace_all(std::string& value, const std::string_view needle,
                 const std::string_view replacement) {
  for (std::size_t position = 0; (position = value.find(needle, position)) != std::string::npos;) {
    value.replace(position, needle.size(), replacement);
    position += replacement.size();
  }
}
} // namespace

std::optional<std::string> ProcessEnvironment::get(const std::string_view name) const {
  const auto* value = std::getenv(std::string{name}.c_str());
  return value == nullptr ? std::nullopt : std::optional<std::string>{value};
}

std::filesystem::path
WorkflowLoader::resolve_path(const std::optional<std::filesystem::path>& explicit_path,
                             const std::filesystem::path& cwd) {
  return explicit_path.value_or(cwd / "WORKFLOW.md");
}

WorkflowDocument WorkflowLoader::load(const std::filesystem::path& path,
                                      const Environment& env) const {
  std::ifstream stream(path);
  if (!stream) throw std::runtime_error("cannot open workflow: " + path.native());
  const std::string content{std::istreambuf_iterator<char>{stream},
                            std::istreambuf_iterator<char>{}};
  std::istringstream input(content);
  std::string line;
  WorkflowDocument document;
  document.path = path;
  document.fingerprint = content_fingerprint(content);
  const auto has_front_matter = std::getline(input, line) && is_front_matter_delimiter(line);
  detail::RawWorkflow raw;
  if (has_front_matter) {
    std::ostringstream yaml_text;
    bool closed = false;
    while (std::getline(input, line)) {
      if (is_front_matter_delimiter(line)) {
        closed = true;
        break;
      }
      yaml_text << line << '\n';
    }
    if (!closed) throw std::runtime_error("unterminated YAML front matter");
    auto yaml = yaml_text.str();
    if (trim(yaml).empty()) {
      throw std::runtime_error("workflow front matter must be a YAML mapping");
    }
    const auto yaml_error =
        glz::read_yaml<glz::yaml::yaml_opts{.error_on_unknown_keys = false}>(raw, yaml);
    if (yaml_error) {
      throw std::runtime_error("invalid workflow YAML");
    }
  } else {
    document.prompt = content;
  }

  if (raw.polling && raw.polling->interval_ms) {
    document.config.polling.interval = std::chrono::milliseconds{*raw.polling->interval_ms};
  }
  if (raw.workspace && raw.workspace->root) {
    document.config.workspace.root = workspace_root(*raw.workspace->root, env, path);
  }
  if (raw.agent) {
    if (raw.agent->max_concurrent_agents) {
      document.config.agent.max_concurrent_agents =
          uint32_value(*raw.agent->max_concurrent_agents, "agent.max_concurrent_agents");
    }
    if (raw.agent->max_turns) {
      document.config.agent.max_turns = uint32_value(*raw.agent->max_turns, "agent.max_turns");
    }
    if (raw.agent->max_retry_backoff_ms) {
      document.config.agent.max_retry_backoff =
          std::chrono::milliseconds{*raw.agent->max_retry_backoff_ms};
    }
    if (raw.agent->max_concurrent_agents_by_state &&
        raw.agent->max_concurrent_agents_by_state->is_object()) {
      for (const auto& [state, value] : raw.agent->max_concurrent_agents_by_state->get_object()) {
        std::optional<std::uint64_t> limit;
        if (const auto* number = value.get_if<std::uint64_t>()) {
          limit = *number;
        } else if (const auto* text = value.get_if<std::string>()) {
          try {
            limit = unsigned_value(*text, "state concurrency");
          } catch (const std::exception&) {
          }
        }
        if (limit && *limit > 0) {
          document.config.agent.max_concurrent_agents_by_state.emplace(
              normalized_state(state),
              uint32_value(*limit, "agent.max_concurrent_agents_by_state"));
        }
      }
    }
  }
  if (raw.hooks) {
    if (raw.hooks->timeout_ms) {
      document.config.hooks.timeout = std::chrono::milliseconds{*raw.hooks->timeout_ms};
    }
    document.config.hooks.after_create = raw.hooks->after_create;
    document.config.hooks.before_run = raw.hooks->before_run;
    document.config.hooks.after_run = raw.hooks->after_run;
    document.config.hooks.before_remove = raw.hooks->before_remove;
  }
  if (raw.codex) {
    if (raw.codex->command) document.config.codex.command = *raw.codex->command;
    document.config.codex.model = raw.codex->model;
    document.config.codex.reasoning_effort = raw.codex->reasoning_effort;
    document.config.codex.escalation_model = raw.codex->escalation_model;
    document.config.codex.escalation_reasoning_effort = raw.codex->escalation_reasoning_effort;
    document.config.codex.repeated_failure_reasoning_effort =
        raw.codex->repeated_failure_reasoning_effort;
    if (raw.codex->context_rollover_percent) {
      const auto value = *raw.codex->context_rollover_percent;
      if (value == 0 || value >= 100) {
        throw std::runtime_error("codex.context_rollover_percent must be between 1 and 99");
      }
      document.config.codex.context_rollover_percent = static_cast<std::uint32_t>(value);
    }
    document.config.codex.approval_policy = raw.codex->approval_policy;
    document.config.codex.thread_sandbox = raw.codex->thread_sandbox;
    document.config.codex.turn_sandbox_policy = raw.codex->turn_sandbox_policy;
    if (raw.codex->turn_timeout_ms) {
      document.config.codex.turn_timeout = std::chrono::milliseconds{*raw.codex->turn_timeout_ms};
    }
    if (raw.codex->read_timeout_ms) {
      document.config.codex.read_timeout = std::chrono::milliseconds{*raw.codex->read_timeout_ms};
    }
    if (raw.codex->stall_timeout_ms) {
      document.config.codex.stall_timeout = std::chrono::milliseconds{*raw.codex->stall_timeout_ms};
    }
  }
  if (raw.tracker) {
    if (raw.tracker->kind) document.config.tracker.kind = *raw.tracker->kind;
    if (raw.tracker->provider) {
      if (!raw.tracker->provider->is_object()) {
        throw std::runtime_error("tracker.provider must be a YAML mapping");
      }
      std::string provider_yaml;
      if (glz::write_yaml(*raw.tracker->provider, provider_yaml)) {
        throw std::runtime_error("cannot preserve tracker.provider YAML");
      }
      document.config.tracker.provider_yaml = std::move(provider_yaml);
    }
    if (raw.tracker->required_labels) {
      document.config.tracker.required_labels = std::move(*raw.tracker->required_labels);
    }
    if (raw.tracker->active_states) {
      document.config.tracker.active_states = std::move(*raw.tracker->active_states);
    }
    if (raw.tracker->terminal_states) {
      document.config.tracker.terminal_states = std::move(*raw.tracker->terminal_states);
    }
  }
  if (has_front_matter) {
    document.prompt.assign(std::istreambuf_iterator<char>{input}, std::istreambuf_iterator<char>{});
  }
  document.prompt = trim(std::move(document.prompt));
  if (document.prompt.empty()) throw std::runtime_error("workflow prompt must not be empty");
  if (document.config.polling.interval <= std::chrono::milliseconds::zero() ||
      document.config.agent.max_concurrent_agents == 0 || document.config.agent.max_turns == 0 ||
      document.config.hooks.timeout <= std::chrono::milliseconds::zero()) {
    throw std::runtime_error("workflow durations and concurrency must be positive");
  }
  return document;
}

WorkflowWatcher::WorkflowWatcher(WorkflowLoader loader) : loader_(std::move(loader)) {}
std::optional<WorkflowDocument>
WorkflowWatcher::reload_if_changed(const std::filesystem::path& path, const Environment& env) {
  auto document = loader_.load(path, env);
  if (document.fingerprint == last_fingerprint_) return std::nullopt;
  return document;
}

void WorkflowWatcher::accept(const WorkflowDocument& document) {
  last_fingerprint_ = document.fingerprint;
}

std::string render_prompt(const std::string_view prompt, const domain::Issue& issue,
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

void validate_for_dispatch(const WorkflowConfig& config,
                           const std::vector<std::string>& supported_tracker_kinds) {
  if (trim(config.tracker.kind).empty()) {
    throw std::runtime_error("tracker.kind is required for dispatch");
  }
  if (std::ranges::find(supported_tracker_kinds, config.tracker.kind) ==
      supported_tracker_kinds.end()) {
    throw std::runtime_error("unsupported tracker.kind: " + config.tracker.kind);
  }
  if (config.tracker.active_states.empty() || config.tracker.terminal_states.empty()) {
    throw std::runtime_error("tracker active_states and terminal_states are required");
  }
  if (trim(config.codex.command).empty()) {
    throw std::runtime_error("codex.command must not be empty");
  }
  if (config.codex.model && trim(*config.codex.model).empty()) {
    throw std::runtime_error("codex.model must not be empty");
  }
  if (config.codex.reasoning_effort && trim(*config.codex.reasoning_effort).empty()) {
    throw std::runtime_error("codex.reasoning_effort must not be empty");
  }
  if (config.codex.escalation_model && trim(*config.codex.escalation_model).empty()) {
    throw std::runtime_error("codex.escalation_model must not be empty");
  }
  if (config.codex.escalation_reasoning_effort &&
      trim(*config.codex.escalation_reasoning_effort).empty()) {
    throw std::runtime_error("codex.escalation_reasoning_effort must not be empty");
  }
  if (config.codex.repeated_failure_reasoning_effort &&
      trim(*config.codex.repeated_failure_reasoning_effort).empty()) {
    throw std::runtime_error("codex.repeated_failure_reasoning_effort must not be empty");
  }
}
} // namespace symphony::workflow
