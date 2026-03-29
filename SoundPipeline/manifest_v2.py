import json
import os
import re
from pathlib import Path

DEFAULT_FALLBACKS = {
    "space": "alphanumeric",
    "enter": "alphanumeric",
    "backspace": "alphanumeric",
    "modifier": "alphanumeric",
    "arrow": "alphanumeric",
    "tab": "modifier",
    "escape": "modifier",
}

DEFAULT_AUDIO = {
    "sampleRate": 48000,
    "bitDepth": 24,
    "channels": 1,
}

DEFAULT_RENDERING = {
    "defaultGainDb": 0.0,
    "stereoWidth": 0.12,
    "pitchJitterCents": 3.0,
}


def slugify_pack_id(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")
    return slug or "sound_pack"


def humanize_pack_name(raw_name: str) -> str:
    tokens = re.split(r"[-_]+", raw_name.strip())
    return " ".join(token.upper() if token.isupper() else token.capitalize() for token in tokens if token)


def build_manifest_v2(
    *,
    pack_name: str,
    brand: str,
    switch_type: str,
    groups: dict,
    description: str | None = None,
    audio: dict | None = None,
    rendering: dict | None = None,
    fallbacks: dict | None = None,
    compatibility_mode: str | None = None,
    compatibility_source: str | None = None,
    compatibility_notes: str | None = None,
    tier: str = "legacy",
) -> dict:
    total_down = sum(len(group.get("down", [])) for group in groups.values())
    total_up = sum(len(group.get("up", [])) for group in groups.values())

    manifest = {
        "manifestVersion": 2,
        "id": slugify_pack_id(pack_name),
        "name": pack_name,
        "brand": brand,
        "switchType": switch_type,
        "audio": audio or DEFAULT_AUDIO,
        "groups": groups,
        "fallbacks": fallbacks or DEFAULT_FALLBACKS,
        "coverage": {
            "hasKeyUp": total_up > 0,
            "groupCount": len(groups),
            "totalDownSamples": total_down,
            "totalUpSamples": total_up,
            "tier": tier,
        },
    }

    if description:
        manifest["description"] = description

    if rendering:
        manifest["rendering"] = rendering
    else:
        manifest["rendering"] = DEFAULT_RENDERING

    if compatibility_mode:
        manifest["compatibility"] = {
            "mode": compatibility_mode,
            "source": compatibility_source,
            "notes": compatibility_notes,
        }

    return manifest


def build_flat_legacy_manifest(
    *,
    pack_name: str,
    down_files: list[str],
    up_files: list[str] | None = None,
    brand: str = "Upstream",
    switch_type: str = "Mechanical",
    source: str = "flat-import",
    description: str | None = None,
) -> dict:
    groups = {
        "alphanumeric": {
            "down": down_files,
            "up": up_files or [],
        }
    }

    return build_manifest_v2(
        pack_name=pack_name,
        brand=brand,
        switch_type=switch_type,
        groups=groups,
        description=description,
        compatibility_mode="legacy-flat",
        compatibility_source=source,
        compatibility_notes="Imported from a flat upstream pack and routed through fallback groups.",
        tier="legacy",
    )


def write_manifest(manifest_path: str | os.PathLike[str], manifest: dict) -> None:
    path = Path(manifest_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
