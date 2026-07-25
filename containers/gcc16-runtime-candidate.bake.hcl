variable "RUNTIME_BASE_CONTEXT" {
  description = "Exact docker-image:// generic GCC runtime reference ending in @sha256:<digest>"
  default     = ""
  validation {
    condition     = can(regex("^docker-image://[^@[:space:]]+@sha256:[0-9a-f]{64}$", RUNTIME_BASE_CONTEXT))
    error_message = "RUNTIME_BASE_CONTEXT must be an exact docker-image:// reference pinned by sha256 digest"
  }
}

variable "RUNTIME_ARCH" {
  description = "Native architecture of the exact generic GCC runtime child"
  default     = ""
  validation {
    condition     = contains(["amd64", "arm64"], RUNTIME_ARCH)
    error_message = "RUNTIME_ARCH must be exactly amd64 or arm64"
  }
}

group "default" {
  targets = ["gcc16-runtime-candidate-validation"]
}

target "gcc16-runtime-candidate-validation" {
  context    = "."
  dockerfile = "containers/validation/gcc16-runtime-candidate.Containerfile"
  target     = "gcc16-runtime-candidate-validation"
  platforms  = ["linux/${RUNTIME_ARCH}"]
  contexts = {
    "runtime-base" = RUNTIME_BASE_CONTEXT
  }
  output = ["type=cacheonly"]
}
