#!/bin/sh
set -eu

# shellcheck disable=SC1007  # Empty CDPATH prevents cd from contaminating command substitution.
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
revision=f9400172ebe08522ab228b771d885e3bd5456e42
expected=0e6756eca8e097e1738f273d0fa288dd745d75ee298c038a8bc9b8c6301f42d7
image='docker.io/openapitools/openapi-generator-cli:v7.24.0@sha256:5bf3dc75f764c584da8e3344c51b2f3f1e74703461d46a035b5ac1d31515cc88'
input=.build/openai-openapi/openapi.yaml
output=.build/generated/openai-api

mkdir -p "$root/.build/openai-openapi" "$root/.build/generated"
curl --fail --location --silent --show-error \
  "https://raw.githubusercontent.com/openai/openai-openapi/$revision/openapi.yaml" \
  --output "$root/$input"
printf '%s  %s\n' "$expected" "$root/$input" | sha256sum --check --status
rm -rf "${root:?}/$output"

docker run --rm \
  --user "$(id -u):$(id -g)" \
  --volume "$root:/local" \
  "$image" generate \
  --input-spec "/local/$input" \
  --generator-name cpp-boost-beast-client \
  --output "/local/$output" \
  --additional-properties packageName=OpenAIApi,apiPackage=openai.api,modelPackage=openai.model \
  --global-property apis,models,supportingFiles \
  --skip-validate-spec

test -f "$root/$output/CMakeLists.txt"
printf 'Generated pinned OpenAI REST API reference client at %s\n' "$root/$output"
