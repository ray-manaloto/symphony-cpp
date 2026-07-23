# Third-party notices

## OpenAI codex-universal

The base image is licensed under the MIT License:

Copyright (c) 2025 OpenAI

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

The base image's component notices and SPDX SBOM remain at `/LICENSES/` in derived images.

## OpenSymphony

The external development-orchestrator image contains OpenSymphony v2.10.0, distributed under the
MIT License. Its exact source revision is recorded in `docs/research/sources.md`, and its license is
included in that image at `/LICENSES/OpenSymphony-LICENSE`.

## OpenAI Codex CLI

The external development-orchestrator image contains OpenAI Codex CLI 0.145.0, distributed under
the Apache License 2.0. The npm package retains its license and notices in the installed package.

## GCC 16.1

The GCC toolchain is distributed under GPLv3 and related runtime-library exceptions. The exact
signed corresponding-source archive, signature, signer key, and COPYING files are included at
`/opt/gcc-16.1/sources/` in the GCC development image.

## LLVM clang-p2996

Bloomberg's clang-p2996 fork derives from LLVM and is distributed under Apache-2.0 with LLVM
exceptions. Its exact source revision is recorded in `docs/upstream-lock.md`.

## Intel compile-time libraries

Intel compile-time-init-build, cpp-std-extensions, cpp-baremetal-concurrency, and
cpp-baremetal-senders-and-receivers are distributed under the Boost Software License 1.0. Their
exact source revisions and archive hashes are recorded in `docs/upstream-lock.md`; the vcpkg
overlay packages install each upstream license with the corresponding headers.
