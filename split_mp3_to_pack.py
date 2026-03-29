#!/usr/bin/env python3
"""
Split a mechanical keyboard MP3 recording into individual keypress sounds,
then generate properly-formatted sound packs for Mecha.

Uses only pydub + numpy (no scipy dependency).
"""

import os
import json
import struct
import wave
import numpy as np
from pydub import AudioSegment

from SoundPipeline.manifest_v2 import build_manifest_v2, write_manifest

# ─── Configuration ───────────────────────────────────────────────
INPUT_MP3 = "freesound_community-mechanical-keyboard-23537.mp3"
OUTPUT_BASE = "Mecha/Resources/SoundPacks"
TARGET_SR = 48000
FADE_MS = 25
PEAK_DBFS = -3.0

KEY_TYPES = ["alphanumeric", "space", "enter", "backspace", "modifier", "arrow"]
VARIATIONS_PER_TYPE = 3


def load_mp3_as_numpy(mp3_path):
    """Convert MP3 to mono numpy array at target sample rate using pydub."""
    audio = AudioSegment.from_mp3(mp3_path)
    audio = audio.set_channels(1).set_frame_rate(TARGET_SR).set_sample_width(2)
    samples = np.array(audio.get_array_of_samples(), dtype=np.float64)
    samples = samples / 32768.0  # Normalize to -1..1
    return samples


def detect_clicks(data, sr, min_gap_ms=60, threshold_db=-30):
    """Detect individual keypress transients via amplitude envelope."""
    threshold = 10 ** (threshold_db / 20.0)
    
    window_size = int(sr * 0.005)  # 5ms window
    num_windows = len(data) // window_size
    envelope = np.zeros(len(data))
    
    for i in range(num_windows):
        start = i * window_size
        end = start + window_size
        envelope[start:end] = np.max(np.abs(data[start:end]))
    
    above = envelope > threshold
    min_gap_samples = int(sr * min_gap_ms / 1000.0)
    max_click_samples = int(sr * 0.200)
    
    clicks = []
    in_click = False
    click_start = 0
    
    for i in range(len(above)):
        if above[i] and not in_click:
            in_click = True
            click_start = max(0, i - int(sr * 0.002))
        elif not above[i] and in_click:
            gap_end = min(i + min_gap_samples, len(above))
            if not np.any(above[i:gap_end]):
                click_end = min(i + int(sr * 0.030), len(data))
                clicks.append((click_start, click_end))
                in_click = False
    
    if in_click:
        clicks.append((click_start, min(click_start + max_click_samples, len(data))))
    
    clicks = [(s, min(e, s + max_click_samples)) for s, e in clicks]
    min_samples = int(sr * 0.010)
    clicks = [(s, e) for s, e in clicks if (e - s) >= min_samples]
    
    return clicks


def naive_resample(data, new_length):
    """Simple linear interpolation resampling (no scipy needed)."""
    if new_length == len(data):
        return data
    old_indices = np.linspace(0, len(data) - 1, new_length)
    old_int = old_indices.astype(int)
    old_frac = old_indices - old_int
    # Clamp to avoid out-of-bounds
    old_int_next = np.minimum(old_int + 1, len(data) - 1)
    return data[old_int] * (1.0 - old_frac) + data[old_int_next] * old_frac


def process_segment(data, sr=TARGET_SR):
    """Process a single click segment: trim, fade, normalize."""
    threshold = 10 ** (-60 / 20.0)
    valid = np.where(np.abs(data) > threshold)[0]
    if len(valid) == 0:
        return None
    data = data[valid[0]:valid[-1]+1]
    
    max_samples = int(0.200 * sr)
    if len(data) > max_samples:
        data = data[:max_samples]
    
    # Fade out
    fade_samples = int((FADE_MS / 1000.0) * sr)
    if fade_samples > 0 and len(data) > fade_samples:
        data = data.copy()
        data[-fade_samples:] *= np.linspace(1.0, 0.0, fade_samples)
    
    # Fade in
    fade_in = int(0.002 * sr)
    if fade_in > 0 and len(data) > fade_in:
        data[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
    
    # Normalize
    current_peak = np.max(np.abs(data))
    if current_peak > 0:
        target_peak = 10 ** (PEAK_DBFS / 20.0)
        data = data * (target_peak / current_peak)
    
    return data


def pitch_shift(data, shift_amount):
    """Naive pitch shift via linear-interpolation resampling."""
    new_length = int(len(data) / shift_amount)
    if new_length < 10:
        return data
    return naive_resample(data, new_length)


def write_wav_24bit(filepath, data, sr):
    """Write 24-bit PCM WAV file."""
    # Scale to 24-bit range
    samples_24 = np.clip(data * (2**23 - 1), -(2**23), 2**23 - 1).astype(np.int32)
    
    with wave.open(filepath, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(3)  # 24-bit = 3 bytes
        wav.setframerate(sr)
        
        # Pack each sample as 3 bytes (little-endian)
        raw_bytes = bytearray()
        for sample in samples_24:
            b = struct.pack('<i', sample)
            raw_bytes.extend(b[:3])  # Take lower 3 bytes
        
        wav.writeframes(bytes(raw_bytes))


def build_pack(segments, pack_dir, pack_name, pitch_base_offset=0.0):
    """Build a complete sound pack from extracted segments."""
    os.makedirs(pack_dir, exist_ok=True)
    
    num_segments = len(segments)
    if num_segments == 0:
        print(f"  WARNING: No segments for {pack_name}, skipping")
        return
    
    print(f"  Building {pack_name} from {num_segments} raw segments...")
    
    pitch_shifts = [1.0, 1.02, 0.98, 1.035, 0.965]
    manifest_key_mapping = {}
    manifest_key_up_mapping = {}
    
    for type_idx, key_type in enumerate(KEY_TYPES):
        files_for_type = []
        
        for var_idx in range(1, VARIATIONS_PER_TYPE + 1):
            seg_idx = (type_idx * VARIATIONS_PER_TYPE + var_idx - 1) % num_segments
            segment = segments[seg_idx].copy()
            
            shift_idx = var_idx % len(pitch_shifts)
            shift_amount = pitch_shifts[shift_idx] + pitch_base_offset
            
            if abs(shift_amount - 1.0) > 0.001:
                segment = pitch_shift(segment, shift_amount)
            
            processed = process_segment(segment)
            if processed is None:
                continue
            
            filename = f"{key_type}_{var_idx}.wav"
            filepath = os.path.join(pack_dir, filename)
            write_wav_24bit(filepath, processed, TARGET_SR)
            files_for_type.append(filename)
        
        if files_for_type:
            manifest_key_mapping[key_type] = files_for_type
        
        # Key-up sound (shorter, quieter)
        seg_idx = (type_idx + 3) % num_segments
        segment = segments[seg_idx].copy()
        max_up_samples = int(0.060 * TARGET_SR)
        if len(segment) > max_up_samples:
            segment = segment[:max_up_samples]
        segment *= 0.6
        
        processed = process_segment(segment)
        if processed is not None:
            up_filename = f"{key_type}-up_1.wav"
            up_filepath = os.path.join(pack_dir, up_filename)
            write_wav_24bit(up_filepath, processed, TARGET_SR)
            manifest_key_up_mapping[key_type] = up_filename
    
    # Generic keyup.wav
    seg_idx = num_segments // 2
    segment = segments[seg_idx].copy()
    max_up_samples = int(0.050 * TARGET_SR)
    if len(segment) > max_up_samples:
        segment = segment[:max_up_samples]
    segment *= 0.5
    processed = process_segment(segment)
    if processed is not None:
        write_wav_24bit(os.path.join(pack_dir, "keyup.wav"), processed, TARGET_SR)
    
    groups = {}
    for key_type, down_files in manifest_key_mapping.items():
        groups[key_type] = {
            "down": down_files,
            "up": [manifest_key_up_mapping[key_type]] if key_type in manifest_key_up_mapping else []
        }

    manifest = build_manifest_v2(
        pack_name=pack_name,
        brand="Freesound Community",
        switch_type="Mechanical",
        groups=groups,
        description=f"Generated from sliced MP3 source for {pack_name}",
        compatibility_mode="generated-from-split",
        compatibility_source="split_mp3_to_pack.py",
        compatibility_notes="Prototype pack generated from a sliced audio source through the canonical v2 manifest helper.",
        tier="legacy"
    )

    write_manifest(os.path.join(pack_dir, "manifest.json"), manifest)
    
    wav_files = [f for f in os.listdir(pack_dir) if f.endswith('.wav')]
    total_size = sum(os.path.getsize(os.path.join(pack_dir, f)) for f in os.listdir(pack_dir))
    print(f"  ✓ {pack_name}: {len(wav_files)} wav files, {total_size/1024:.1f} KB total")


def main():
    if not os.path.exists(INPUT_MP3):
        print(f"ERROR: {INPUT_MP3} not found!")
        return
    
    print(f"Loading {INPUT_MP3}...")
    audio_data = load_mp3_as_numpy(INPUT_MP3)
    print(f"  Loaded {len(audio_data)} samples ({len(audio_data)/TARGET_SR:.1f}s) at {TARGET_SR}Hz")
    
    print("Detecting keypress transients...")
    clicks = detect_clicks(audio_data, TARGET_SR)
    print(f"  Found {len(clicks)} click segments")
    
    if len(clicks) < 6:
        print("  Lowering threshold...")
        clicks = detect_clicks(audio_data, TARGET_SR, threshold_db=-35, min_gap_ms=40)
        print(f"  Found {len(clicks)} click segments (retry)")
    
    if len(clicks) < 3:
        print("  Using fixed-interval slicing fallback...")
        step = int(TARGET_SR * 0.150)
        click_len = int(TARGET_SR * 0.120)
        clicks = []
        for i in range(0, len(audio_data) - click_len, step):
            segment = audio_data[i:i+click_len]
            if np.max(np.abs(segment)) > 0.01:
                clicks.append((i, i+click_len))
        print(f"  Generated {len(clicks)} segments via fixed slicing")
    
    segments = [audio_data[s:e].copy() for s, e in clicks]
    print(f"\nBuilding sound packs ({len(segments)} segments)...\n")
    
    packs = [
        ("Cherry MX Blue", 0.0),
        ("Cherry MX Red", -0.02),
        ("Typewriter", 0.04),
        ("Silent", -0.04),
    ]
    
    for pack_name, pitch_offset in packs:
        pack_dir = os.path.join(OUTPUT_BASE, pack_name)
        if os.path.exists(pack_dir):
            for f in os.listdir(pack_dir):
                os.remove(os.path.join(pack_dir, f))
        build_pack(segments, pack_dir, pack_name, pitch_base_offset=pitch_offset)
    

    
    print("\n✅ All sound packs generated successfully!")


if __name__ == "__main__":
    main()
