variable "CLANG_P2996_ARTIFACT_CONTEXT" {
  description = "Exact docker-image:// clang-p2996 linux/amd64 manifest reference"
  default     = "docker-image://invalid.invalid/required-clang-p2996-artifact@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  validation {
    condition     = can(regex("^docker-image://[^@[:space:]]+@sha256:[0-9a-f]{64}$", CLANG_P2996_ARTIFACT_CONTEXT))
    error_message = "CLANG_P2996_ARTIFACT_CONTEXT must be an exact docker-image:// reference pinned by sha256 digest"
  }
}

variable "GCC16_ARTIFACT_CONTEXT" {
  description = "Exact docker-image:// GCC 16.1 native manifest reference"
  default     = "docker-image://invalid.invalid/required-gcc16-artifact@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  validation {
    condition     = can(regex("^docker-image://[^@[:space:]]+@sha256:[0-9a-f]{64}$", GCC16_ARTIFACT_CONTEXT))
    error_message = "GCC16_ARTIFACT_CONTEXT must be an exact docker-image:// reference pinned by sha256 digest"
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

target "symphony-gcc-runtime" {
  inherits = ["common"]
  target = "symphony-gcc-runtime"
  contexts = {
    "gcc16-artifact-input" = GCC16_ARTIFACT_CONTEXT
  }
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
  contexts = {
    "gcc16-artifact-input" = GCC16_ARTIFACT_CONTEXT
  }
}
