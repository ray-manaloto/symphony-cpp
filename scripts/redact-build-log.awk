{
  lower = tolower($0)
  has_secret_marker = lower ~ /[[:alnum:]_]*(api[_-]?key|token|secret|password|passwd)[[:alnum:]_-]*/ || lower ~ /authorization/ || lower ~ /bearer[[:space:]]+/
  has_credential_url = lower ~ /:\/\/[^\/@[:space:]:]+:[^\/@[:space:]]+@/
  is_indented = $0 ~ /^[[:space:]]/
  is_secret_continuation = redact_indented_block && is_indented
  if (has_secret_marker || has_credential_url || is_secret_continuation) {
    print "[redacted secret-bearing build log line]"
  } else if (length($0) > 300) {
    print substr($0, 1, 300) "..."
  } else {
    print
  }
  if (has_secret_marker) {
    redact_indented_block = 1
  } else if (!is_indented) {
    redact_indented_block = 0
  }
}
