import os
import wave
import struct
import math

PACKS = ["Cherry MX Blue", "Cherry MX Red", "Typewriter", "Silent"]
TYPES = ["alphanumeric", "space", "enter", "backspace", "modifier", "arrow"]

def generate_beep(filename, freq=440.0, duration=0.1, sample_rate=44100):
    num_samples = int(duration * sample_rate)
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            # very simple decay envelope
            envelope = math.exp(-i / (sample_rate * duration))
            value = int(32767.0 * math.sin(2.0 * math.pi * freq * i / sample_rate) * envelope)
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)

base_dir = "Mecha/Resources/SoundPacks"
os.makedirs(base_dir, exist_ok=True)

for pack in PACKS:
    pack_dir = os.path.join(base_dir, pack)
    os.makedirs(pack_dir, exist_ok=True)
    
    # Write manifest
    with open(os.path.join(pack_dir, "manifest.json"), "w") as f:
        f.write(f'{{"name": "{pack}", "author": "Dummy", "description": "Mock sound pack", "switchType": "linear"}}')
    
    # Generate 3 variations per type + 1 keyup
    for key_type in TYPES:
        for i in range(1, 4):
            # Slight pitch variation so we hear random playback working
            base_pitch = 400 + (TYPES.index(key_type) * 100)
            pitch = base_pitch + (i * 20)
            generate_beep(os.path.join(pack_dir, f"{key_type}_{i}.wav"), freq=pitch)
            
        # Keyup variation
        generate_beep(os.path.join(pack_dir, f"{key_type}-up_1.wav"), freq=300, duration=0.05)
        
    # Add a fallback keyup
    generate_beep(os.path.join(pack_dir, "keyup.wav"), freq=300, duration=0.05)

print("Generated dummy soundpacks!")
