#include "symphony/workspace/workspace.hpp"

#include <cctype>
#include <iomanip>
#include <sstream>
#include <stdexcept>

namespace symphony::workspace {
namespace {
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
  std::string safe;
  for (const unsigned char character : issue.identifier) {
    if (std::isalnum(character) != 0 || character == '-' || character == '_') {
      safe += static_cast<char>(character);
    } else if (!safe.empty() && safe.back() != '-') {
      safe += '-';
    }
  }
  if (safe.empty()) safe = "issue";
  std::ostringstream suffix;
  suffix << std::hex << std::setfill('0') << std::setw(12) << (fnv1a(issue.id) & 0xffffffffffffULL);
  return safe + '-' + suffix.str();
}

FixtureWorkspaceExecutor::FixtureWorkspaceExecutor(std::filesystem::path root)
    : root_(std::filesystem::absolute(std::move(root)).lexically_normal()) {
  std::filesystem::create_directories(root_);
}

std::filesystem::path FixtureWorkspaceExecutor::contained(const std::string_view leaf) const {
  const auto candidate = (root_ / std::string{leaf}).lexically_normal();
  const auto relative = candidate.lexically_relative(root_);
  if (relative.empty() || relative.is_absolute() || *relative.begin() == "..") {
    throw std::runtime_error("workspace path escapes configured root");
  }
  return candidate;
}

Workspace FixtureWorkspaceExecutor::create(const domain::Issue& issue) {
  const auto path = contained(workspace_leaf(issue));
  if (std::filesystem::is_symlink(path)) throw std::runtime_error("workspace path is a symlink");
  std::filesystem::create_directories(path);
  return {path, issue.id};
}

void FixtureWorkspaceExecutor::run_hook(
    const Workspace& workspace,
    const std::string_view hook_name,
    const std::vector<std::string>& command,
    const std::chrono::milliseconds timeout) {
  const auto verified = contained(workspace.path.filename().native());
  if (verified != workspace.path.lexically_normal()) throw std::runtime_error("uncontained hook workspace");
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
}  // namespace symphony::workspace
