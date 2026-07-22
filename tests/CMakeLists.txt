add_executable(symphony_tests
  test_main.cpp
  domain_tests.cpp
  scheduler_tests.cpp
  workflow_tests.cpp
  workspace_tests.cpp
  codex_tests.cpp
  observability_tests.cpp)
target_sources(symphony_tests PRIVATE reflection_tests.cpp)
target_link_libraries(symphony_tests PRIVATE
  symphony_domain symphony_meta symphony_workflow symphony_scheduler symphony_tracker
  symphony_workspace symphony_codex symphony_observability)
add_test(NAME symphony_tests COMMAND symphony_tests)
