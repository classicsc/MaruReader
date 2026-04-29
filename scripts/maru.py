#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import threading
from datetime import datetime
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent
LOG_DIR = ROOT_DIR / "build" / "logs"
PROJECT_PATH = ROOT_DIR / "MaruReader.xcodeproj"
SCHEME = "MaruReader"
DEFAULT_DESTINATION = "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1"
TEST_PLANS = [
    "MaruReaderTests",
    "MaruReaderCoreTests",
    "MaruDictionaryManagementTests",
    "MaruMangaTests",
    "MaruAnkiTests",
    "MaruWebTests",
    "MaruMarkTests",
    "MaruTextAnalysisTests",
]
RUST_CRATE_DIRS = [
    ROOT_DIR / "MaruMarkFFI",
    ROOT_DIR / "MaruAdblockFFI",
    ROOT_DIR / "MaruSudachiFFI",
]
SIMULATOR_LAUNCH_RACE = "is installing or uninstalling, and cannot be launched"


def sanitize_log_key(log_key: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "-", log_key)


def resolve_destination(destination_input: str) -> str:
    if not destination_input:
        return DEFAULT_DESTINATION
    if destination_input.startswith("generic/"):
        return destination_input
    if "platform=" in destination_input or "," in destination_input:
        return destination_input
    if re.fullmatch(r"[0-9A-Fa-f-]{8,}", destination_input):
        return f"platform=iOS Simulator,id={destination_input}"
    return f"platform=iOS Simulator,name={destination_input}"


def require_tool(tool: str) -> None:
    if shutil.which(tool) is None:
        print(f"{tool} is required but not found in PATH", file=sys.stderr)
        raise SystemExit(1)


def filter_misleading_test_summary(line: str) -> bool:
    return (
        re.fullmatch(
            r"\s*Executed 0 tests, with 0 failures \(0 unexpected\) in 0\.000 \([0-9.]+\) seconds\n?",
            line,
        )
        is None
    )


def extract_test_summary(raw_log_path: Path) -> str | None:
    swift_testing_summary = None
    xctest_summary = None
    swift_pattern = re.compile(r"\s*(.\s+)?Test run with \d+ tests in \d+ suites? (passed|failed) after ")
    xctest_pattern = re.compile(r"\s*Executed [1-9][0-9]* tests, with ")

    with raw_log_path.open(encoding="utf-8", errors="replace") as raw_log:
        for line in raw_log:
            stripped = line.strip()
            if swift_pattern.match(line):
                swift_testing_summary = stripped
            if xctest_pattern.match(line):
                xctest_summary = stripped

    return swift_testing_summary or xctest_summary


def run_xcodebuild(log_key: str, args: list[str], is_test_invocation: bool) -> int:
    require_tool("xcodebuild")
    require_tool("xcbeautify")

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    safe_log_key = sanitize_log_key(log_key)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    raw_log_path = LOG_DIR / f"{timestamp}-{safe_log_key}.raw.log"
    parsed_log_path = LOG_DIR / f"{timestamp}-{safe_log_key}.parsed.log"
    latest_raw_path = LOG_DIR / f"latest-{safe_log_key}.raw.log"
    latest_parsed_path = LOG_DIR / f"latest-{safe_log_key}.parsed.log"

    print(f"Running xcodebuild ({safe_log_key})", flush=True)
    print(f"Raw log: {raw_log_path}", flush=True)
    print(f"Parsed log: {parsed_log_path}", flush=True)

    xcodebuild = subprocess.Popen(
        ["xcodebuild", *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )
    assert xcodebuild.stdout is not None

    beautify = subprocess.Popen(
        ["xcbeautify", "-q"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )
    assert beautify.stdin is not None
    assert beautify.stdout is not None

    def read_beautified_output() -> None:
        with parsed_log_path.open("w", encoding="utf-8") as parsed_log:
            for line in beautify.stdout:
                if is_test_invocation and not filter_misleading_test_summary(line):
                    continue
                print(line, end="", flush=True)
                parsed_log.write(line)

    output_thread = threading.Thread(target=read_beautified_output)
    output_thread.start()

    with raw_log_path.open("w", encoding="utf-8") as raw_log:
        for line in xcodebuild.stdout:
            raw_log.write(line)
            beautify.stdin.write(line)

    xcodebuild_exit_code = xcodebuild.wait()
    beautify.stdin.close()
    beautify.wait()
    output_thread.join()

    if is_test_invocation:
        summary = extract_test_summary(raw_log_path)
        if summary:
            print(summary)
            with parsed_log_path.open("a", encoding="utf-8") as parsed_log:
                parsed_log.write(f"{summary}\n")

    shutil.copyfile(raw_log_path, latest_raw_path)
    shutil.copyfile(parsed_log_path, latest_parsed_path)

    print(f"Latest raw log: {latest_raw_path}")
    print(f"Latest parsed log: {latest_parsed_path}")

    return xcodebuild_exit_code


def xcodebuild_base_args(configuration: str, destination: str) -> list[str]:
    return [
        "-project",
        str(PROJECT_PATH),
        "-scheme",
        SCHEME,
        "-destination",
        destination,
        "-configuration",
        configuration,
    ]


def run_build(args: argparse.Namespace) -> int:
    destination = resolve_destination(args.destination)
    log_key = f"build-{args.configuration.lower()}"
    return run_xcodebuild(log_key, [*xcodebuild_base_args(args.configuration, destination), "build"], False)


def run_build_for_testing(args: argparse.Namespace) -> int:
    destination = resolve_destination(args.destination)
    return run_xcodebuild(
        "build-for-testing",
        [*xcodebuild_base_args(args.configuration, destination), "build-for-testing"],
        False,
    )


def test_without_building_args(configuration: str, destination: str, plan: str | None = None) -> list[str]:
    xcode_args = xcodebuild_base_args(configuration, destination)
    if plan:
        xcode_args.extend(["-testPlan", plan])
    xcode_args.append("test-without-building")
    return xcode_args


def run_test_plan_once(plan: str, configuration: str, destination: str) -> int:
    log_key = f"test-plan-{plan}"
    latest_raw_log_path = LOG_DIR / f"latest-{sanitize_log_key(log_key)}.raw.log"

    for attempt in (1, 2):
        exit_code = run_xcodebuild(log_key, test_without_building_args(configuration, destination, plan), True)
        if exit_code == 0:
            return 0
        if attempt == 2:
            return exit_code
        if latest_raw_log_path.exists() and SIMULATOR_LAUNCH_RACE in latest_raw_log_path.read_text(
            encoding="utf-8", errors="replace"
        ):
            print(f"Retrying test plan {plan} after simulator launch race...", flush=True)
            import time

            time.sleep(15)
            continue
        return exit_code

    return 1


def run_test_plan(args: argparse.Namespace) -> int:
    destination = resolve_destination(args.destination)
    build_exit_code = run_xcodebuild(
        "build-for-testing",
        [*xcodebuild_base_args(args.configuration, destination), "build-for-testing"],
        False,
    )
    if build_exit_code != 0:
        return build_exit_code
    return run_test_plan_once(args.plan, args.configuration, destination)


def run_test_one(args: argparse.Namespace) -> int:
    destination = resolve_destination(args.destination)
    build_exit_code = run_xcodebuild(
        "build-for-testing",
        [*xcodebuild_base_args(args.configuration, destination), "build-for-testing"],
        False,
    )
    if build_exit_code != 0:
        return build_exit_code

    xcode_args = xcodebuild_base_args(args.configuration, destination)
    if args.plan:
        xcode_args.extend(["-testPlan", args.plan])
    xcode_args.extend([f"-only-testing:{args.only_testing}", "test-without-building"])
    return run_xcodebuild(f"test-one-{args.only_testing}", xcode_args, True)


def crate_package_name(crate_dir: Path) -> str:
    manifest = crate_dir / "Cargo.toml"
    for line in manifest.read_text(encoding="utf-8").splitlines():
        if line.startswith("name = "):
            return line.split("=", 1)[1].strip().strip('"')
    return crate_dir.name


def rust_crates(crate: str | None) -> list[Path]:
    if not crate:
        return RUST_CRATE_DIRS

    matches = []
    for crate_dir in RUST_CRATE_DIRS:
        names = {crate_dir.name, crate_package_name(crate_dir), str(crate_dir.relative_to(ROOT_DIR))}
        if crate in names:
            matches.append(crate_dir)

    if matches:
        return matches

    crate_path = (ROOT_DIR / crate).resolve()
    if (crate_path / "Cargo.toml").exists():
        return [crate_path]

    valid = ", ".join(f"{path.name} ({crate_package_name(path)})" for path in RUST_CRATE_DIRS)
    print(f"Unknown Rust crate '{crate}'. Valid crates: {valid}", file=sys.stderr)
    raise SystemExit(1)


def run_cargo_test(crate_dir: Path) -> int:
    require_tool("cargo")
    print(f"Running cargo test ({crate_dir.relative_to(ROOT_DIR)})", flush=True)
    env = os.environ.copy()
    env["PATH"] = f"/opt/homebrew/bin:/usr/local/bin:{Path.home() / '.cargo' / 'bin'}:{env.get('PATH', '')}"
    return subprocess.run(["cargo", "test", "--locked"], cwd=crate_dir, env=env).returncode


def run_test_crate(args: argparse.Namespace) -> int:
    for crate_dir in rust_crates(args.crate):
        exit_code = run_cargo_test(crate_dir)
        if exit_code != 0:
            return exit_code
    return 0


def run_all_tests(args: argparse.Namespace) -> int:
    destination = resolve_destination(args.destination)
    build_exit_code = run_xcodebuild(
        "build-for-testing",
        [*xcodebuild_base_args(args.configuration, destination), "build-for-testing"],
        False,
    )
    if build_exit_code != 0:
        return build_exit_code

    for plan in TEST_PLANS:
        exit_code = run_test_plan_once(plan, args.configuration, destination)
        if exit_code != 0:
            return exit_code

    return run_test_crate(argparse.Namespace(crate=None))


def add_configuration_and_destination(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("configuration", nargs="?", default="Debug")
    parser.add_argument("destination", nargs="?", default="")


def main() -> int:
    parser = argparse.ArgumentParser(description="MaruReader build and test harness")
    subparsers = parser.add_subparsers(dest="command", required=True)

    build_parser = subparsers.add_parser("build")
    add_configuration_and_destination(build_parser)
    build_parser.set_defaults(func=run_build)

    build_for_testing_parser = subparsers.add_parser("build-for-testing")
    add_configuration_and_destination(build_for_testing_parser)
    build_for_testing_parser.set_defaults(func=run_build_for_testing)

    test_parser = subparsers.add_parser("test")
    test_parser.add_argument("destination", nargs="?", default="")
    test_parser.add_argument("--configuration", default="Debug")
    test_parser.set_defaults(func=run_all_tests)

    test_plan_parser = subparsers.add_parser("test-plan")
    test_plan_parser.add_argument("plan")
    test_plan_parser.add_argument("destination", nargs="?", default="")
    test_plan_parser.add_argument("--configuration", default="Debug")
    test_plan_parser.set_defaults(func=run_test_plan)

    test_one_parser = subparsers.add_parser("test-one")
    test_one_parser.add_argument("only_testing")
    test_one_parser.add_argument("plan", nargs="?", default="")
    test_one_parser.add_argument("destination", nargs="?", default="")
    test_one_parser.add_argument("--configuration", default="Debug")
    test_one_parser.set_defaults(func=run_test_one)

    test_crate_parser = subparsers.add_parser("test-crate")
    test_crate_parser.add_argument("crate", nargs="?")
    test_crate_parser.set_defaults(func=run_test_crate)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
