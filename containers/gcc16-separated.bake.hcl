variable "GCC16_ARTIFACT_CONTEXT" {
  description = "Exact docker-image:// GCC 16.1 manifest reference ending in @sha256:<digest>"
  default     = ""
  validation {
    condition     = can(regex("^docker-image://[^@[:space:]]+@sha256:[0-9a-f]{64}$", GCC16_ARTIFACT_CONTEXT))
    error_message = "GCC16_ARTIFACT_CONTEXT must be an exact docker-image:// reference pinned by sha256 digest"
  }
}

variable "GCC16_ARCH" {
  description = "GCC 16.1 runtime and validation architecture"
  default     = ""
  validation {
    condition     = contains(["amd64", "arm64"], GCC16_ARCH)
    error_message = "GCC16_ARCH must be exactly amd64 or arm64"
  }
}

variable "SOURCE_REVISION" {
  description = "Source revision recorded on the generic GCC runtime"
  default     = "unknown"
}

group "default" {
  targets = ["gcc16-validation"]
}

target "gcc16-runtime" {
  context    = "."
  dockerfile = "containers/Containerfile"
  target     = "symphony-gcc-runtime"
  platforms  = ["linux/${GCC16_ARCH}"]
  contexts = {
    "gcc16-artifact-input" = GCC16_ARTIFACT_CONTEXT
  }
  args = {
    SOURCE_REVISION = SOURCE_REVISION
  }
  output = ["type=cacheonly"]
}

target "gcc16-validation" {
  context    = "."
  dockerfile = "containers/validation/gcc16.Containerfile"
  target     = "gcc16-validation"
  platforms  = ["linux/${GCC16_ARCH}"]
  contexts = {
    "runtime-base" = "target:gcc16-runtime"
  }
  output = ["type=cacheonly"]
}
