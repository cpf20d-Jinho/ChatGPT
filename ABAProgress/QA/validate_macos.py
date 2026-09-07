"""Run on a Mac with Xcode and iOS Simulator runtimes; no signing required.

This checks compilation, the existing standalone scenario checks, and app launch.
Screenshots require visual review. It does not replace the interactive AGENTS.md QA.
"""
import json
from pathlib import Path
import platform
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "ABAProgress/XcodeProject/ABAProgress.xcodeproj"
OUT = ROOT / "validation-results"
OUT.mkdir(exist_ok=True)
SUMMARY = {"status": "running", "devices": [], "interactiveQA": "NOT_RUN"}


def run(args, log=None, timeout=120):
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=timeout)
    if log:
        (OUT / log).write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {args}\n{result.stdout[-12000:]}")
    return result.stdout


def main():
    if platform.system() != "Darwin":
        raise RuntimeError("Requires macOS with Xcode; Windows cannot run this validation.")
    SUMMARY["commit"] = run(["git", "rev-parse", "HEAD"]).strip()
    SUMMARY["xcode"] = run(["xcodebuild", "-version"], "xcode.txt").strip()
    run(["xcrun", "swift", str(ROOT / "ABAProgress/QA/scenario_tests.swift")],
        "scenario-tests.txt", timeout=300)
    SUMMARY["standaloneScenarios"] = "PASS (separate simulation, not production model tests)"
    inventory = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "-j"], "devices.json"))
    candidates = []
    for runtime, devices in inventory["devices"].items():
        if "SimRuntime.iOS-" in runtime:
            candidates.extend(d for d in devices if d.get("isAvailable", False))
    phones = [d for d in candidates if d["name"].startswith("iPhone")]
    pads = [d for d in candidates if d["name"].startswith("iPad")]
    if not phones or not pads:
        raise RuntimeError("Install iOS runtimes with at least one iPhone and one iPad simulator.")
    # Prefer known compact/standard and 11-/13-inch models; record actual choices.
    compact = next((d for d in phones if "mini" in d["name"] or "SE" in d["name"]), phones[0])
    standard = next((d for d in phones if d["udid"] != compact["udid"] and
                     "Pro" not in d["name"] and "Plus" not in d["name"]), phones[-1])
    pad11 = next((d for d in pads if "11-inch" in d["name"]), pads[0])
    large = next((d for d in pads if "13-inch" in d["name"] or "12.9-inch" in d["name"]), pads[-1])
    selected = {d["udid"]: d for d in (compact, standard, pad11, large)}
    SUMMARY["deviceSelection"] = "Prefers mini/SE, standard iPhone, 11-inch and large iPad; falls back to installed devices. Full size coverage requires manual review."
    derived = OUT / "DerivedData"
    run(["xcodebuild", "-project", str(PROJECT), "-scheme", "ABAProgress",
         "-configuration", "Debug", "-sdk", "iphonesimulator",
         "-destination", f"platform=iOS Simulator,id={compact['udid']}",
         "-derivedDataPath", str(derived), "CODE_SIGNING_ALLOWED=NO", "build"],
        "build.txt", timeout=1200)
    SUMMARY["build"] = "PASS"
    app = derived / "Build/Products/Debug-iphonesimulator/ABAProgress.app"
    bundle = run(["/usr/libexec/PlistBuddy", "-c", "Print :CFBundleIdentifier", str(app / "Info.plist")]).strip()
    for index, device in enumerate(selected.values(), 1):
        udid = device["udid"]
        prefix = f"{index}-{udid}"
        item = {"name": device["name"], "udid": udid, "status": "running"}
        SUMMARY["devices"].append(item)
        booted_here = device["state"] != "Booted"
        try:
            if booted_here:
                run(["xcrun", "simctl", "boot", udid])
            run(["xcrun", "simctl", "bootstatus", udid, "-b"], prefix + "-boot.txt", timeout=300)
            run(["xcrun", "simctl", "install", udid, str(app)])
            launch = run(["xcrun", "simctl", "launch", "--terminate-running-process", udid, bundle], prefix + "-launch.txt")
            pid = launch.strip().rsplit(":", 1)[-1].strip()
            if not pid.isdigit():
                raise RuntimeError(f"No process ID returned: {launch}")
            time.sleep(8)
            processes = run(["xcrun", "simctl", "spawn", udid, "launchctl", "list"], prefix + "-processes.txt")
            if not any(line.split() and line.split()[0] == pid for line in processes.splitlines()):
                raise RuntimeError(f"App process {pid} exited after launch on {device['name']}")
            run(["xcrun", "simctl", "io", udid, "screenshot", str(OUT / (prefix + ".png"))])
            run(["xcrun", "simctl", "ui", udid, "appearance", "dark"])
            time.sleep(2)
            run(["xcrun", "simctl", "io", udid, "screenshot", str(OUT / (prefix + "-dark.png"))])
            run(["xcrun", "simctl", "ui", udid, "appearance", "light"])
            run(["xcrun", "simctl", "ui", udid, "content_size", "accessibility-extra-extra-extra-large"])
            time.sleep(2)
            run(["xcrun", "simctl", "io", udid, "screenshot", str(OUT / (prefix + "-AX5.png"))])
            run(["xcrun", "simctl", "ui", udid, "content_size", "large"])
            item["status"] = "PASS: process survived 8 seconds; screenshot captured"
        finally:
            try:
                run(["xcrun", "simctl", "spawn", udid, "log", "show", "--last", "2m",
                     "--style", "compact", "--predicate", 'process == "ABAProgress"'], prefix + "-runtime.txt")
            except Exception as error:
                item["logCaptureError"] = str(error)
            if booted_here:
                run(["xcrun", "simctl", "shutdown", udid])
    for device in (compact, pad11):
        run(["xcodebuild", "-project", str(PROJECT), "-scheme", "ABAProgress",
             "-destination", f"platform=iOS Simulator,id={device['udid']}",
             "-derivedDataPath", str(derived), "-resultBundlePath", str(OUT / (device['udid'] + ".xcresult")),
             "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO", "test"],
            device['udid'] + "-uitests.txt", timeout=1200)
    SUMMARY["interactiveQA"] = "PASS: registration, relaunch persistence and search on iPhone/iPad. Full therapy flows NOT_RUN."
    SUMMARY["status"] = "PASS: build, standalone scenarios, launch and registration/search UI checks"


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        SUMMARY["status"] = "FAIL"
        SUMMARY["error"] = str(error)
        raise
    finally:
        (OUT / "summary.json").write_text(json.dumps(SUMMARY, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(SUMMARY, ensure_ascii=False, indent=2))
