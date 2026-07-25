variable "GCC16_ARTIFACT_CONTEXT" {
  description = "Exact qualified GCC 16.1 linux/amd64 child reference"
  default     = ""
  validation {
    condition     = can(regex("^docker-image://[^@[:space:]]+@sha256:[0-9a-f]{64}$", GCC16_ARTIFACT_CONTEXT))
    error_message = "GCC16_ARTIFACT_CONTEXT must be an exact docker-image:// reference pinned by sha256 digest"
  }
}

variable "OPENSYMPHONY_IMAGE" {
  description = "Local-only OpenSymphony image tag"
  default     = "symphony-opensymphony:local"
  validation {
    condition     = can(regex("^symphony-opensymphony:[a-z0-9][a-z0-9._-]*$", OPENSYMPHONY_IMAGE))
    error_message = "OPENSYMPHONY_IMAGE must use the local symphony-opensymphony namespace"
  }
}

variable "SOURCE_REVISION" {
  description = "Reviewed symphony-cpp revision recorded on the clean local GCC runtime"
  default     = ""
  validation {
    condition     = can(regex("^[0-9a-f]{40}$", SOURCE_REVISION))
    error_message = "SOURCE_REVISION must be an exact lowercase 40-hex Git revision"
  }
}

variable "BUILD_INPUT_SHA256" {
  description = "Exact digest of the local OpenSymphony image and validation inputs"
  default     = ""
  validation {
    condition     = can(regex("^[0-9a-f]{64}$", BUILD_INPUT_SHA256))
    error_message = "BUILD_INPUT_SHA256 must be an exact lowercase SHA-256 digest"
  }
}

target "opensymphony-gcc-runtime" {
  context    = "."
  dockerfile = "containers/Containerfile"
  target     = "symphony-gcc-runtime"
  platforms  = ["linux/amd64"]
  contexts = {
    "gcc16-artifact-input" = GCC16_ARTIFACT_CONTEXT
  }
  args = {
    SOURCE_REVISION = SOURCE_REVISION
  }
  output = ["type=cacheonly"]
}

target "opensymphony-gcc-runtime-validation" {
  context    = "."
  dockerfile = "containers/validation/gcc16-runtime-candidate.Containerfile"
  target     = "gcc16-runtime-candidate-validation"
  platforms  = ["linux/amd64"]
  contexts = {
    "runtime-base" = "target:opensymphony-gcc-runtime"
  }
  output = ["type=cacheonly"]
}

target "opensymphony-local-common" {
  context    = "."
  dockerfile = "containers/OpenSymphony.Containerfile"
  platforms  = ["linux/amd64"]
  contexts = {
    "symphony-cpp-base"            = "target:opensymphony-gcc-runtime"
    "symphony-cpp-base-validation" = "target:opensymphony-gcc-runtime-validation"
  }
  args = {
    BUILD_INPUT_SHA256 = BUILD_INPUT_SHA256
    SOURCE_REVISION    = SOURCE_REVISION
  }
  tags   = [OPENSYMPHONY_IMAGE]
  output = ["type=docker"]
}

target "opensymphony-candidate-local" {
  inherits = ["opensymphony-local-common"]
  target   = "symphony-orchestrator-candidate"
}

target "opensymphony-validated-local" {
  inherits = ["opensymphony-local-common"]
  target   = "symphony-orchestrator"
}
