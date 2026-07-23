add_executable(symphony_tests
  test_main.cpp
  domain_tests.cpp
  scheduler_tests.cpp
  workflow_tests.cpp
  glaze_yaml_tests.cpp
  tracker_tests.cpp
  workspace_tests.cpp
  codex_tests.cpp
  cli_tests.cpp
  observability_tests.cpp)
target_sources(symphony_tests PRIVATE process_tests.cpp)
target_link_libraries(symphony_tests PRIVATE
  symphony_domain symphony_meta symphony_workflow symphony_scheduler symphony_tracker
  symphony_workspace symphony_codex symphony_observability symphony_cli
  ut::ut Boost::process glaze::glaze)
target_compile_definitions(symphony_tests PRIVATE
  SYMPHONYD_PATH="$<TARGET_FILE:symphonyd>")
add_dependencies(symphony_tests symphonyd)
add_test(NAME symphony_tests COMMAND symphony_tests)
add_test(
  NAME symphony_workflow_document
  COMMAND $<TARGET_FILE:symphonyctl> validate ${PROJECT_SOURCE_DIR}/WORKFLOW.md)

add_executable(symphony_intel_provider_tests
  test_main.cpp
  intel_provider_tests.cpp)
set_property(TARGET symphony_intel_provider_tests
  PROPERTY CXX_SCAN_FOR_MODULES OFF)
target_link_libraries(symphony_intel_provider_tests PRIVATE
  symphony_options
  ut::ut
  Intel::baremetal_async
  Intel::baremetal_concurrency
  cib::nexus
  stdx::stdx)
add_test(
  NAME symphony_intel_provider_tests
  COMMAND symphony_intel_provider_tests)

add_executable(symphony_execution_tests test_main.cpp execution_tests.cpp)
set_property(TARGET symphony_execution_tests PROPERTY CXX_SCAN_FOR_MODULES OFF)
target_link_libraries(symphony_execution_tests PRIVATE
  symphony_execution ut::ut STDEXEC::stdexec)
add_test(NAME symphony_execution_tests COMMAND symphony_execution_tests)

add_executable(symphony_persistence_provider_tests
  test_main.cpp
  persistence_provider_tests.cpp)
set_property(TARGET symphony_persistence_provider_tests PROPERTY CXX_SCAN_FOR_MODULES OFF)
target_link_libraries(symphony_persistence_provider_tests PRIVATE
  symphony_options ut::ut Boost::sqlite)
add_test(
  NAME symphony_persistence_provider_tests
  COMMAND symphony_persistence_provider_tests)

add_executable(symphony_persistence_tests test_main.cpp persistence_tests.cpp)
set_property(TARGET symphony_persistence_tests PROPERTY CXX_SCAN_FOR_MODULES OFF)
target_link_libraries(symphony_persistence_tests PRIVATE
  symphony_persistence_events ut::ut Boost::sqlite)
add_test(NAME symphony_persistence_tests COMMAND symphony_persistence_tests)

add_executable(symphony_reflection_tests test_main.cpp reflection_tests.cpp)
target_link_libraries(symphony_reflection_tests PRIVATE
  symphony_options symphony_reflection_options symphony_meta ut::ut)
add_test(NAME symphony_reflection_tests COMMAND symphony_reflection_tests)

add_executable(symphony_p2996_tests test_main.cpp p2996_tests.cpp)
target_link_libraries(symphony_p2996_tests PRIVATE
  symphony_reflection symphony_reflection_options ut::ut)
add_test(NAME symphony_p2996_tests COMMAND symphony_p2996_tests)
