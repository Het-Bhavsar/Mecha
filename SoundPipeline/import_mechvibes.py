import json
import os
import shutil
from pathlib import Path
from pydub import AudioSegment

from manifest_v2 import build_manifest_v2, write_manifest

ROOT_DIR = Path(__file__).resolve().parent.parent
RAW_ROOT = ROOT_DIR / "Mecha" / "raw_sources" / "open_source" / "mechvibes" / "src" / "audio"
DEST_ROOT = ROOT_DIR / "Mecha" / "Resources" / "SoundPacks"

PACKS = {
    "cherrymx-blue-abs": "Cherry MX Blue",
    "cherrymx-red-abs": "Cherry MX Red",
    "cherrymx-brown-abs": "Cherry MX Brown",
    "nk-cream": "NovelKeys Cream",
    "holy-pandas": "Holy Pandas"
}

KEY_MAPS = {
    "space": ["57"],
    "enter": ["28", "271"],
    "backspace": ["14"],
    "modifier": ["29", "42", "54", "56", "91", "92", "340", "341", "342", "343", "344", "345", "346"],
    "arrow": ["57416", "57419", "57421", "57424"],
    "alphanumeric": ["16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "30", "31", "32", "33", "34", "35", "36", "37", "38", "44", "45", "46", "47", "48", "49", "50"]
}

LOOSE_MAPS = {
    "space": ["space", "SPACE", "SPACEBAR"],
    "enter": ["enter", "ENTER", "return"],
    "backspace": ["backspace", "BACKSPACE", "delete", "bksp"],
    "modifier": ["shift", "ctrl", "alt", "cmd", "opt", "caps"],
    "arrow": ["up", "down", "left", "right"],
    "alphanumeric": ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "GENERIC"]
}

def export_packs():
    if os.path.exists(DEST_ROOT):
        shutil.rmtree(DEST_ROOT)
    os.makedirs(DEST_ROOT, exist_ok=True)
    
    for src_name, dest_name in PACKS.items():
        src_path = RAW_ROOT / src_name
        dest_path = DEST_ROOT / dest_name
        config_file, audio_sprite = src_path / "config.json", src_path / "sound.ogg"
        if not src_path.exists():
            continue
        print(f"[*] Processing {dest_name}...")
        os.makedirs(dest_path, exist_ok=True)
        groups = {}

        if audio_sprite.exists() and config_file.exists():
            print(f"  [Sprite] Extracting from sound.ogg...")
            with open(config_file, "r") as f: defines = json.load(f).get("defines", {})
            audio = AudioSegment.from_ogg(audio_sprite)
            for archetype, keys in KEY_MAPS.items():
                ls, count = [], 0
                for k_id in keys:
                    if k_id in defines:
                        t = defines[k_id]
                        clip = audio[t[0]:t[0]+t[1]].normalize().fade_out(20)
                        f_name = f"{archetype}_{count}.wav"
                        clip.export(dest_path / f_name, format="wav")
                        ls.append(f_name); count += 1
                        if count >= 3: break
                if ls:
                    groups[archetype] = {"down": ls, "up": []}
        else:
            print(f"  [Loose] Mapping separate files...")
            p_path = src_path / "press" if (src_path / "press").is_dir() else src_path
            r_path = src_path / "release" if (src_path / "release").is_dir() else None
            
            p_files = [p_path / f for f in os.listdir(p_path) if f.lower().endswith(('.wav', '.mp3', '.ogg'))]
            for arch, ms in LOOSE_MAPS.items():
                ls, count = [], 0
                for f in p_files:
                    if any(m.upper() in os.path.basename(f).upper() for m in ms):
                        clip = AudioSegment.from_file(f).normalize().fade_out(15)
                        f_name = f"{arch}_{count}.wav"
                        clip.export(dest_path / f_name, format="wav")
                        ls.append(f_name); count += 1
                        if count >= 3: break
                if ls:
                    groups[arch] = {"down": ls, "up": []}
                
            if r_path:
                print(f"  [Loose] Adding key-up sounds...")
                r_files = [r_path / f for f in os.listdir(r_path) if f.lower().endswith(('.wav', '.mp3', '.ogg'))]
                for arch, ms in LOOSE_MAPS.items():
                    for f in r_files:
                        if any(m.upper() in os.path.basename(f).upper() for m in ms):
                            clip = AudioSegment.from_file(f).normalize().fade_out(15)
                            f_name = f"{arch}_up.wav"
                            clip.export(dest_path / f_name, format="wav")
                            groups.setdefault(arch, {"down": [], "up": []})
                            groups[arch]["up"] = [f_name]
                            break
        manifest = build_manifest_v2(
            pack_name=dest_name,
            brand="Community",
            switch_type="Mechanical",
            groups=groups,
            description=f"Imported from mechvibes upstream source '{src_name}'",
            compatibility_mode="legacy-mechvibes",
            compatibility_source="open_source/mechvibes",
            compatibility_notes="Imported from mechvibes source assets through the canonical v2 importer.",
            tier="legacy"
        )
        write_manifest(dest_path / "manifest.json", manifest)
    print("[*] All packs exported successfully!")

if __name__ == "__main__": export_packs()
