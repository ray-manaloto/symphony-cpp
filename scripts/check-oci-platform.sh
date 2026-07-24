#!/usr/bin/env bash
set -euo pipefail

readonly mode="${1:-}"
readonly architecture="${2:-}"

case "${architecture}" in
  amd64 | arm64) ;;
  *)
    echo "usage: $0 select-index|validate-image amd64|arm64" >&2
    exit 64
    ;;
esac

case "${mode}" in
  select-index)
    jq -er \
      --arg architecture "${architecture}" \
      '
        if .mediaType != "application/vnd.oci.image.index.v1+json" then
          error("compiler package must be an OCI image index")
        else
          [
            .manifests[]
            | select(
                .mediaType == "application/vnd.oci.image.manifest.v1+json"
                and .platform.os == "linux"
                and .platform.architecture == $architecture
              )
          ]
          | if length != 1 then
              error(
                "compiler package must contain exactly one linux/" +
                $architecture +
                " image manifest"
              )
            elif (.[0].digest | test("^sha256:[0-9a-f]{64}$")) then
              .[0].digest
            else
              error("compiler platform manifest has an invalid digest")
            end
        end
      '
    ;;
  validate-image)
    jq -e \
      --arg architecture "${architecture}" \
      '
        if .os == "linux" and .architecture == $architecture then
          true
        else
          error(
            "compiler child image config does not match linux/" +
            $architecture
          )
        end
      ' >/dev/null
    ;;
  *)
    echo "usage: $0 select-index|validate-image amd64|arm64" >&2
    exit 64
    ;;
esac
