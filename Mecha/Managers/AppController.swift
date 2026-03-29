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
        eventManager.onKeyDown = { [weak self] keyType, isRepeat, holdDuration in
            guard let self = self else { return }
            
            // Only play if not muted
            self.statsManager.incrementKeystroke()
            
            if let sample = self.soundPackManager.getRandomDownSound(for: keyType) {
                self.audioManager.playSound(
                    url: sample.url,
                    keyGroup: sample.playbackGroup,
                    isRepeat: isRepeat,
                    holdDuration: holdDuration,
                    isKeyUp: false
                )
            }
        }
        
        eventManager.onKeyUp = { [weak self] keyType, _ in
            guard let self = self else { return }
            
            if let sample = self.soundPackManager.getUpSound(for: keyType) {
                self.audioManager.playSound(url: sample.url, keyGroup: sample.playbackGroup, isRepeat: false, isKeyUp: true)
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
    }
    
    private func refreshPackBuffers() {
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
