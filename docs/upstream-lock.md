# Upstream lock

Accessed 2026-07-22.

| Input | Immutable identity | Role |
| --- | --- | --- |
| OpenAI Symphony | `1f3219bb1ea5f69a1305dc594e79b0db57c113c5` | Normative Draft v1 specification |
| openai/codex-universal | multi-arch digest `sha256:905e512f36460e1be4cfedb30928a8a28299edb0fcd5de7998ceaa72d27fe304`; AMD64 manifest `sha256:1641c7bc30b00e0c5d4858b3e4da750123e9802fdb8086e9baa5afa2bc99393c` | Container base |
| GCC 16.1.0 tar.xz | SHA-256 `50efb4d94c3397aff3b0d61a5abd748b4dd31d9d3f2ab7be05b171d36a510f79`; signature key fingerprint `D3A93CAD751C2AF4F8C7AD516C35B99309B5FA62` | Release compiler source |
| Docker Official GCC 16.1 | AMD64 manifest `sha256:4eb18b10b4b6464ba0409fa9d6d0a3ed81c5246e086ac7b7bfe2fa5c8b01e4cb` | Fast source/reflection CI only |
| bloomberg/clang-p2996 | `7220baffd57ea5b0f8cf59bee494dd5b7cc2b748` | Differential reflection compiler |
| Microsoft vcpkg registry | `4493042c759d3bdff26164695dbee500d1e696c8` | Manifest dependency graph and bootstrap tool |
| stephenberry/glaze | `v7.9.0` / `f33758ad0c912471f2580fb7b3bf3a2b103214b9`; source tarball SHA-512 `902e3d707f5c2d07bd74abb232ba6dfed78a5b83ed2a9c6151d4cb53ef5724f4162afaba8b398b910c795b03692d0a648f615d89ad4e35ac8fdeeaf7bf1d9eff` | JSON codecs, typed protocol DTOs, and reflected schema generation |
| openalgz/ut | `v1.2.0` / `864c810899c497640784baa82c93e2fad4a3f7ce`; source tarball SHA-512 `dd5acfc244ec7a746cbffafc4739728cccef02f591ae714db22a20b7d5d70352aaade16ae92cca528ae4715a1f57952335e9cba184053b283562a28fca784994` | Unit-test framework supplied by the repository overlay port |
| Boost.Process | `1.91.0` from pinned vcpkg baseline; source archive SHA-512 `5e7199970509baa84199899f5f47d2114a9f44a4ecd9dc91ed55590fc4ec79ee7ef56b70e79e1a2b44da7e2e47d6a4fb55dcd2e3776f4fd2b279b91b8413ad02` | Process v2 compatibility gate and planned child-process lifecycle owner |
| openai/openai-openapi | `f9400172ebe08522ab228b771d885e3bd5456e42`; `openapi.yaml` SHA-256 `0e6756eca8e097e1738f273d0fa288dd745d75ee298c038a8bc9b8c6301f42d7` | OpenAI REST API reference schema |
| OpenAPI Generator | `v7.24.0`; image digest `sha256:5bf3dc75f764c584da8e3344c51b2f3f1e74703461d46a035b5ac1d31515cc88` | Disposable C++ Boost.Beast reference generation |

The Codex Universal MIT notice and image SBOM are stored under its `LICENSES/` directory. The
owning repository explicitly permits publishing and distribution. Derived images retain that
material, and the GCC image includes the exact signed corresponding-source archive and COPYING
files under `/opt/gcc-16.1/sources/`.
