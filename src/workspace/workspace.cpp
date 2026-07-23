#include "symphony/workspace/workspace.hpp"

#include <algorithm>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <thread>

#include <csignal>
#include <sys/wait.h>
#include <unistd.h>

namespace symphony::workspace {
namespace {
bool is_ascii_alphanumeric(const unsigned char value) {
  return (value >= 'A' && value <= 'Z') ||
         (value >= 'a' && value <= 'z') ||
         (value >= '0' && value <= '9');
}

std::uint64_t fnv1a(const std::string_view value) {
  std::uint64_t hash = 14695981039346656037ULL;
  for (const unsigned char byte : value) {
    hash ^= byte;
    hash *= 1099511628211ULL;
  }
  return hash;
}
}  // namespace

std::string workspace_leaf(const domain::Issue& issue) {
  if (issue.identifier.empty()) {
    throw std::invalid_argument("workspace issue identifier is required");
  }
  std::string safe;
  bool changed = false;
  for (const unsigned char character : issue.identifier) {
    if (is_ascii_alphanumeric(character) || character == '.' ||
        character == '-' || character == '_') {
      safe += static_cast<char>(character);
    } else {
      safe += '_';
      changed = true;
    }
  }
  if (safe == "." || safe == "..") {
    std::ranges::fill(safe, '_');
    changed = true;
  }
  if (!changed) return safe;
  std::ostringstream suffix;
  suffix << std::hex << std::setfill('0') << std::setw(16)
         << fnv1a(issue.identifier);
  return safe + '-' + suffix.str();
}

FixtureWorkspaceExecutor::FixtureWorkspaceExecutor(std::filesystem::path root)
    : root_(std::filesystem::absolute(std::move(root)).lexically_normal()) {
  std::filesystem::create_directories(root_);
  root_ = std::filesystem::canonical(root_);
}

std::filesystem::path FixtureWorkspaceExecutor::contained(const std::string_view leaf) const {
  const auto candidate = (root_ / std::string{leaf}).lexically_normal();
  const auto relative = candidate.lexically_relative(root_);
  if (relative.empty() || relative.is_absolute() || *relative.begin() == "..") {
    throw std::runtime_error("workspace path escapes configured root");
  }
  return candidate;
}

std::optional<Workspace> FixtureWorkspaceExecutor::find(const domain::Issue& issue) const {
  const auto path = contained(workspace_leaf(issue));
  if (!std::filesystem::is_directory(path) || std::filesystem::is_symlink(path)) return std::nullopt;
  return Workspace{path, issue.id, false};
}

Workspace FixtureWorkspaceExecutor::create(const domain::Issue& issue) {
  const auto path = contained(workspace_leaf(issue));
  if (std::filesystem::is_symlink(path)) throw std::runtime_error("workspace path is a symlink");
  const auto newly_created = !std::filesystem::exists(path);
  std::filesystem::create_directories(path);
  return {path, issue.id, newly_created};
}

void FixtureWorkspaceExecutor::run_hook(
    const Workspace& workspace,
    const std::string_view hook_name,
    const std::vector<std::string>& command,
    const std::chrono::milliseconds timeout) {
  const auto verified = contained(workspace.path.filename().native());
  if (verified != workspace.path.lexically_normal()) throw std::runtime_error("uncontained hook workspace");
  if (std::filesystem::is_symlink(verified) ||
      std::filesystem::canonical(verified) != verified) {
    throw std::runtime_error("hook workspace is not canonical and contained");
  }
  if (timeout <= std::chrono::milliseconds::zero()) throw std::runtime_error("hook timeout must be positive");
  if (command.empty()) return;
  hook_history_.push_back(std::string{hook_name});
}

void FixtureWorkspaceExecutor::remove(const Workspace& workspace) {
  const auto verified = contained(workspace.path.filename().native());
  if (verified != workspace.path.lexically_normal()) throw std::runtime_error("uncontained workspace removal");
  if (std::filesystem::is_symlink(verified)) throw std::runtime_error("refusing symlink workspace removal");
  std::filesystem::remove_all(verified);
}

const std::vector<std::string>& FixtureWorkspaceExecutor::hook_history() const noexcept { return hook_history_; }

LocalWorkspaceExecutor::LocalWorkspaceExecutor(std::filesystem::path root)
    : root_(std::filesystem::absolute(std::move(root)).lexically_normal()) {
  std::filesystem::create_directories(root_);
  root_ = std::filesystem::canonical(root_);
}

std::filesystem::path LocalWorkspaceExecutor::contained(const std::filesystem::path& candidate) const {
  const auto absolute = candidate.is_absolute() ? candidate.lexically_normal() : (root_ / candidate).lexically_normal();
  const auto relative = absolute.lexically_relative(root_);
  if (relative.empty() || relative.is_absolute() || *relative.begin() == "..") {
    throw std::runtime_error("workspace path escapes configured root");
  }
  return absolute;
}

std::optional<Workspace> LocalWorkspaceExecutor::find(const domain::Issue& issue) const {
  const auto path = contained(workspace_leaf(issue));
  if (!std::filesystem::is_directory(path) || std::filesystem::is_symlink(path)) return std::nullopt;
  if (std::filesystem::canonical(path) != path) return std::nullopt;
  return Workspace{path, issue.id, false};
}

Workspace LocalWorkspaceExecutor::create(const domain::Issue& issue) {
  const auto path = contained(workspace_leaf(issue));
  if (std::filesystem::is_symlink(path)) throw std::runtime_error("workspace path is a symlink");
  const auto newly_created = !std::filesystem::exists(path);
  std::filesystem::create_directories(path);
  std::filesystem::permissions(
      path,
      std::filesystem::perms::owner_all,
      std::filesystem::perm_options::replace);
  return {path, issue.id, newly_created};
}

void LocalWorkspaceExecutor::run_hook(
    const Workspace& workspace,
    const std::string_view hook_name,
    const std::vector<std::string>& command,
    const std::chrono::milliseconds timeout) {
  static_cast<void>(hook_name);
  if (command.empty()) return;
  if (timeout <= std::chrono::milliseconds::zero()) throw std::runtime_error("hook timeout must be positive");
  const auto path = contained(workspace.path);
  if (std::filesystem::is_symlink(path) || std::filesystem::canonical(path) != path) {
    throw std::runtime_error("hook workspace is not canonical and contained");
  }
  const auto child = ::fork();
  if (child < 0) throw std::runtime_error("cannot fork workspace hook");
  if (child == 0) {
    static_cast<void>(::setpgid(0, 0));
    if (::chdir(path.c_str()) != 0) _exit(126);
    std::vector<char*> arguments;
    arguments.reserve(command.size() + 1);
    for (const auto& value : command) arguments.push_back(const_cast<char*>(value.c_str()));
    arguments.push_back(nullptr);
    ::execvp(arguments.front(), arguments.data());
    _exit(127);
  }
  const auto deadline = std::chrono::steady_clock::now() + timeout;
  int status = 0;
  while (std::chrono::steady_clock::now() < deadline) {
    const auto result = ::waitpid(child, &status, WNOHANG);
    if (result == child) {
      if (WIFEXITED(status) && WEXITSTATUS(status) == 0) return;
      throw std::runtime_error("workspace hook failed");
    }
    if (result < 0) throw std::runtime_error("cannot wait for workspace hook");
    std::this_thread::sleep_for(std::chrono::milliseconds{5});
  }
  static_cast<void>(::kill(-child, SIGKILL));
  static_cast<void>(::waitpid(child, &status, 0));
  throw std::runtime_error("workspace hook timed out");
}

void LocalWorkspaceExecutor::remove(const Workspace& workspace) {
  const auto path = contained(workspace.path);
  if (std::filesystem::is_symlink(path)) throw std::runtime_error("refusing symlink workspace removal");
  if (std::filesystem::exists(path) && std::filesystem::canonical(path) != path) {
    throw std::runtime_error("refusing non-canonical workspace removal");
  }
  std::filesystem::remove_all(path);
}
}  // namespace symphony::workspace
