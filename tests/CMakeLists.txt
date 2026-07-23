add_executable(symphony_tests
  test_main.cpp
  domain_tests.cpp
  scheduler_tests.cpp
  workflow_tests.cpp
  tracker_tests.cpp
  workspace_tests.cpp
  codex_tests.cpp
  cli_tests.cpp
  observability_tests.cpp)
target_sources(symphony_tests PRIVATE reflection_tests.cpp process_tests.cpp)
target_link_libraries(symphony_tests PRIVATE
  symphony_domain symphony_meta symphony_workflow symphony_scheduler symphony_tracker
  symphony_workspace symphony_codex symphony_observability symphony_cli
  ut::ut Boost::process)
target_compile_definitions(symphony_tests PRIVATE
  SYMPHONYD_PATH="$<TARGET_FILE:symphonyd>")
add_dependencies(symphony_tests symphonyd)
add_test(NAME symphony_tests COMMAND symphony_tests)
