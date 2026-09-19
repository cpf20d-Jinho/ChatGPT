#!/usr/bin/env python3
"""Validate source parity and create a deterministic Swift Playgrounds archive."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import tempfile
import zipfile
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_ROOT = PROJECT_ROOT / "ABAProgress.swiftpm"
XCODE_ROOT = PROJECT_ROOT / "XcodeProject" / "ABAProgress"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate() -> str:
    required = [
        PACKAGE_ROOT / "Package.swift",
        PACKAGE_ROOT / "README_iPad.txt",
        PACKAGE_ROOT / "Sources" / "AppModule" / "ABAProgressApp.swift",
        PACKAGE_ROOT / "Sources" / "AppModule" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png",
        PACKAGE_ROOT / "Sources" / "AppModule" / "Resources" / "PrivacyInfo.xcprivacy",
        PACKAGE_ROOT / "Sources" / "AppModule" / "Resources" / "ReportTemplate.html",
    ]
    missing = [str(path.relative_to(PROJECT_ROOT)) for path in required if not path.is_file()]
    if missing:
        raise SystemExit("Missing Swift Playgrounds files: " + ", ".join(missing))

    package_text = (PACKAGE_ROOT / "Package.swift").read_text(encoding="utf-8")
    version = (PROJECT_ROOT / "VERSION.txt").read_text(encoding="utf-8").strip()
    declared = re.search(r'displayVersion:\s*"([^"]+)"', package_text)
    if declared is None or declared.group(1) != version:
        raise SystemExit(f"Package displayVersion does not match VERSION.txt ({version})")
    if '.iOS("17.0")' not in package_text or ".phone" not in package_text or ".pad" not in package_text:
        raise SystemExit("Package must remain an iOS/iPadOS 17 Universal application")

    source_root = PACKAGE_ROOT / "Sources" / "AppModule"
    mismatches: list[str] = []
    for package_file in sorted(path for path in source_root.rglob("*") if path.is_file()):
        relative = package_file.relative_to(source_root)
        xcode_file = XCODE_ROOT / relative
        if not xcode_file.is_file() or sha256(package_file) != sha256(xcode_file):
            mismatches.append(relative.as_posix())
    if mismatches:
        raise SystemExit("Xcode/Swift Playgrounds source mismatch: " + ", ".join(mismatches))
    return version


def archive(output_dir: Path, version: str) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    archive_path = output_dir / f"ABAProgress-v{version}-Swift-Playgrounds.zip"
    checksum_path = output_dir / f"ABAProgress-v{version}-Swift-Playgrounds.sha256"

    with tempfile.TemporaryDirectory() as temporary:
        staged = Path(temporary) / "ABAProgress.swiftpm"
        shutil.copytree(PACKAGE_ROOT, staged, ignore=shutil.ignore_patterns(".build", ".swiftpm", ".DS_Store"))
        with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
            for file in sorted(path for path in staged.rglob("*") if path.is_file()):
                entry = file.relative_to(staged.parent).as_posix()
                info = zipfile.ZipInfo(entry, date_time=(2026, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                bundle.writestr(info, file.read_bytes())

    checksum_path.write_text(f"{sha256(archive_path)}  {archive_path.name}\n", encoding="utf-8")
    return archive_path, checksum_path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    version = validate()
    archive_path, checksum_path = archive(args.output, version)
    print(json.dumps({
        "version": version,
        "archive": str(archive_path),
        "sha256": checksum_path.read_text(encoding="utf-8").split()[0],
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
