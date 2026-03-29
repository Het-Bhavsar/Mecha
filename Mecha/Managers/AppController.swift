import SwiftUI
import Combine

/// A persistent coordinator that manages the life-cycle of event-to-audio wiring.
/// Unlike MenuView, this lives for the entire lifecycle of the App.
class AppController: ObservableObject {
    private let eventManager: EventTapManager
    private let audioManager: AudioEngineManager
    private let soundPackManager: SoundPackManager
    private let statsManager: StatsManager
    
    private var cancellables = Set<AnyCancellable>()
    private var activePressSamples: [Int64: SelectedSoundSample] = [:]
    
    init(eventManager: EventTapManager, 
         audioManager: AudioEngineManager, 
         soundPackManager: SoundPackManager, 
         statsManager: StatsManager) {
        self.eventManager = eventManager
        self.audioManager = audioManager
        self.soundPackManager = soundPackManager
        self.statsManager = statsManager
        
        setupWiring()
        setupObservers()
        
        // Initial pre-buffer
        refreshPackBuffers()
        syncRenderingProfile()
        
        print("[AppController] Initialized and wired for background sounds.")
    }
    
    private func setupWiring() {
        // Essential: Connect the low-level EventTap events to the Audio Engine
        eventManager.onKeyDown = { [weak self] keyCode, keyType, isRepeat, holdDuration in
            guard let self = self else { return }
            
            if !isRepeat {
                self.statsManager.incrementKeystroke()
            }
            
            if let sample = self.soundPackManager.getRandomDownSound(for: keyType) {
                if !isRepeat {
                    self.activePressSamples[keyCode] = sample
                }
                self.audioManager.playSound(
                    url: sample.url,
                    keyGroup: sample.playbackGroup,
                    isRepeat: isRepeat,
                    holdDuration: holdDuration,
                    isKeyUp: false
                )
            }
        }
        
        eventManager.onKeyUp = { [weak self] keyCode, keyType in
            guard let self = self else { return }

            let rememberedPress = self.activePressSamples.removeValue(forKey: keyCode)
            let nativeRelease = self.soundPackManager.getUpSound(for: keyType)
            if let sample = SoundPackManager.resolvedKeyUpSample(
                nativeRelease: nativeRelease,
                fallbackPress: rememberedPress
            ) {
                self.audioManager.playSound(
                    url: sample.url,
                    keyGroup: sample.playbackGroup,
                    isRepeat: false,
                    isKeyUp: true,
                    isFallbackRelease: nativeRelease == nil
                )
            }
        }
    }
    
    private func setupObservers() {
        // Listen for when the pack manager finishes its background filesystem scan
        soundPackManager.$isSwitching
            .dropFirst() // Skip initial state
            .sink { [weak self] isSwitching in
                if !isSwitching {
                    // Background scan complete, now trigger background buffer load
                    self?.refreshPackBuffers()
                }
            }
            .store(in: &cancellables)

        soundPackManager.$activeRenderingProfile
            .sink { [weak self] profile in
                self?.audioManager.updateRenderingProfile(
                    defaultGainDb: profile.defaultGainDb,
                    stereoWidth: profile.stereoWidth,
                    pitchJitterCents: profile.pitchJitterCents,
                    timingJitterMs: profile.timingJitterMs,
                    releaseBlend: profile.releaseBlend
                )
            }
            .store(in: &cancellables)

        audioManager.$performanceMode
            .sink { [weak self] mode in
                let configuration = AudioEngineManager.configuration(for: mode)
                self?.statsManager.updatePersistenceInterval(configuration.statsFlushInterval)
            }
            .store(in: &cancellables)
    }
    
    private func refreshPackBuffers() {
        activePressSamples.removeAll()
        let urls = soundPackManager.allSoundURLs()
        audioManager.prebufferPack(urls: urls)
        print("[AppController] Re-buffered sounds for: \(soundPackManager.activePackName)")
    }

    private func syncRenderingProfile() {
        let profile = soundPackManager.activeRenderingProfile
        audioManager.updateRenderingProfile(
            defaultGainDb: profile.defaultGainDb,
            stereoWidth: profile.stereoWidth,
            pitchJitterCents: profile.pitchJitterCents,
            timingJitterMs: profile.timingJitterMs,
            releaseBlend: profile.releaseBlend
        )
    }
}
