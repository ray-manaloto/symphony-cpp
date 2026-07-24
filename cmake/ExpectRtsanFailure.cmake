foreach(required_variable IN ITEMS PROGRAM MODE EXPECTED_REPORT)
  if(NOT DEFINED ${required_variable})
    message(FATAL_ERROR "Missing required variable: ${required_variable}")
  endif()
endforeach()

execute_process(
  COMMAND "${PROGRAM}" "${MODE}"
  RESULT_VARIABLE program_result
  OUTPUT_VARIABLE program_stdout
  ERROR_VARIABLE program_stderr)

if("${program_result}" STREQUAL "0")
  message(FATAL_ERROR
    "RTSan ${MODE} control reported success instead of a fatal violation")
endif()

set(program_output "${program_stdout}\n${program_stderr}")
if(NOT program_output MATCHES "${EXPECTED_REPORT}")
  message(FATAL_ERROR
    "RTSan ${MODE} control omitted expected report: ${EXPECTED_REPORT}")
endif()
