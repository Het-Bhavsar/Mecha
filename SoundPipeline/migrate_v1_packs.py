#!/usr/bin/env python3
import json
import sys
from pathlib import Path

from manifest_v2 import build_manifest_v2, write_manifest


def migrate_pack(pack_dir: Path) -> bool:
    manifest_path = pack_dir / "manifest.json"
    if not manifest_path.exists():
        return False

    with manifest_path.open("r", encoding="utf-8") as f:
        manifest = json.load(f)

    if manifest.get("manifestVersion") == 2:
        return False

    if "keyMapping" not in manifest:
        return False

    key_mapping = manifest.get("keyMapping", {})
    key_up_mapping = manifest.get("keyUpMapping", {})
    groups = {}
    for key_type, down_files in key_mapping.items():
        groups[key_type] = {
            "down": down_files,
            "up": [key_up_mapping[key_type]] if key_type in key_up_mapping else []
        }

    v2_manifest = build_manifest_v2(
        pack_name=manifest.get("name", pack_dir.name),
        brand=manifest.get("brand", "Community"),
        switch_type=manifest.get("switchType", "Mechanical"),
        groups=groups,
        description=f"Legacy bundled pack migrated from manifest v1 for {manifest.get('name', pack_dir.name)}",
        compatibility_mode="legacy-v1",
        compatibility_source="bundled-v1",
        compatibility_notes="Auto-migrated from the original Mecha manifest v1 schema.",
        tier="legacy"
    )
    write_manifest(manifest_path, v2_manifest)
    return True


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python3 migrate_v1_packs.py <soundpacks_root>", file=sys.stderr)
        sys.exit(2)

    root = Path(sys.argv[1]).expanduser().resolve()
    migrated = 0
    for pack_dir in sorted(path for path in root.iterdir() if path.is_dir()):
        if migrate_pack(pack_dir):
            migrated += 1
            print(f"[migrate_v1_packs] Migrated {pack_dir.name}")

    print(f"[migrate_v1_packs] Complete. Migrated {migrated} pack(s).")


if __name__ == "__main__":
    main()
