#!/usr/bin/env python3
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

from key_inference import build_grouped_sample_index
from manifest_v2 import build_manifest_v2, humanize_pack_name, write_manifest


ROOT_DIR = Path(__file__).resolve().parent.parent
DEST_ROOT = ROOT_DIR / "Mecha" / "Resources" / "SoundPacks"


def import_zip(zip_path: Path, dest_root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="mecha-soundpacks-") as tmp_dir:
        extract_root = Path(tmp_dir)

        with zipfile.ZipFile(zip_path) as archive:
            archive.extractall(extract_root)

        source_root = extract_root / "soundpacks"
        if not source_root.exists():
            raise RuntimeError("Expected top-level 'soundpacks/' directory in zip")

        for pack_dir in sorted(path for path in source_root.iterdir() if path.is_dir()):
            wav_files = sorted(
                path for path in pack_dir.iterdir()
                if path.is_file() and path.suffix.lower() == ".wav" and not path.name.startswith("._")
            )
            if not wav_files:
                continue

            pack_name = humanize_pack_name(pack_dir.name)
            target_dir = dest_root / pack_name

            if target_dir.exists():
                shutil.rmtree(target_dir)
            source_by_name = {wav_path.name: wav_path for wav_path in wav_files}
            grouped_sources = build_grouped_sample_index(list(source_by_name.keys()))

            manifest_groups: dict[str, dict[str, list[str]]] = {}
            for group_name, payload in grouped_sources.items():
                manifest_groups[group_name] = {"down": [], "up": []}
                for direction in ("down", "up"):
                    for wav_name in payload[direction]:
                        source_path = source_by_name[wav_name]
                        target_path = target_dir / direction / group_name / wav_name
                        target_path.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(source_path, target_path)
                        manifest_groups[group_name][direction].append(str(target_path.relative_to(target_dir)))

            manifest = build_manifest_v2(
                pack_name=pack_name,
                brand="Upstream",
                switch_type="Mechanical",
                groups=manifest_groups,
                description=f"Imported upstream per-key pack from {zip_path.name} and grouped into keyboard zones.",
                compatibility_mode="legacy-mapped",
                compatibility_source=zip_path.name,
                compatibility_notes="Imported from upstream per-key WAVs and heuristically grouped into keyboard zones.",
                tier="mapped",
            )
            write_manifest(target_dir / "manifest.json", manifest)
            print(f"[import_soundpacks_zip] Imported {pack_name} with {len(wav_files)} samples across {len(manifest_groups)} groups")


def main() -> None:
    if len(sys.argv) not in {2, 3}:
        print("Usage: python3 import_soundpacks_zip.py <soundpacks.zip> [destination_root]", file=sys.stderr)
        sys.exit(2)

    zip_path = Path(sys.argv[1]).expanduser().resolve()
    dest_root = Path(sys.argv[2]).expanduser().resolve() if len(sys.argv) == 3 else DEST_ROOT
    import_zip(zip_path, dest_root)


if __name__ == "__main__":
    main()
