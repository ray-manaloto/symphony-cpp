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

add_executable(symphony_supervisor_policy_tests
  test_main.cpp supervisor_policy_tests.cpp)
target_link_libraries(symphony_supervisor_policy_tests PRIVATE
  symphony_supervisor_policy ut::ut)
add_test(NAME symphony_supervisor_policy_tests
  COMMAND symphony_supervisor_policy_tests)

add_executable(symphony_control_records_tests
  test_main.cpp control_records_tests.cpp)
target_link_libraries(symphony_control_records_tests PRIVATE
  symphony_control_records ut::ut glaze::glaze)
add_test(NAME symphony_control_records_tests
  COMMAND symphony_control_records_tests)

add_executable(symphony_control_record_schema_generator
  control_record_schema_generator.cpp)
target_link_libraries(symphony_control_record_schema_generator PRIVATE
  symphony_control_records)

find_program(SYMPHONY_CHECK_JSONSCHEMA
  NAMES check-jsonschema
  REQUIRED)
set(control_record_schema_dir
  ${CMAKE_CURRENT_BINARY_DIR}/generated/control-record-schemas)
add_test(
  NAME symphony_control_record_schema_generate
  COMMAND symphony_control_record_schema_generator
    ${control_record_schema_dir})
set_tests_properties(symphony_control_record_schema_generate
  PROPERTIES FIXTURES_SETUP control_record_schemas)

add_test(
  NAME symphony_control_record_schema_metaschema
  COMMAND ${SYMPHONY_CHECK_JSONSCHEMA}
    --check-metaschema
    ${control_record_schema_dir}/task-packet-v1.schema.json
    ${control_record_schema_dir}/task-result-v1.schema.json
    ${control_record_schema_dir}/review-attestation-v1.schema.json
    ${control_record_schema_dir}/task-notepad-v1.schema.json)
set_tests_properties(symphony_control_record_schema_metaschema
  PROPERTIES FIXTURES_REQUIRED control_record_schemas)

function(symphony_control_record_schema_fixture name schema fixture expected_valid)
  add_test(
    NAME symphony_control_record_schema_${name}
    COMMAND ${CMAKE_COMMAND}
      -DCHECK_JSONSCHEMA=${SYMPHONY_CHECK_JSONSCHEMA}
      -DSCHEMA=${control_record_schema_dir}/${schema}
      -DINSTANCE=${PROJECT_SOURCE_DIR}/tests/fixtures/control-records/${fixture}
      -DEXPECT_VALID=${expected_valid}
      -DMAX_INSTANCE_BYTES=1048576
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckJsonSchemaFixture.cmake)
  set_tests_properties(symphony_control_record_schema_${name}
    PROPERTIES FIXTURES_REQUIRED control_record_schemas)
endfunction()

symphony_control_record_schema_fixture(
  task_packet_valid task-packet-v1.schema.json task-packet-v1.valid.json TRUE)
symphony_control_record_schema_fixture(
  task_packet_hostile task-packet-v1.schema.json task-packet-v1.hostile.json FALSE)
symphony_control_record_schema_fixture(
  task_packet_wrong_kind task-packet-v1.schema.json
  task-packet-v1.wrong-kind.json FALSE)
symphony_control_record_schema_fixture(
  task_packet_nested_unknown task-packet-v1.schema.json
  task-packet-v1.nested-unknown.json FALSE)
symphony_control_record_schema_fixture(
  task_result_valid task-result-v1.schema.json task-result-v1.valid.json TRUE)
symphony_control_record_schema_fixture(
  task_result_hostile task-result-v1.schema.json task-result-v1.hostile.json FALSE)
symphony_control_record_schema_fixture(
  review_valid review-attestation-v1.schema.json review-attestation-v1.valid.json TRUE)
symphony_control_record_schema_fixture(
  review_hostile review-attestation-v1.schema.json review-attestation-v1.hostile.json FALSE)
symphony_control_record_schema_fixture(
  notepad_valid task-notepad-v1.schema.json task-notepad-v1.valid.json TRUE)
symphony_control_record_schema_fixture(
  notepad_hostile task-notepad-v1.schema.json task-notepad-v1.hostile.json FALSE)
add_test(
  NAME symphony_control_record_schema_wrapper_self_test
  COMMAND ${CMAKE_COMMAND}
    -DSELF_TEST=TRUE
    -DCHECK_JSONSCHEMA=${SYMPHONY_CHECK_JSONSCHEMA}
    -DSCHEMA=${control_record_schema_dir}/task-packet-v1.schema.json
    -DINSTANCE=${PROJECT_SOURCE_DIR}/tests/fixtures/control-records/task-packet-v1.valid.json
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckJsonSchemaFixture.cmake)
set_tests_properties(symphony_control_record_schema_wrapper_self_test
  PROPERTIES FIXTURES_REQUIRED control_record_schemas)

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
  cib::lookup
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

if(SYMPHONY_ENABLE_RTSAN)
  add_executable(symphony_rtsan_safe_fixture rtsan_safe_fixture.cpp)
  target_link_libraries(symphony_rtsan_safe_fixture PRIVATE
    symphony_options symphony_rtsan_options)
  add_test(
    NAME symphony_rtsan_safe
    COMMAND symphony_rtsan_safe_fixture)

  add_executable(symphony_rtsan_violation_fixture rtsan_violation_fixture.cpp)
  target_link_libraries(symphony_rtsan_violation_fixture PRIVATE
    symphony_options symphony_rtsan_options)
  add_test(
    NAME symphony_rtsan_allocation_violation
    COMMAND ${CMAKE_COMMAND}
      -DPROGRAM=$<TARGET_FILE:symphony_rtsan_violation_fixture>
      -DMODE=allocation
      "-DEXPECTED_REPORT=RealtimeSanitizer: unsafe-library-call"
      -P ${PROJECT_SOURCE_DIR}/cmake/ExpectRtsanFailure.cmake)
  add_test(
    NAME symphony_rtsan_blocking_violation
    COMMAND ${CMAKE_COMMAND}
      -DPROGRAM=$<TARGET_FILE:symphony_rtsan_violation_fixture>
      -DMODE=blocking
      "-DEXPECTED_REPORT=RealtimeSanitizer: blocking-call"
      -P ${PROJECT_SOURCE_DIR}/cmake/ExpectRtsanFailure.cmake)
endif()

add_executable(symphony_reflection_tests test_main.cpp reflection_tests.cpp)
target_link_libraries(symphony_reflection_tests PRIVATE
  symphony_options symphony_reflection_options symphony_meta ut::ut)
add_test(NAME symphony_reflection_tests COMMAND symphony_reflection_tests)

add_executable(symphony_p2996_tests test_main.cpp p2996_tests.cpp)
target_link_libraries(symphony_p2996_tests PRIVATE
  symphony_reflection symphony_reflection_options ut::ut)
add_test(NAME symphony_p2996_tests COMMAND symphony_p2996_tests)

if(SYMPHONY_ENABLE_REFLECTION)
  add_executable(symphony_codex_protocol_reflection_tests
    test_main.cpp
    codex_protocol_reflection_tests.cpp)
  target_include_directories(symphony_codex_protocol_reflection_tests PRIVATE
    ${PROJECT_SOURCE_DIR}/src/codex)
  target_link_libraries(symphony_codex_protocol_reflection_tests PRIVATE
    symphony_meta symphony_reflection_options ut::ut)
  add_test(NAME symphony_codex_protocol_reflection_tests
    COMMAND symphony_codex_protocol_reflection_tests)

  add_executable(symphony_workflow_dto_reflection_tests
    test_main.cpp
    workflow_dto_reflection_tests.cpp)
  target_include_directories(symphony_workflow_dto_reflection_tests PRIVATE
    ${PROJECT_SOURCE_DIR}/src/workflow)
  target_link_libraries(symphony_workflow_dto_reflection_tests PRIVATE
    symphony_meta symphony_reflection_options ut::ut)
  add_test(NAME symphony_workflow_dto_reflection_tests
    COMMAND symphony_workflow_dto_reflection_tests)
endif()
