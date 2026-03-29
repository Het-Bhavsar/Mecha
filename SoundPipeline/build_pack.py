import os
import sys
import glob
import json
import numpy as np
import soundfile as sf
from pathlib import Path

from manifest_v2 import build_manifest_v2, write_manifest

try:
    from pydub import AudioSegment
except ImportError:
    print("Missing dependencies. Run: pip install pydub numpy scipy soundfile")
    sys.exit(1)

def pitch_shift(data, sample_rate, shift_amount):
    """
    Very fast naive pitch + speed shift using pure resampling.
    Keyboard clicks are ~100ms so a ±3% speed change is imperceptible
    as a duration change, but adds enough pitch variation.
    """
    from scipy.signal import resample
    # shift_amount e.g. 1.03 for +3% pitch, 0.97 for -3%
    new_length = int(len(data) / shift_amount)
    resampled = resample(data, new_length)
    return resampled

def convert_to_wav(input_path):
    ext = os.path.splitext(input_path)[1].lower()
    if ext in ['.ogg', '.mp3']:
        temp_wav = "/tmp/_clackmac_temp.wav"
        audio = AudioSegment.from_file(input_path)
        audio.export(temp_wav, format="wav")
        return temp_wav
    return input_path

def process_audio(input_file, target_sr=48000, fade_ms=25, peak_dbfs=-3.0):
    wav_path = convert_to_wav(input_file)
    data, sr = sf.read(wav_path)
    
    if wav_path == "/tmp/_clackmac_temp.wav":
        os.remove(wav_path)
        
    # Mono conversion
    if len(data.shape) > 1:
        data = np.mean(data, axis=1)
        
    # Resample
    if sr != target_sr:
        from scipy.signal import resample
        num_samples = int(len(data) * float(target_sr) / sr)
        data = resample(data, num_samples)
        
    # Trim leading/trailing silence below -60 dBFS
    threshold = 10 ** (-60 / 20.0)
    valid_indices = np.where(np.abs(data) > threshold)[0]
    if len(valid_indices) == 0:
        return None
    data = data[valid_indices[0]:valid_indices[-1]+1]
    
    # Cap at 200ms
    max_samples = int(0.200 * target_sr)
    if len(data) > max_samples:
        data = data[:max_samples]
        
    # Fade out last 25ms to prevent clicks
    fade_samples = int((fade_ms / 1000.0) * target_sr)
    if fade_samples > 0 and len(data) > fade_samples:
        fade_curve = np.linspace(1.0, 0.0, fade_samples)
        data[-fade_samples:] *= fade_curve
        
    # Normalize
    current_peak = np.max(np.abs(data))
    if current_peak > 0:
        target_peak = 10 ** (peak_dbfs / 20.0)
        data = data * (target_peak / current_peak)
        
    return data

def build_pack(source_dir, output_dir, pack_name, switch_type):
    os.makedirs(output_dir, exist_ok=True)
    
    # Mapping definitions
    categories = ["alphanumeric", "space", "enter", "backspace", "modifier", "arrow"]
    # Keyword matcher. You can add more specific strings.
    keywords = {
        "space": ["space"],
        "enter": ["enter", "return"],
        "backspace": ["backspace", "delete", "bksp"],
        "modifier": ["shift", "cmd", "ctrl", "alt", "opt", "win", "mod"],
        "fkey": ["f1", "f2", "f3", "f4", "f5", "fkey"],
        "up": ["up", "release"] # if we detect 'up' we class it as a keyUp sound
    }
    
    manifest_urls = { cat: [] for cat in categories }
    manifest_up_urls = {}
    
    files = glob.glob(os.path.join(source_dir, "*.*"))
    audio_files = [f for f in files if f.lower().endswith(('.wav', '.ogg', '.mp3'))]
    
    if not audio_files:
        print(f"No audio files found in {source_dir}. Ensure you provide a folder with separate key noises.")
        return

    # Sort files into categories
    mapped_files = { cat: [] for cat in categories }
    mapped_up_files = { cat: [] for cat in categories }
    
    for f in audio_files:
        fname = os.path.basename(f).lower()
        
        is_up = any(k in fname for k in keywords["up"])
        matched_cat = "alpha" # default
        
        for cat in ["space", "enter", "backspace", "modifier", "fkey"]:
            if any(k in fname for k in keywords[cat]):
                matched_cat = cat
                break
                
        if is_up:
            mapped_up_files[matched_cat].append(f)
        else:
            mapped_files[matched_cat].append(f)
            
    # Process and Expand to 4 variants
    total_files_written = 0
    
    for cat in categories:
        sources = mapped_files[cat]
        
        # If a category is completely empty, fallback exactly to alpha
        if not sources and cat != "alpha":
            sources = mapped_files["alpha"]
            
        if not sources:
            continue
            
        processed_data_list = []
        for src in sources:
            data = process_audio(src)
            if data is not None:
                processed_data_list.append(data)
                
        # Generate 4 variations
        final_variations = []
        shifts = [1.0, 1.015, 0.985, 1.03, 0.97]
        
        while len(final_variations) < 4:
            base_data = processed_data_list[len(final_variations) % len(processed_data_list)]
            shift_idx = len(final_variations) // len(processed_data_list)
            shift_amt = shifts[shift_idx % len(shifts)]
            
            if shift_amt != 1.0:
                shifted = pitch_shift(base_data, 48000, shift_amt)
            else:
                shifted = base_data
            final_variations.append(shifted)
            
        # Save variation WAVs
        for i, wav_data in enumerate(final_variations[:4]):
            out_name = f"{cat}_{i+1}.wav"
            out_path = os.path.join(output_dir, out_name)
            sf.write(out_path, wav_data, 48000, subtype='PCM_24')
            manifest_urls[cat].append(out_name)
            total_files_written += 1
            
        # Process Up sound
        up_sources = mapped_up_files[cat]
        if not up_sources and mapped_up_files["alpha"]:
            up_sources = mapped_up_files["alpha"]
            
        if up_sources:
            data = process_audio(up_sources[0])
            if data is not None:
                out_name = f"{cat}_up.wav"
                out_path = os.path.join(output_dir, out_name)
                sf.write(out_path, data, 48000, subtype='PCM_24')
                manifest_up_urls[cat] = out_name
                total_files_written += 1

    groups = {}
    for cat in categories:
        groups[cat] = {
            "down": manifest_urls[cat],
            "up": [manifest_up_urls[cat]] if cat in manifest_up_urls else []
        }

    manifest = build_manifest_v2(
        pack_name=pack_name,
        brand="Mecha Studio",
        switch_type=switch_type,
        groups=groups,
        description=f"Generated grouped pack for {pack_name}",
        compatibility_mode="generated-v2",
        compatibility_source="SoundPipeline/build_pack.py",
        compatibility_notes="Generated from grouped source assets through the canonical v2 builder.",
        tier="premium"
    )

    write_manifest(os.path.join(output_dir, "manifest.json"), manifest)
        
    print(f"Pack '{pack_name}' built successfully at {output_dir}")
    print(f"Total files written: {total_files_written}")
    
    # Check Pack Size
    pack_size_mb = sum(os.path.getsize(os.path.join(output_dir, f)) for f in os.listdir(output_dir)) / (1024*1024)
    print(f"Total Pack Size: {pack_size_mb:.2f} MB")

if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: python3 build_pack.py <source_raw_dir> <output_dir> <pack_name> <switch_type>")
        sys.exit(1)
        
    build_pack(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
