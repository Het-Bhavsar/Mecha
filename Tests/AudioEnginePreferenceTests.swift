import Foundation

@main
struct AudioEnginePreferenceTests {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let suiteName = "MechaAudioEnginePreferenceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fputs("Failed to create isolated UserDefaults suite\n", stderr)
            exit(1)
        }

        defaults.removePersistentDomain(forName: suiteName)

        expect(AudioEngineManager.resolvedMuteState(from: defaults) == false, "Fresh installs should default to sound on")
        expect(AudioEngineManager.resolvedMasterVolume(from: defaults) == 0.8, "Fresh installs should default to 80% master volume")

        defaults.set(true, forKey: AudioEngineManager.isMutedKey)
        defaults.set(0.6, forKey: AudioEngineManager.masterVolumeKey)

        expect(AudioEngineManager.resolvedMuteState(from: defaults) == true, "Stored mute preference should be restored")
        expect(AudioEngineManager.resolvedMasterVolume(from: defaults) == 0.6, "Stored master volume should be restored")
        expect(AudioEngineManager.effectivePlaybackVolume(baseVolume: 0.25, jitter: 1.0, categoryMultiplier: 1.0, masterVolume: 0.8, isMuted: false) == 0.2, "Master volume should scale playback gain")
        expect(AudioEngineManager.effectivePlaybackVolume(baseVolume: 0.25, jitter: 1.0, categoryMultiplier: 1.0, masterVolume: 0.2, isMuted: false) == 0.05, "Lower master volume should produce a lower playback gain")
        expect(AudioEngineManager.effectivePlaybackVolume(baseVolume: 0.25, jitter: 1.0, categoryMultiplier: 1.0, masterVolume: 0.8, isMuted: true) == 0, "Muted playback should resolve to zero gain")
        expect(abs(AudioEngineManager.packGainMultiplier(defaultGainDb: -6) - 0.501) < 0.01, "Pack gain should convert from dB to a playback multiplier")
        expect(AudioEngineManager.stereoPanPosition(for: "space", stereoWidth: 0.4) == 0, "Space should remain centered in the stereo field")
        expect(AudioEngineManager.stereoPanPosition(for: "alphanumeric_left", stereoWidth: 0.4) < 0, "Left alphanumeric keys should lean left in the stereo field")
        expect(AudioEngineManager.stereoPanPosition(for: "backspace", stereoWidth: 0.4) > 0, "Backspace should lean right in the stereo field")
        expect(AudioEngineManager.stereoPanPosition(for: "enter", stereoWidth: 0.4) > 0, "Enter should lean right in the stereo field")
        expect(AudioEngineManager.stereoPanPosition(for: "numpad", stereoWidth: 0.4) > 0, "Numpad keys should lean right in the stereo field")
        expect(AudioEngineManager.schedulingDelaySeconds(timingJitterMs: 0) == 0, "Zero timing jitter should schedule immediately")
        for _ in 0..<32 {
            let delay = AudioEngineManager.schedulingDelaySeconds(timingJitterMs: 12)
            expect(delay >= 0 && delay <= 0.0121, "Timing jitter should stay within the manifest budget")
        }
        expect(AudioEngineManager.basePlaybackVolume(isRepeat: false, isKeyUp: false) == 0.25, "Downstrokes should keep the primary attack gain")
        expect(AudioEngineManager.basePlaybackVolume(isRepeat: false, isKeyUp: true) < AudioEngineManager.basePlaybackVolume(isRepeat: false, isKeyUp: false), "Key-up playback should be softer than key-down")
        expect(AudioEngineManager.releaseSampleGainMultiplier(releaseBlend: 0, isFallback: false) < 1.0, "Default release samples should blend below downstroke gain")
        expect(AudioEngineManager.releaseSampleGainMultiplier(releaseBlend: 1.0, isFallback: false) == 1.0, "Maximum release blend should preserve full release gain")
        expect(AudioEngineManager.releaseSampleGainMultiplier(releaseBlend: 0.4, isFallback: true) < AudioEngineManager.releaseSampleGainMultiplier(releaseBlend: 0.4, isFallback: false), "Fallback release playback should be lighter than native release samples")
        let fallbackFormat = AudioEngineManager.normalizedPlaybackFormatValues(sampleRate: 0, channelCount: 0)
        expect(fallbackFormat.sampleRate == 44100 && fallbackFormat.channelCount == 2, "Invalid hardware formats should fall back to 44.1kHz stereo")
        let preservedFormat = AudioEngineManager.normalizedPlaybackFormatValues(sampleRate: 48000, channelCount: 2)
        expect(preservedFormat.sampleRate == 48000 && preservedFormat.channelCount == 2, "Valid hardware formats should be preserved")

        defaults.removePersistentDomain(forName: suiteName)
    }
}
