#!/usr/bin/env python3

import json
import shlex
import sys
from pathlib import Path


def command_tokens(entry: dict[str, object]) -> list[str]:
    arguments = entry.get("arguments")
    if isinstance(arguments, list) and all(isinstance(value, str) for value in arguments):
        return arguments
    command = entry.get("command")
    if isinstance(command, str):
        return shlex.split(command)
    raise ValueError("compile command has neither string arguments nor command")


def validate_link_command(path: Path, failures: list[str]) -> None:
    candidate_commands: list[list[str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        tokens = shlex.split(line)
        if any(
            token.endswith("/symphony_p2996_tests")
            or token == "tests/symphony_p2996_tests"
            for token in tokens
        ):
            candidate_commands.append(tokens)
    if len(candidate_commands) != 1:
        failures.append(
            "expected exactly one symphony_p2996_tests link command; "
            f"found {len(candidate_commands)}"
        )
        return

    tokens = candidate_commands[0]
    has_noop_prefix = tokens[:2] == [":", "&&"]
    has_noop_suffix = tokens[-2:] == ["&&", ":"]
    if has_noop_prefix != has_noop_suffix:
        failures.append("link command has a malformed Ninja no-op envelope")
        return
    if has_noop_prefix:
        tokens = tokens[2:-2]

    compiler = "/opt/clang-p2996/bin/clang++"
    valid_driver = tokens[:1] == [compiler] or (
        len(tokens) >= 2
        and Path(tokens[0]).name == "ccache"
        and tokens[1] == compiler
    )
    if not valid_driver:
        failures.append("link command does not invoke the pinned p2996 compiler")
    if tokens.count("-stdlib=libc++") != 1:
        failures.append("link command does not select exactly one pinned libc++")
    if tokens.count("-fuse-ld=lld") != 1:
        failures.append("link command does not select exactly one lld")
    rpaths = [
        token for token in tokens
        if token.startswith("-Wl,-rpath,/opt/clang-p2996/lib")
    ]
    if not rpaths:
        failures.append("link command has no pinned p2996 runtime rpath")


def main() -> int:
    if len(sys.argv) not in {2, 3}:
        print(
            f"usage: {Path(sys.argv[0]).name} COMPILE_COMMANDS [NINJA_COMMANDS]",
            file=sys.stderr,
        )
        return 64

    repository_root = Path.cwd().resolve()
    expected_source = (repository_root / "tests/p2996_tests.cpp").resolve()
    entries = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    if not isinstance(entries, list):
        raise ValueError("compilation database root is not an array")

    matching_commands: list[list[str]] = []
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("compilation database entry is not an object")
        source = entry.get("file")
        directory = entry.get("directory")
        if not isinstance(source, str) or not isinstance(directory, str):
            raise ValueError("compile command has no string file or directory")
        source_path = Path(source)
        if not source_path.is_absolute():
            source_path = Path(directory) / source_path
        if source_path.resolve() == expected_source:
            matching_commands.append(command_tokens(entry))

    if len(matching_commands) != 1:
        print(
            "p2996 compilation database must contain exactly one "
            f"tests/p2996_tests.cpp command; found {len(matching_commands)}",
            file=sys.stderr,
        )
        return 1

    tokens = matching_commands[0]
    compiler = "/opt/clang-p2996/bin/clang++"
    valid_driver = tokens[:1] == [compiler] or (
        len(tokens) >= 2
        and Path(tokens[0]).name == "ccache"
        and tokens[1] == compiler
    )
    failures: list[str] = []
    if not valid_driver:
        failures.append("command does not invoke the pinned p2996 compiler")

    standards = [token for token in tokens if token.startswith("-std=")]
    if standards != ["-std=c++26"]:
        failures.append(
            f"invalid language standards: {', '.join(standards) or '<none>'}"
        )

    standard_libraries = [token for token in tokens if token.startswith("-stdlib=")]
    if standard_libraries != ["-stdlib=libc++"]:
        failures.append(
            "invalid C++ standard libraries: "
            f"{', '.join(standard_libraries) or '<none>'}"
        )

    for required_flag in ("-freflection", "-fexpansion-statements"):
        if tokens.count(required_flag) != 1:
            failures.append(f"expected exactly one {required_flag}")
    if any(
        token in {"-freflection-latest", "-fno-reflection"}
        for token in tokens
    ):
        failures.append("conflicting reflection mode")

    forbidden_options = (
        "--gcc-install-dir",
        "--gcc-toolchain",
        "--gcc-triple",
        "--sysroot",
        "-isysroot",
        "-stdlib++-isystem",
        "--target",
        "-target",
    )
    if any(
        token in {"-nostdinc", "-nostdinc++", "-nostdlibinc"}
        or any(
            token == option or token.startswith(f"{option}=")
            for option in forbidden_options
        )
        or "/usr/include/c++" in token
        for token in tokens
    ):
        failures.append("conflicting compiler target or C++ include search path")

    if failures:
        for failure in failures:
            print(f"p2996 compile command: {failure}", file=sys.stderr)
        return 1

    if len(sys.argv) == 3:
        validate_link_command(Path(sys.argv[2]), failures)
        if failures:
            for failure in failures:
                print(f"p2996 toolchain command: {failure}", file=sys.stderr)
            return 1

    print("p2996 compilation database passed: 1 differential command")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
