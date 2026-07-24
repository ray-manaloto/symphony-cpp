#include <optional>
#include <string>
#include <vector>

#include <glaze/yaml.hpp>
#include <ut/ut.hpp>

namespace {
struct ProbeHooks {
  std::optional<std::string> before_run;
};

struct ProbeTracker {
  std::string kind;
  glz::generic provider;
  std::vector<std::string> active_states;
};

struct ProbeWorkflow {
  std::optional<ProbeHooks> hooks;
  std::optional<ProbeTracker> tracker;
};
} // namespace

template <> struct glz::meta<ProbeHooks> {
  using T = ProbeHooks;
  static constexpr auto value = object("before_run", &T::before_run);
};

template <> struct glz::meta<ProbeTracker> {
  using T = ProbeTracker;
  static constexpr auto value =
      object("kind", &T::kind, "provider", &T::provider, "active_states", &T::active_states);
};

template <> struct glz::meta<ProbeWorkflow> {
  using T = ProbeWorkflow;
  static constexpr auto value = object("hooks", &T::hooks, "tracker", &T::tracker);
};

static ut::suite glaze_yaml_tests = [] {
  ut::test("Glaze YAML preserves workflow shapes and provider extensions") = [] {
    std::string yaml = "hooks:\n"
                       "  before_run: |\n"
                       "    echo fixture\n"
                       "tracker:\n"
                       "  kind: linear\n"
                       "  provider:\n"
                       "    project: symphony\n"
                       "    nested:\n"
                       "      enabled: true\n"
                       "  active_states: [Todo, In Progress]\n"
                       "future_extension:\n"
                       "  enabled: true\n";
    ProbeWorkflow workflow;

    const auto read_error =
        glz::read_yaml<glz::yaml::yaml_opts{.error_on_unknown_keys = false}>(workflow, yaml);

    ut::expect(!read_error);
    ut::expect(workflow.hooks.has_value());
    ut::expect(workflow.hooks->before_run == std::optional<std::string>{"echo fixture\n"});
    ut::expect(workflow.tracker.has_value());
    ut::expect(workflow.tracker->kind == std::string{"linear"});
    ut::expect(workflow.tracker->active_states ==
               std::vector<std::string>({"Todo", "In Progress"}));

    std::string provider_yaml;
    const auto write_error = glz::write_yaml(workflow.tracker->provider, provider_yaml);
    ut::expect(!write_error);
    ut::expect(provider_yaml.find("project") != std::string::npos);
    ut::expect(provider_yaml.find("symphony") != std::string::npos);
    ut::expect(provider_yaml.find("nested") != std::string::npos);
    ut::expect(provider_yaml.find("enabled") != std::string::npos);
  };
};
