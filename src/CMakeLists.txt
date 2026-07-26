function(symphony_library name)
  add_library(${name} ${ARGN})
  target_include_directories(${name} PUBLIC ${PROJECT_SOURCE_DIR}/include)
  target_link_libraries(${name} PUBLIC symphony_options)
endfunction()

function(symphony_public_headers target visibility)
  target_sources(${target} ${visibility}
    FILE_SET public_headers
    TYPE HEADERS
    BASE_DIRS ${PROJECT_SOURCE_DIR}/include
    FILES ${ARGN})
endfunction()

symphony_library(symphony_domain domain/domain.cpp)
target_link_libraries(symphony_domain PRIVATE picosha2::picosha2)
symphony_public_headers(symphony_domain PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/domain/domain.hpp)
symphony_library(symphony_control_records control/records.cpp)
target_link_libraries(symphony_control_records PRIVATE glaze::glaze)
symphony_public_headers(symphony_control_records PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/control/records.hpp)
add_library(symphony_reflection INTERFACE)
target_include_directories(symphony_reflection
  INTERFACE ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(symphony_reflection INTERFACE symphony_options)
symphony_public_headers(symphony_reflection INTERFACE
  ${PROJECT_SOURCE_DIR}/include/symphony/meta/reflection.hpp)
add_library(symphony_meta INTERFACE)
target_include_directories(symphony_meta
  INTERFACE ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(symphony_meta INTERFACE
  symphony_reflection glaze::glaze)
symphony_public_headers(symphony_meta INTERFACE
  ${PROJECT_SOURCE_DIR}/include/symphony/meta/meta.hpp)
symphony_library(symphony_workflow workflow/workflow.cpp)
target_link_libraries(symphony_workflow PUBLIC glaze::glaze)
symphony_public_headers(symphony_workflow PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/workflow/workflow.hpp)
symphony_library(symphony_tracker tracker/tracker.cpp)
target_link_libraries(symphony_tracker PRIVATE cib::lookup)
symphony_public_headers(symphony_tracker PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/tracker/tracker.hpp)
symphony_library(symphony_workspace workspace/workspace.cpp)
target_link_libraries(symphony_workspace PRIVATE picosha2::picosha2)
symphony_public_headers(symphony_workspace PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/workspace/workspace.hpp)
symphony_library(symphony_codex codex/codex.cpp)
target_link_libraries(symphony_codex PUBLIC glaze::glaze Boost::process)
symphony_public_headers(symphony_codex PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/codex/codex.hpp)
symphony_library(symphony_supervisor_policy supervisor/policy.cpp)
target_link_libraries(symphony_supervisor_policy PUBLIC symphony_domain)
symphony_public_headers(symphony_supervisor_policy PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/supervisor/policy.hpp)
symphony_library(symphony_execution execution/execution.cpp)
set_property(TARGET symphony_execution PROPERTY CXX_SCAN_FOR_MODULES OFF)
target_link_libraries(symphony_execution PUBLIC symphony_codex symphony_domain)
target_link_libraries(symphony_execution PRIVATE STDEXEC::stdexec)
symphony_public_headers(symphony_execution PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/execution/execution.hpp)
symphony_library(symphony_persistence persistence/persistence.cpp)
set_property(TARGET symphony_persistence PROPERTY CXX_SCAN_FOR_MODULES OFF)
target_link_libraries(symphony_persistence PRIVATE
  Boost::sqlite symphony_execution)
symphony_public_headers(symphony_persistence PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/persistence/persistence.hpp)
symphony_library(symphony_observability observability/observability.cpp)
target_link_libraries(symphony_observability PUBLIC spdlog::spdlog)
target_link_libraries(symphony_observability PRIVATE glaze::glaze)
symphony_public_headers(symphony_observability PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/observability/observability.hpp
  ${PROJECT_SOURCE_DIR}/include/symphony/observability/spdlog_event_store.hpp)
symphony_library(symphony_persistence_events persistence/event_store.cpp)
target_link_libraries(symphony_persistence_events PUBLIC
  symphony_observability symphony_persistence)
symphony_public_headers(symphony_persistence_events PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/persistence/event_store.hpp)
symphony_library(symphony_cli cli/cli.cpp)
target_link_libraries(symphony_cli PUBLIC CLI11::CLI11)
symphony_public_headers(symphony_cli PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/cli/cli.hpp)
symphony_library(symphony_scheduler scheduler/scheduler.cpp)
target_link_libraries(symphony_scheduler PUBLIC
  symphony_domain symphony_tracker symphony_workspace symphony_codex
  symphony_execution symphony_observability)
target_link_libraries(symphony_scheduler PRIVATE fmt::fmt)
symphony_public_headers(symphony_scheduler PUBLIC
  ${PROJECT_SOURCE_DIR}/include/symphony/scheduler/scheduler.hpp)
target_link_libraries(symphony_workflow PUBLIC symphony_domain)

add_executable(symphonyd daemon/main.cpp)
target_link_libraries(symphonyd PRIVATE symphony_cli symphony_scheduler symphony_workflow)
add_executable(symphonyctl ctl/main.cpp)
target_link_libraries(symphonyctl PRIVATE symphony_scheduler symphony_workflow symphony_meta)
