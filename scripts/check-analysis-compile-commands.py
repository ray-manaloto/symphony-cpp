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


def validate_toolchain(
    relative_source: Path, tokens: list[str], failures: list[str]
) -> None:
    compiler = "/opt/llvm-22.1.8/bin/clang++"
    valid_driver = tokens[:1] == [compiler] or (
        len(tokens) >= 2
        and Path(tokens[0]).name == "ccache"
        and tokens[1] == compiler
    )
    if not valid_driver:
        failures.append(
            f"{relative_source}: command does not invoke pinned Clang through ccache"
        )

    gcc_selectors = [
        token
        for token in tokens
        if token.startswith(("--gcc-install-dir", "--gcc-toolchain", "--gcc-triple"))
    ]
    if gcc_selectors != ["--gcc-toolchain=/opt/gcc-16.1"]:
        failures.append(
            f"{relative_source}: invalid GCC selectors "
            f"{', '.join(gcc_selectors) or '<none>'}"
        )

    language_standards = [token for token in tokens if token.startswith("-std=")]
    if language_standards != ["-std=c++26"]:
        failures.append(
            f"{relative_source}: invalid language standards "
            f"{', '.join(language_standards) or '<none>'}"
        )
    if any(token.startswith("-stdlib=") and token != "-stdlib=libstdc++" for token in tokens):
        failures.append(f"{relative_source}: conflicting C++ standard library")
    header_redirection_options = (
        "--sysroot",
        "-isysroot",
        "-cxx-isystem",
        "-stdlib++-isystem",
        "--target",
        "-target",
    )
    if (
        any(
            token in {"-nostdinc", "-nostdinc++", "-nostdlibinc"}
            or any(
                token == option or token.startswith(f"{option}=")
                for option in header_redirection_options
            )
            for token in tokens
        )
        or any("/usr/include/c++" in token for token in tokens)
    ):
        failures.append(f"{relative_source}: conflicting C++ include search path")


def main() -> int:
    if len(sys.argv) not in {2, 3} or (
        len(sys.argv) == 3 and sys.argv[2] != "--require-rtsan-fixtures"
    ):
        print(
            f"usage: {Path(sys.argv[0]).name} COMPILE_COMMANDS "
            "[--require-rtsan-fixtures]",
            file=sys.stderr,
        )
        return 64

    require_rtsan_fixtures = len(sys.argv) == 3
    database_path = Path(sys.argv[1])
    repository_root = Path.cwd().resolve()
    entries = json.loads(database_path.read_text(encoding="utf-8"))
    if not isinstance(entries, list):
        raise ValueError("compilation database root is not an array")

    expected_sources = {
        source.resolve()
        for source in (repository_root / "src").rglob("*")
        if source.is_file() and source.suffix in {".cc", ".cpp", ".cxx"}
    }
    analyzed_sources: set[Path] = set()
    expected_rtsan_fixtures = {
        Path("tests/rtsan_safe_fixture.cpp"),
        Path("tests/rtsan_violation_fixture.cpp"),
    }
    validated_rtsan_fixtures: set[Path] = set()
    analyzed = 0
    failures: list[str] = []
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
        try:
            relative_source = source_path.resolve().relative_to(repository_root)
        except ValueError:
            continue
        tokens = command_tokens(entry)
        if require_rtsan_fixtures:
            controlled_rtsan_flags = {
                "-fsanitize=realtime",
                "-Werror=function-effects",
                "-Werror=perf-constraint-implies-noexcept",
            }
            escaped_rtsan_flags = sorted(controlled_rtsan_flags.intersection(tokens))
            if (
                relative_source not in expected_rtsan_fixtures
                and escaped_rtsan_flags
            ):
                failures.append(
                    f"{relative_source}: RTSan flags escaped fixture allowlist "
                    f"{', '.join(escaped_rtsan_flags)}"
                )
            disabled_effect_flags = [
                token
                for token in tokens
                if token
                in {
                    "-Wno-function-effects",
                    "-Wno-error=function-effects",
                    "-Wno-perf-constraint-implies-noexcept",
                    "-Wno-error=perf-constraint-implies-noexcept",
                }
            ]
            if disabled_effect_flags:
                failures.append(
                    f"{relative_source}: disabled function-effect enforcement "
                    f"{', '.join(disabled_effect_flags)}"
                )
        if require_rtsan_fixtures and relative_source in expected_rtsan_fixtures:
            validated_rtsan_fixtures.add(relative_source)
            validate_toolchain(relative_source, tokens, failures)
            required_rtsan_flags = {
                "-fsanitize=realtime",
                "-fno-omit-frame-pointer",
                "-Werror=function-effects",
                "-Werror=perf-constraint-implies-noexcept",
            }
            for required_flag in sorted(required_rtsan_flags):
                if tokens.count(required_flag) != 1:
                    failures.append(
                        f"{relative_source}: expected exactly one {required_flag}"
                    )
            other_sanitizers = [
                token
                for token in tokens
                if token.startswith("-fsanitize=") and token != "-fsanitize=realtime"
            ]
            if other_sanitizers:
                failures.append(
                    f"{relative_source}: conflicting sanitizers "
                    f"{', '.join(other_sanitizers)}"
                )
        if relative_source.parent.parts[:1] != ("src",) or relative_source.suffix not in {
            ".cc",
            ".cpp",
            ".cxx",
        }:
            continue

        analyzed += 1
        analyzed_sources.add(source_path.resolve())
        validate_toolchain(relative_source, tokens, failures)

    if analyzed == 0:
        failures.append("no project src/*.{cc,cpp,cxx} compile commands found")
    for missing_source in sorted(expected_sources.difference(analyzed_sources)):
        failures.append(
            f"{missing_source.relative_to(repository_root)}: no compile command"
        )
    if require_rtsan_fixtures:
        for missing_fixture in sorted(
            expected_rtsan_fixtures.difference(validated_rtsan_fixtures)
        ):
            failures.append(f"{missing_fixture}: no RTSan compile command")
    if failures:
        print("invalid analysis compilation database:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    print(f"analysis compilation database passed: {analyzed} source command(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
