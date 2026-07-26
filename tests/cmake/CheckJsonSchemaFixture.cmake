cmake_minimum_required(VERSION 4.4)

if(SELF_TEST)
  execute_process(
    COMMAND ${CMAKE_COMMAND}
      -DCHECK_JSONSCHEMA=${CHECK_JSONSCHEMA}
      -DSCHEMA=${SCHEMA}
      -DINSTANCE=${CMAKE_CURRENT_LIST_DIR}/does-not-exist.json
      -DEXPECT_VALID=FALSE
      -DMAX_INSTANCE_BYTES=1048576
      -P ${CMAKE_CURRENT_LIST_FILE}
    RESULT_VARIABLE missing_result
    OUTPUT_VARIABLE missing_output
    ERROR_VARIABLE missing_error)
  if(missing_result EQUAL 0 OR
     NOT missing_error MATCHES "instance file does not exist")
    message(FATAL_ERROR
      "schema wrapper accepted or misclassified a missing instance file")
  endif()

  execute_process(
    COMMAND ${CMAKE_COMMAND}
      -DCHECK_JSONSCHEMA=${CHECK_JSONSCHEMA}
      -DSCHEMA=${SCHEMA}
      -DINSTANCE=${INSTANCE}
      -DEXPECT_VALID=TRUE
      -DMAX_INSTANCE_BYTES=1
      -P ${CMAKE_CURRENT_LIST_FILE}
    RESULT_VARIABLE oversized_result
    OUTPUT_VARIABLE oversized_output
    ERROR_VARIABLE oversized_error)
  if(oversized_result EQUAL 0 OR
     NOT oversized_error MATCHES "instance exceeds the configured byte limit")
    message(FATAL_ERROR
      "schema wrapper accepted or misclassified an oversized instance file")
  endif()
  return()
endif()

foreach(required IN ITEMS
    CHECK_JSONSCHEMA
    SCHEMA
    INSTANCE
    EXPECT_VALID
    MAX_INSTANCE_BYTES)
  if(NOT DEFINED ${required})
    message(FATAL_ERROR "missing required argument: ${required}")
  endif()
endforeach()

if(NOT EXISTS "${SCHEMA}")
  message(FATAL_ERROR "schema file does not exist")
endif()
if(NOT EXISTS "${INSTANCE}")
  message(FATAL_ERROR "instance file does not exist")
endif()

file(SIZE "${INSTANCE}" instance_bytes)
if(instance_bytes GREATER MAX_INSTANCE_BYTES)
  message(FATAL_ERROR "instance exceeds the configured byte limit")
endif()

execute_process(
  COMMAND "${CHECK_JSONSCHEMA}"
    --output-format json
    --schemafile "${SCHEMA}"
    "${INSTANCE}"
  RESULT_VARIABLE validator_result
  OUTPUT_VARIABLE validator_output
  ERROR_VARIABLE validator_error)

if(NOT validator_error STREQUAL "")
  message(FATAL_ERROR "check-jsonschema reported an operational error")
endif()

string(JSON validator_status
  ERROR_VARIABLE status_error
  GET "${validator_output}" status)
string(JSON validator_error_count
  ERROR_VARIABLE errors_error
  LENGTH "${validator_output}" errors)
if(NOT status_error STREQUAL "NOTFOUND" OR
   NOT errors_error STREQUAL "NOTFOUND")
  message(FATAL_ERROR "check-jsonschema did not return the expected JSON result")
endif()

if(EXPECT_VALID)
  if(NOT validator_result EQUAL 0 OR
     NOT validator_status STREQUAL "ok" OR
     NOT validator_error_count EQUAL 0)
    message(FATAL_ERROR "expected schema-valid instance was rejected")
  endif()
else()
  if(NOT validator_result EQUAL 1 OR
     NOT validator_status STREQUAL "fail" OR
     validator_error_count LESS 1)
    message(FATAL_ERROR
      "expected schema rejection was not a validator-produced failure")
  endif()
endif()
