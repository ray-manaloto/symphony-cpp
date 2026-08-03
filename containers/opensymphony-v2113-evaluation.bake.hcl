variable "OPENSYMPHONY_IMAGE" {
  description = "Exact task-owned local OpenSymphony v2.11.3 evaluation tag"
  default     = ""
  validation {
    condition = (
      OPENSYMPHONY_IMAGE ==
      "symphony-opensymphony:osv2113-019fc0ca-ticket47"
    )
    error_message = "OPENSYMPHONY_IMAGE must be the exact authorized #47 tag"
  }
}

variable "BUILD_INPUT_SHA256" {
  description = "Domain-separated identity of every #47 image build-contract input"
  default     = ""
  validation {
    condition     = can(regex("^[0-9a-f]{64}$", BUILD_INPUT_SHA256))
    error_message = "BUILD_INPUT_SHA256 must be an exact lowercase SHA-256 digest"
  }
}

target "opensymphony-v2113-evaluation" {
  context    = "."
  dockerfile = "containers/OpenSymphony-v2113-evaluation.Containerfile"
  target     = "evaluation-image"
  platforms  = ["linux/amd64"]
  args = {
    BUILD_INPUT_SHA256 = BUILD_INPUT_SHA256
  }
  tags   = [OPENSYMPHONY_IMAGE]
  output = ["type=docker"]
}
