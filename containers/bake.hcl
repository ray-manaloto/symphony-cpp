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

target "symphony-clang-p2996" {
  inherits = ["common"]
  target = "symphony-clang-p2996"
}

target "symphony-gcc-runtime" {
  inherits = ["common"]
  target = "symphony-gcc-runtime"
}

target "symphony-ci-clang" {
  inherits = ["common"]
  target = "symphony-ci-clang"
}

target "symphony-analysis" {
  inherits = ["common"]
  target = "symphony-analysis"
}
