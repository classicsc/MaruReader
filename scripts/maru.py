#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
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
PROJECT_FILE = PROJECT_PATH / "project.pbxproj"
SCHEME = "MaruReader"
DEFAULT_DESTINATION = "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1"
RELEASE_TARGETS = ["MaruReader", "MaruShareExtension", "MaruAssetDownloader"]
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


def die(message: str) -> None:
    print(message, file=sys.stderr)
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


def project_json() -> dict:
    require_tool("plutil")
    result = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(PROJECT_FILE)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr, end="")
        raise SystemExit(result.returncode)
    return json.loads(result.stdout)


def target_config_ids(project: dict) -> list[str]:
    objects = project["objects"]
    config_ids = []
    for object_id, value in objects.items():
        if value.get("isa") == "PBXNativeTarget" and value.get("name") in RELEASE_TARGETS:
            config_list_id = value["buildConfigurationList"]
            config_ids.extend(objects[config_list_id]["buildConfigurations"])
    return sorted(set(config_ids))


def unique_setting_value(project: dict, config_ids: list[str], key: str) -> str:
    objects = project["objects"]
    values = sorted({objects[config_id]["buildSettings"].get(key) for config_id in config_ids})
    if len(values) != 1:
        joined_values = ", ".join(str(value) for value in values)
        die(f"Expected a single synced value for {key} across {' '.join(RELEASE_TARGETS)}, found: {joined_values}")
    return str(values[0])


def current_marketing_version(project: dict, config_ids: list[str]) -> str:
    return unique_setting_value(project, config_ids, "MARKETING_VERSION")


def current_build_number(project: dict, config_ids: list[str]) -> str:
    return unique_setting_value(project, config_ids, "CURRENT_PROJECT_VERSION")


def update_setting_for_config(project_text: str, config_id: str, key: str, value: str) -> str:
    pattern = re.compile(
        rf"({re.escape(config_id)}\s*/\*.*?\*/\s*=\s*\{{.*?buildSettings\s*=\s*\{{.*?\b{re.escape(key)}\s*=\s*)[^;]+(;)",
        re.DOTALL,
    )
    updated_text, count = pattern.subn(rf"\g<1>{value}\2", project_text, count=1)
    if count != 1:
        die(f"Failed to update {key} for {config_id}")
    return updated_text


def set_synced_settings(marketing_version: str | None = None, build_number: str | None = None) -> None:
    project = project_json()
    config_ids = target_config_ids(project)
    project_text = PROJECT_FILE.read_text(encoding="utf-8")
    for config_id in config_ids:
        if marketing_version is not None:
            project_text = update_setting_for_config(project_text, config_id, "MARKETING_VERSION", marketing_version)
        if build_number is not None:
            project_text = update_setting_for_config(project_text, config_id, "CURRENT_PROJECT_VERSION", build_number)
    PROJECT_FILE.write_text(project_text, encoding="utf-8")


def ensure_clean_worktree() -> None:
    result = subprocess.run(["git", "-C", str(ROOT_DIR), "status", "--short"], text=True, stdout=subprocess.PIPE)
    if result.stdout:
        print(result.stdout, end="")
        die("Working tree must be clean before starting the release workflow.")


def ensure_tag_absent(tag_name: str) -> None:
    result = subprocess.run(
        ["git", "-C", str(ROOT_DIR), "rev-parse", "--verify", "--quiet", f"refs/tags/{tag_name}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode == 0:
        die(f"Git tag {tag_name} already exists.")


def normalize_tag_version(version: str) -> str:
    if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        return version
    if re.fullmatch(r"[0-9]+\.[0-9]+", version):
        return f"{version}.0"
    die(f"Version {version} cannot be converted to a semver tag. Use Xcode Version values like 1.2.3.")


def validate_release_version(version: str) -> None:
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        die("Release version must use semver major.minor.patch.")


def run_release_prep() -> None:
    result = subprocess.run(["swift", str(ROOT_DIR / "scripts" / "sync-third-party-licenses.swift"), "--refresh-snapshots"])
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def archive_for_tag(tag_name: str) -> Path:
    archive_dir = ROOT_DIR / "build" / "archives"
    archive_path = archive_dir / f"{tag_name}.xcarchive"

    archive_dir.mkdir(parents=True, exist_ok=True)
    if archive_path.exists():
        shutil.rmtree(archive_path)

    exit_code = run_xcodebuild(
        f"archive-{tag_name}",
        [
            "-project",
            str(PROJECT_PATH),
            "-scheme",
            SCHEME,
            "-configuration",
            "Release",
            "-destination",
            resolve_destination(""),
            "-archivePath",
            str(archive_path),
            "archive",
        ],
        False,
    )
    if exit_code != 0:
        raise SystemExit(exit_code)
    return archive_path


def commit_and_tag(commit_message: str, tag_name: str) -> None:
    subprocess.run(["git", "-C", str(ROOT_DIR), "add", "-A"], check=True)
    diff = subprocess.run(["git", "-C", str(ROOT_DIR), "diff", "--cached", "--quiet"])
    if diff.returncode == 0:
        die("Release workflow produced no changes to commit.")
    subprocess.run(["git", "-C", str(ROOT_DIR), "commit", "-m", commit_message], check=True)
    subprocess.run(["git", "-C", str(ROOT_DIR), "tag", "-a", tag_name, "-m", tag_name], check=True)


def run_release_status(args: argparse.Namespace) -> int:
    project = project_json()
    config_ids = target_config_ids(project)
    marketing_version = current_marketing_version(project, config_ids)
    build_number = current_build_number(project, config_ids)
    prerelease_tag = f"v{normalize_tag_version(marketing_version)}-build.{build_number}"

    print(f"Marketing version: {marketing_version}")
    print(f"Build number: {build_number}")
    print(f"Targets: {' '.join(RELEASE_TARGETS)}")
    print(f"Current prerelease tag shape: {prerelease_tag}")
    return 0


def run_set_version(args: argparse.Namespace) -> int:
    normalize_tag_version(args.version)
    set_synced_settings(marketing_version=args.version)
    print(f"Set marketing version to {args.version}")
    return 0


def run_prerelease(args: argparse.Namespace) -> int:
    require_tool("git")
    require_tool("swift")

    project = project_json()
    config_ids = target_config_ids(project)
    marketing_version = current_marketing_version(project, config_ids)
    current_build_number_value = current_build_number(project, config_ids)
    if not re.fullmatch(r"[0-9]+", current_build_number_value):
        die("Current build number must be numeric.")

    next_build_number = str(int(current_build_number_value) + 1)
    tag_name = f"v{normalize_tag_version(marketing_version)}-build.{next_build_number}"

    ensure_tag_absent(tag_name)
    ensure_clean_worktree()
    run_release_prep()
    set_synced_settings(marketing_version=marketing_version, build_number=next_build_number)
    archive_path = archive_for_tag(tag_name)
    commit_and_tag(f"Prerelease {tag_name}", tag_name)

    print(f"Created prerelease {tag_name}")
    print(f"Archived at {archive_path}")
    return 0


def run_release(args: argparse.Namespace) -> int:
    require_tool("git")
    require_tool("swift")

    project = project_json()
    config_ids = target_config_ids(project)
    release_version = args.version or current_marketing_version(project, config_ids)
    current_build_number_value = current_build_number(project, config_ids)
    if not re.fullmatch(r"[0-9]+", current_build_number_value):
        die("Current build number must be numeric.")

    validate_release_version(release_version)
    next_build_number = str(int(current_build_number_value) + 1)
    tag_name = f"v{release_version}"

    ensure_tag_absent(tag_name)
    ensure_clean_worktree()
    run_release_prep()
    set_synced_settings(marketing_version=release_version, build_number=next_build_number)
    archive_path = archive_for_tag(tag_name)
    commit_and_tag(f"Release {tag_name}", tag_name)

    print(f"Created release {tag_name}")
    print(f"Archived at {archive_path}")
    return 0


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

    release_status_parser = subparsers.add_parser("release-status")
    release_status_parser.set_defaults(func=run_release_status)

    set_version_parser = subparsers.add_parser("set-version")
    set_version_parser.add_argument("version")
    set_version_parser.set_defaults(func=run_set_version)

    prerelease_parser = subparsers.add_parser("prerelease")
    prerelease_parser.set_defaults(func=run_prerelease)

    release_parser = subparsers.add_parser("release")
    release_parser.add_argument("version", nargs="?")
    release_parser.set_defaults(func=run_release)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
