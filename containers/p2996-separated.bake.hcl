variable "CLANG_P2996_ARTIFACT_CONTEXT" {
  description = "Exact docker-image:// GHCR clang-p2996 artifact reference ending in @sha256:<digest>"
  default     = ""
  validation {
    condition     = can(regex("^docker-image://[^@[:space:]]+@sha256:[0-9a-f]{64}$", CLANG_P2996_ARTIFACT_CONTEXT))
    error_message = "CLANG_P2996_ARTIFACT_CONTEXT must be an exact docker-image:// reference pinned by sha256 digest"
  }
}

group "default" {
  targets = ["clang-p2996-validation"]
}

target "clang-p2996-runtime" {
  context    = "."
  dockerfile = "containers/Containerfile"
  target     = "symphony-ci-clang"
  platforms  = ["linux/amd64"]
  contexts = {
    "clang-p2996-artifact-input" = CLANG_P2996_ARTIFACT_CONTEXT
  }
  output = ["type=cacheonly"]
}

target "clang-p2996-validation" {
  context    = "."
  dockerfile = "containers/validation/clang-p2996.Containerfile"
  target     = "clang-p2996-validation"
  platforms  = ["linux/amd64"]
  contexts = {
    "runtime-base" = "target:clang-p2996-runtime"
  }
  output = ["type=cacheonly"]
}
