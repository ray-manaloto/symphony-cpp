variable "CLANG_P2996_ARTIFACT_CONTEXT" {
  description = "Exact docker-image:// clang-p2996 linux/amd64 manifest reference"
  default     = ""
  validation {
    condition     = can(regex("^docker-image://[^@[:space:]]+@sha256:[0-9a-f]{64}$", CLANG_P2996_ARTIFACT_CONTEXT))
    error_message = "CLANG_P2996_ARTIFACT_CONTEXT must be an exact docker-image:// reference pinned by sha256 digest"
  }
}

group "default" {
  targets = ["symphony-gcc-runtime", "symphony-ci-clang", "symphony-analysis"]
}

target "common" {
  context = "."
  dockerfile = "containers/Containerfile"
  platforms = ["linux/amd64"]
}

target "symphony-gcc16" {
  inherits = ["common"]
  target = "symphony-gcc16"
}

target "symphony-gcc-runtime" {
  inherits = ["common"]
  target = "symphony-gcc-runtime"
}

target "symphony-ci-clang" {
  inherits = ["common"]
  target = "symphony-ci-clang"
  contexts = {
    "clang-p2996-artifact-input" = CLANG_P2996_ARTIFACT_CONTEXT
  }
}

target "symphony-analysis" {
  inherits = ["common"]
  target = "symphony-analysis"
}
