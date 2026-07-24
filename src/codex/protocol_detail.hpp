#pragma once

#include <optional>
#include <string>
#include <vector>

#include <glaze/json/generic.hpp>

namespace symphony::codex::protocol_detail {

struct ClientInfo {
  std::string name;
  std::string title;
  std::string version;
};

struct InitializeParams {
  ClientInfo clientInfo;
};

struct ThreadStartParams {
  std::string cwd;
  std::optional<std::string> approvalPolicy;
  std::optional<std::string> sandbox;
  std::optional<std::string> model;
};

struct TurnInput {
  std::string type;
  std::string text;
};

struct TurnStartParams {
  std::string threadId;
  std::string cwd;
  std::vector<TurnInput> input;
  std::optional<std::string> approvalPolicy;
  std::optional<glz::raw_json> sandboxPolicy;
  std::optional<std::string> model;
  std::optional<std::string> effort;
};

} // namespace symphony::codex::protocol_detail
