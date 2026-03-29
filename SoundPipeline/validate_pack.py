#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"[validate_pack] ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def validate_group_files(pack_dir: Path, group_name: str, file_list: list[str], label: str) -> int:
    count = 0
    for relative_path in file_list:
        file_path = pack_dir / relative_path
        if not file_path.exists():
            fail(f"Missing {label} sample for group '{group_name}': {relative_path}")
        count += 1
    return count


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python3 validate_pack.py <pack_dir>", file=sys.stderr)
        sys.exit(2)

    pack_dir = Path(sys.argv[1])
    manifest_path = pack_dir / "manifest.json"

    if not manifest_path.exists():
        fail(f"No manifest.json found in {pack_dir}")

    with manifest_path.open("r", encoding="utf-8") as f:
        manifest = json.load(f)

    if manifest.get("manifestVersion") != 2:
        fail("Only manifestVersion 2 packs are supported by this validator")

    for key in ["id", "name", "brand", "switchType", "audio", "groups", "fallbacks", "coverage"]:
        if key not in manifest:
            fail(f"Missing required manifest field: {key}")

    groups = manifest["groups"]
    if not groups:
        fail("Manifest must define at least one sample group")

    total_down = 0
    total_up = 0

    for group_name, payload in groups.items():
        if "down" not in payload or "up" not in payload:
            fail(f"Group '{group_name}' must include both 'down' and 'up' arrays")
        total_down += validate_group_files(pack_dir, group_name, payload["down"], "down")
        total_up += validate_group_files(pack_dir, group_name, payload["up"], "up")

    coverage = manifest["coverage"]
    if coverage.get("groupCount") != len(groups):
        fail("coverage.groupCount does not match manifest groups")
    if coverage.get("totalDownSamples") != total_down:
        fail("coverage.totalDownSamples does not match manifest file count")
    if coverage.get("totalUpSamples") != total_up:
        fail("coverage.totalUpSamples does not match manifest file count")
    if coverage.get("hasKeyUp") != (total_up > 0):
        fail("coverage.hasKeyUp does not match actual up-sample presence")

    print(f"[validate_pack] PASS: {pack_dir.name} ({total_down} down / {total_up} up)")


if __name__ == "__main__":
    main()
