@preconcurrency import AVFoundation
import CoreAudio

struct AudioDevice: Identifiable, Equatable, Hashable {
    let id: AudioDeviceID
    let name: String
    var isDefault: Bool = false
}

enum PerformanceMode: String, CaseIterable, Identifiable {
    case powerSavings = "power_savings"
    case balanced = "balanced"
    case zeroLatency = "zero_latency"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .powerSavings:
            return "Power Savings"
        case .balanced:
            return "Balanced"
        case .zeroLatency:
            return "Zero Latency"
        }
    }

    var detailText: String {
        switch self {
        case .powerSavings:
            return "Lowest idle battery draw with a short wake-up when typing resumes."
        case .balanced:
            return "Keeps Mecha responsive while letting the engine cool down after inactivity."
        case .zeroLatency:
            return "Keeps the engine primed for the fastest possible first keystroke."
        }
    }

    var indicatorHeights: [CGFloat] {
        switch self {
        case .powerSavings:
            return [4, 6, 5, 4]
        case .balanced:
            return [6, 9, 11, 8]
        case .zeroLatency:
            return [8, 12, 14, 10]
        }
    }
}

struct PerformanceModeConfiguration: Equatable {
    let activePlayerCount: Int
    let idleTimeout: TimeInterval?
    let keepsEnginePrimed: Bool
    let statsFlushInterval: TimeInterval
}

struct PlaybackFormatValues: Sendable {
    let sampleRate: Double
    let channelCount: AVAudioChannelCount
}

class AudioEngineManager: ObservableObject {
    static let masterVolumeKey = "MasterVolume"
    static let isMutedKey = "IsMuted"
    static let performanceModeKey = "PerformanceMode"
    static let selectedDeviceIDKey = "SelectedOutputDeviceID"

    private let engine = AVAudioEngine()
    private let mixer: AVAudioMixerNode
    
    @Published var availableOutputDevices: [AudioDevice] = []
    @Published var selectedDeviceID: AudioDeviceID? {
        didSet {
            UserDefaults.standard.set(selectedDeviceID.map { Int($0) } ?? -1, forKey: Self.selectedDeviceIDKey)
            guard applyOutputDevice(id: selectedDeviceID) else {
                guard selectedDeviceID != nil else {
                    return
                }

                print("[AudioEngineManager] Failed to apply selected output device. Falling back to system default.")
                selectedDeviceID = nil
                return
            }
        }
    }
    
    // Pool of AVAudioPlayerNodes to handle rapid simultaneous typing
    private var playerNodes: [AVAudioPlayerNode] = []
    private var pitchNodes: [AVAudioUnitVarispeed] = []
    private var currentNodeIndex = 0
    private let poolSize = 32 // Support 32 simultaneous notes with unique pitch
    private let lock = NSLock()
    private var activePlayerLimit = 20
    private var idleTimeout: TimeInterval?
    private var idleShutdownTimer: Timer?
    private var packDefaultGainDb: Float = 0
    private var packStereoWidth: Float = 0.12
    private var packPitchJitterCents: Float = 0
    private var packTimingJitterMs: Float = 0
    private var packReleaseBlend: Float = 0
    private var appliedDeviceID: AudioDeviceID?
    private var observedSystemDefaultDeviceID: AudioDeviceID?
    private var hardwareChangeListener: AudioObjectPropertyListenerBlock?
    
    @Published var masterVolume: Float = 0.8 {
        didSet {
            // Round to 1 decimal place to avoid floating point drift (e.g. 0.60000002)
            let rounded = (masterVolume * 10).rounded() / 10
            UserDefaults.standard.set(rounded, forKey: Self.masterVolumeKey)
            mixer.volume = Self.effectiveMixerVolume(masterVolume: rounded, isMuted: isMuted)
        }
    }
    
    @Published var isMuted: Bool = false {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: Self.isMutedKey)
            mixer.volume = Self.effectiveMixerVolume(masterVolume: masterVolume, isMuted: isMuted)
        }
    }

    @Published var performanceMode: PerformanceMode = .balanced {
        didSet {
            UserDefaults.standard.set(performanceMode.rawValue, forKey: Self.performanceModeKey)
            applyPerformanceMode()
        }
    }
    
    // --- Mechanical Life Engine Tuning ---
    @Published var pitchJitterRange: Float = 0.02 {
        didSet { UserDefaults.standard.set(pitchJitterRange, forKey: "PitchJitter") }
    }
    @Published var volumeJitterRange: Float = 0.05 {
        didSet { UserDefaults.standard.set(volumeJitterRange, forKey: "VolumeJitter") }
    }
    @Published var silenceThreshold: TimeInterval = 0.5 {
        didSet { UserDefaults.standard.set(silenceThreshold, forKey: "SilenceThreshold") }
    }
    
    // --- Pro Max Acoustic Master ---
    @Published var basePitch: Float = 1.0 {
        didSet { UserDefaults.standard.set(basePitch, forKey: "BasePitch") }
    }
    @Published var volumeSpace: Float = 1.0 {
        didSet { UserDefaults.standard.set(volumeSpace, forKey: "VolumeSpace") }
    }
    @Published var volumeEnter: Float = 1.0 {
        didSet { UserDefaults.standard.set(volumeEnter, forKey: "VolumeEnter") }
    }
    @Published var volumeAlpha: Float = 1.0 {
        didSet { UserDefaults.standard.set(volumeAlpha, forKey: "VolumeAlpha") }
    }
    
    // Pre-loaded memory space
    private var soundBuffers: [URL: AVAudioPCMBuffer] = [:]

    static func resolvedMasterVolume(from defaults: UserDefaults = .standard) -> Float {
        let savedVolume = defaults.float(forKey: masterVolumeKey)
        return savedVolume == 0 ? 0.8 : (savedVolume * 5).rounded() / 5
    }

    static func resolvedMuteState(from defaults: UserDefaults = .standard) -> Bool {
        (defaults.object(forKey: isMutedKey) as? Bool) ?? false
    }

    static func resolvedPerformanceMode(from defaults: UserDefaults = .standard) -> PerformanceMode {
        guard
            let rawValue = defaults.string(forKey: performanceModeKey),
            let resolvedMode = PerformanceMode(rawValue: rawValue)
        else {
            return .balanced
        }

        return resolvedMode
    }

    static func configuration(for mode: PerformanceMode) -> PerformanceModeConfiguration {
        switch mode {
        case .powerSavings:
            return PerformanceModeConfiguration(
                activePlayerCount: 10,
                idleTimeout: 1.5,
                keepsEnginePrimed: false,
                statsFlushInterval: 8
            )
        case .balanced:
            return PerformanceModeConfiguration(
                activePlayerCount: 20,
                idleTimeout: 8,
                keepsEnginePrimed: false,
                statsFlushInterval: 4
            )
        case .zeroLatency:
            return PerformanceModeConfiguration(
                activePlayerCount: 32,
                idleTimeout: nil,
                keepsEnginePrimed: true,
                statsFlushInterval: 2
            )
        }
    }

    static func effectiveMixerVolume(masterVolume: Float, isMuted: Bool) -> Float {
        guard !isMuted else {
            return 0
        }

        return (masterVolume * 10).rounded() / 10
    }

    static func basePlaybackVolume(isRepeat: Bool, isKeyUp: Bool) -> Float {
        if isRepeat {
            return 0.08
        }

        if isKeyUp {
            return 0.18
        }

        return 0.25
    }

    static func effectivePlaybackVolume(
        baseVolume: Float,
        jitter: Float,
        categoryMultiplier: Float,
        masterVolume: Float,
        isMuted: Bool
    ) -> Float {
        guard !isMuted else {
            return 0
        }

        return baseVolume * jitter * categoryMultiplier * masterVolume
    }

    static func packGainMultiplier(defaultGainDb: Float) -> Float {
        pow(10, defaultGainDb / 20)
    }

    static func stereoPanPosition(for keyType: String, stereoWidth: Float) -> Float {
        let clampedWidth = max(0, min(stereoWidth, 1))

        switch keyType {
        case "space":
            return 0
        case "escape", "tab", "caps_lock", "modifier_left":
            return -0.45 * clampedWidth
        case "function", "number_row", "alphanumeric_left":
            return -0.22 * clampedWidth
        case "punctuation", "alphanumeric_right":
            return 0.22 * clampedWidth
        case "backspace", "delete", "enter", "return", "navigation", "arrow", "numpad", "modifier_right":
            return 0.5 * clampedWidth
        case "modifier":
            return 0
        default:
            return 0
        }
    }

    static func pitchJitterDelta(for cents: Float) -> Float {
        guard cents > 0 else {
            return 0
        }

        return Float(pow(2.0, Double(cents) / 1200.0) - 1.0)
    }

    static func schedulingDelaySeconds(timingJitterMs: Float) -> TimeInterval {
        let clampedMs = max(0, timingJitterMs)
        guard clampedMs > 0 else {
            return 0
        }

        return Double.random(in: 0...Double(clampedMs) / 1000.0)
    }

    static func releaseSampleGainMultiplier(releaseBlend: Float) -> Float {
        let clampedBlend = max(0, min(releaseBlend, 1))
        return 0.55 + (0.45 * clampedBlend)
    }

    static func releaseSampleGainMultiplier(releaseBlend: Float, isFallback: Bool) -> Float {
        let nativeReleaseGain = releaseSampleGainMultiplier(releaseBlend: releaseBlend)
        return isFallback ? nativeReleaseGain * 0.65 : nativeReleaseGain
    }

    static func normalizedPlaybackFormatValues(sampleRate: Double, channelCount: AVAudioChannelCount) -> PlaybackFormatValues {
        let resolvedSampleRate = sampleRate > 0 ? sampleRate : 44100
        let resolvedChannelCount = channelCount > 0 ? channelCount : 2
        return PlaybackFormatValues(sampleRate: resolvedSampleRate, channelCount: resolvedChannelCount)
    }

    static func resolvedStoredOutputDeviceID(from storedValue: Int) -> AudioDeviceID? {
        storedValue > 0 ? AudioDeviceID(storedValue) : nil
    }

    static func resolvedOutputTargetDeviceID(
        explicitSelection: AudioDeviceID?,
        systemDefaultDeviceID: AudioDeviceID?
    ) -> AudioDeviceID? {
        explicitSelection ?? systemDefaultDeviceID
    }

    static func shouldRefreshSystemDefaultBinding(
        explicitSelection: AudioDeviceID?,
        previouslyAppliedDeviceID: AudioDeviceID?,
        newSystemDefaultDeviceID: AudioDeviceID?
    ) -> Bool {
        guard explicitSelection == nil, let newSystemDefaultDeviceID else {
            return false
        }

        return previouslyAppliedDeviceID != newSystemDefaultDeviceID
    }

    static func shouldResetSelection(
        selectedDeviceID: AudioDeviceID?,
        availableDeviceIDs: [AudioDeviceID]
    ) -> Bool {
        guard let selectedDeviceID else {
            return false
        }

        return !availableDeviceIDs.contains(selectedDeviceID)
    }

    static func currentSystemDefaultOutputDeviceID() -> AudioDeviceID? {
        var defaultOutputDeviceID: AudioDeviceID = 0
        var defaultPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var defaultDataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultPropertyAddress,
            0,
            nil,
            &defaultDataSize,
            &defaultOutputDeviceID
        )
        guard status == noErr, defaultOutputDeviceID != 0 else {
            return nil
        }

        return defaultOutputDeviceID
    }

    static func getAvailableOutputDevices() -> [AudioDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        guard status == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
        guard status == noErr else { return [] }

        var outputDevices: [AudioDevice] = []
        
        // Get the default output device ID
        var defaultOutputDeviceID: AudioDeviceID = 0
        var defaultPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var defaultDataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultPropertyAddress, 0, nil, &defaultDataSize, &defaultOutputDeviceID)

        for deviceID in deviceIDs {
            // Check if it's an output device
            var streamPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamDataSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &streamPropertyAddress, 0, nil, &streamDataSize)
            
            if status == noErr && streamDataSize > 0 {
                // Get the device name
                var namePropertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceNameCFString,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var nameString: Unmanaged<CFString>?
                var nameDataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
                status = AudioObjectGetPropertyData(deviceID, &namePropertyAddress, 0, nil, &nameDataSize, &nameString)
                
                let name = (nameString?.takeRetainedValue() as String?) ?? "Unknown Device"
                outputDevices.append(AudioDevice(id: deviceID, name: name, isDefault: deviceID == defaultOutputDeviceID))
            }
        }
        
        return outputDevices
    }

    func refreshOutputDevices() {
        let devices = Self.getAvailableOutputDevices()
        self.availableOutputDevices = devices
        observedSystemDefaultDeviceID = Self.currentSystemDefaultOutputDeviceID()
        
        // Ensure selectedDeviceID is still valid
        if Self.shouldResetSelection(
            selectedDeviceID: selectedDeviceID,
            availableDeviceIDs: devices.map(\.id)
        ) {
            self.selectedDeviceID = nil
        }
    }

    @discardableResult
    private func applyOutputDevice(id: AudioDeviceID?) -> Bool {
        let wasRunning = engine.isRunning
        if wasRunning {
            engine.pause()
        }
        
        let outputNode = engine.outputNode
        guard let audioUnit = outputNode.audioUnit else {
            print("[AudioEngineManager] Output node is missing its audio unit.")
            return false
        }

        let targetDeviceID = Self.resolvedOutputTargetDeviceID(
            explicitSelection: id,
            systemDefaultDeviceID: observedSystemDefaultDeviceID ?? Self.currentSystemDefaultOutputDeviceID()
        )

        guard var deviceID = targetDeviceID else {
            appliedDeviceID = nil
            reconfigurePlaybackFormatIfNeeded()
            if wasRunning {
                try? engine.start()
            }
            return true
        }

        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            print("[AudioEngineManager] Failed to set output device \(deviceID): \(status)")
            if wasRunning {
                try? engine.start()
            }
            return false
        }
        
        appliedDeviceID = deviceID
        reconfigurePlaybackFormatIfNeeded()
        
        if wasRunning {
            try? engine.start()
        }

        return true
    }

    private func handleObservedOutputHardwareChange() {
        let previousSelection = selectedDeviceID
        let previousAppliedDeviceID = appliedDeviceID
        let newSystemDefaultDeviceID = Self.currentSystemDefaultOutputDeviceID()
        observedSystemDefaultDeviceID = newSystemDefaultDeviceID

        refreshOutputDevices()

        guard selectedDeviceID == previousSelection else {
            return
        }

        guard Self.shouldRefreshSystemDefaultBinding(
            explicitSelection: selectedDeviceID,
            previouslyAppliedDeviceID: previousAppliedDeviceID,
            newSystemDefaultDeviceID: newSystemDefaultDeviceID
        ) else {
            return
        }

        _ = applyOutputDevice(id: nil)
    }

    private func observeOutputHardwareChanges() {
        guard hardwareChangeListener == nil else {
            return
        }

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.handleObservedOutputHardwareChange()
        }

        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var defaultPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var devicesPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let defaultStatus = AudioObjectAddPropertyListenerBlock(
            systemObject,
            &defaultPropertyAddress,
            .main,
            listener
        )
        let devicesStatus = AudioObjectAddPropertyListenerBlock(
            systemObject,
            &devicesPropertyAddress,
            .main,
            listener
        )

        guard defaultStatus == noErr, devicesStatus == noErr else {
            if defaultStatus == noErr {
                AudioObjectRemovePropertyListenerBlock(systemObject, &defaultPropertyAddress, .main, listener)
            }
            if devicesStatus == noErr {
                AudioObjectRemovePropertyListenerBlock(systemObject, &devicesPropertyAddress, .main, listener)
            }
            print("[AudioEngineManager] Failed to observe audio hardware changes: default=\(defaultStatus) devices=\(devicesStatus)")
            return
        }

        hardwareChangeListener = listener
    }

    private func stopObservingOutputHardwareChanges() {
        guard let hardwareChangeListener else {
            return
        }

        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var defaultPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var devicesPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListenerBlock(systemObject, &defaultPropertyAddress, .main, hardwareChangeListener)
        AudioObjectRemovePropertyListenerBlock(systemObject, &devicesPropertyAddress, .main, hardwareChangeListener)
        self.hardwareChangeListener = nil
    }

    func updateRenderingProfile(
        defaultGainDb: Float,
        stereoWidth: Float,
        pitchJitterCents: Float,
        timingJitterMs: Float,
        releaseBlend: Float
    ) {
        lock.lock()
        defer { lock.unlock() }

        packDefaultGainDb = defaultGainDb
        packStereoWidth = stereoWidth
        packPitchJitterCents = pitchJitterCents
        packTimingJitterMs = timingJitterMs
        packReleaseBlend = releaseBlend
    }
    
    init() {
        self.mixer = engine.mainMixerNode
        
        // Restore settings: Default to 0.8 but round to 1 decimal to match "staircase" steps
        self.masterVolume = Self.resolvedMasterVolume()
        self.isMuted = Self.resolvedMuteState()
        self.performanceMode = Self.resolvedPerformanceMode()
        
        self.mixer.volume = Self.effectiveMixerVolume(masterVolume: masterVolume, isMuted: isMuted)
        
        // Refresh devices
        refreshOutputDevices()
        observeOutputHardwareChanges()
        
        // Restore Mechanical Tuning
        self.pitchJitterRange = UserDefaults.standard.object(forKey: "PitchJitter") as? Float ?? 0.02
        self.volumeJitterRange = UserDefaults.standard.object(forKey: "VolumeJitter") as? Float ?? 0.05
        self.silenceThreshold = UserDefaults.standard.object(forKey: "SilenceThreshold") as? TimeInterval ?? 0.5
        
        // Restore Pro Max Master
        self.basePitch = UserDefaults.standard.object(forKey: "BasePitch") as? Float ?? 1.0
        self.volumeSpace = UserDefaults.standard.object(forKey: "VolumeSpace") as? Float ?? 1.0
        self.volumeEnter = UserDefaults.standard.object(forKey: "VolumeEnter") as? Float ?? 1.0
        self.volumeAlpha = UserDefaults.standard.object(forKey: "VolumeAlpha") as? Float ?? 1.0
        
        setupEngine()
        applyPerformanceMode()

        if let savedDeviceID = Self.resolvedStoredOutputDeviceID(
            from: UserDefaults.standard.integer(forKey: Self.selectedDeviceIDKey)
        ) {
            self.selectedDeviceID = savedDeviceID
        }
    }
    
    private lazy var playbackFormat: AVAudioFormat = resolvePlaybackFormat()

    private func resolvePlaybackFormat() -> AVAudioFormat {
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let inputFormat = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : inputFormat.sampleRate
        let channelCount = outputFormat.channelCount > 0 ? outputFormat.channelCount : inputFormat.channelCount
        let values = Self.normalizedPlaybackFormatValues(sampleRate: sampleRate, channelCount: channelCount)
        return AVAudioFormat(standardFormatWithSampleRate: values.sampleRate, channels: values.channelCount)!
    }

    private func reconfigurePlaybackFormatIfNeeded() {
        let resolvedFormat = resolvePlaybackFormat()
        guard resolvedFormat.sampleRate != playbackFormat.sampleRate || resolvedFormat.channelCount != playbackFormat.channelCount else {
            return
        }

        let wasRunning = engine.isRunning
        if wasRunning {
            engine.pause()
        }

        for (node, pitch) in zip(playerNodes, pitchNodes) {
            engine.disconnectNodeOutput(node)
            engine.disconnectNodeOutput(pitch)
            engine.connect(node, to: pitch, format: resolvedFormat)
            engine.connect(pitch, to: mixer, format: resolvedFormat)
        }

        playbackFormat = resolvedFormat

        if wasRunning {
            try? engine.start()
        }
    }

    private func applyPerformanceMode() {
        let configuration = Self.configuration(for: performanceMode)
        activePlayerLimit = max(1, min(playerNodes.count, configuration.activePlayerCount))
        idleTimeout = configuration.idleTimeout

        if configuration.keepsEnginePrimed {
            cancelIdleShutdown()
            ensureEngineRunning()
        } else {
            scheduleIdleShutdownIfNeeded()
        }
    }

    private func ensureEngineRunning() {
        reconfigurePlaybackFormatIfNeeded()
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    private func cancelIdleShutdown() {
        idleShutdownTimer?.invalidate()
        idleShutdownTimer = nil
    }

    private func hasActivePlayback() -> Bool {
        playerNodes.contains(where: \.isPlaying)
    }

    private func scheduleIdleShutdownIfNeeded() {
        cancelIdleShutdown()

        let configuration = Self.configuration(for: performanceMode)
        guard !configuration.keepsEnginePrimed, let timeout = configuration.idleTimeout else {
            return
        }

        idleShutdownTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.suspendEngineIfIdle()
        }
        idleShutdownTimer?.tolerance = min(1.0, timeout * 0.35)
    }

    private func suspendEngineIfIdle() {
        lock.lock()
        defer { lock.unlock() }

        let configuration = Self.configuration(for: performanceMode)
        guard !configuration.keepsEnginePrimed else { return }
        guard !hasActivePlayback() else {
            scheduleIdleShutdownIfNeeded()
            return
        }

        if engine.isRunning {
            engine.pause()
        }
    }
    
    private func setupEngine() {
        // Initialize pool with fixed-format connections (Definitive Fix for switching lag)
        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            let pitch = AVAudioUnitVarispeed()
            
            engine.attach(node)
            engine.attach(pitch)
            
            // Connect once using the current hardware output format.
            engine.connect(node, to: pitch, format: playbackFormat)
            engine.connect(pitch, to: mixer, format: playbackFormat)
            
            playerNodes.append(node)
            pitchNodes.append(pitch)
        }
        
        // Finalize internal mixer gain
        mixer.volume = Self.effectiveMixerVolume(masterVolume: masterVolume, isMuted: isMuted)
    }
    
    private var loadingTask: Task<Void, Never>?
    
    // Call this whenever a soundpack is changed
    func prebufferPack(urls: [URL]) {
        // Cancel any existing load to prioritize the latest pack
        loadingTask?.cancel()
        
        loadingTask = Task { [weak self] in
            guard let self = self else { return }
            let playbackValues = await MainActor.run { () -> PlaybackFormatValues in
                self.reconfigurePlaybackFormatIfNeeded()
                return Self.normalizedPlaybackFormatValues(
                    sampleRate: self.playbackFormat.sampleRate,
                    channelCount: self.playbackFormat.channelCount
                )
            }
            let targetFormat = AVAudioFormat(
                standardFormatWithSampleRate: playbackValues.sampleRate,
                channels: playbackValues.channelCount
            )!
            
            // 1. Background Layer: High-Fidelity Pre-Caching & Normalization
            var tempBuffers: [URL: AVAudioPCMBuffer] = [:]
            
            for url in urls {
                if Task.isCancelled { return }
                
                guard let file = try? AVAudioFile(forReading: url) else { continue }
                
                // Use AVAudioConverter to transform sample rate/channels on the fly
                if let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) {
                    do {
                        try file.read(into: buffer)
                        
                        // If file matches fixed system format, store directly
                        if file.processingFormat.sampleRate == targetFormat.sampleRate && file.processingFormat.channelCount == targetFormat.channelCount {
                            tempBuffers[url] = buffer
                        } else if let converter = AVAudioConverter(from: file.processingFormat, to: targetFormat) {
                            // Professional normalization to the active hardware format.
                            let convertedCapacity = AVAudioFrameCount(Double(buffer.frameLength) * (targetFormat.sampleRate / file.processingFormat.sampleRate))
                            if let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: convertedCapacity) {
                                var error: NSError?
                                let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                                    outStatus.pointee = .haveData
                                    return buffer
                                }
                                
                                if status != .error {
                                    tempBuffers[url] = convertedBuffer
                                }
                            }
                        }
                    } catch {
                        print("[AudioEngineManager] v3.0 Error reading: \(url.lastPathComponent)")
                    }
                }
            }
            
            let loadedBuffers = tempBuffers

            // 2. Atomic Transition Layer (0ms Swap / No Engine Restart)
            await MainActor.run {
                if Task.isCancelled { return }
                
                self.lock.lock()
                defer { self.lock.unlock() }
                
                // NO engine.stop() or reconnection required!
                // The engine stays active and just swaps the buffers atomically.
                self.soundBuffers = loadedBuffers
                
                if Self.configuration(for: self.performanceMode).keepsEnginePrimed {
                    self.ensureEngineRunning()
                } else if self.engine.isRunning {
                    self.scheduleIdleShutdownIfNeeded()
                }
                
                print("[AudioEngineManager] v3.0.0 Master Engine Sync Complete (0ms Swap)")
            }
        }
    }
    
    private var lastRepeatTime: TimeInterval = 0
    
    func playSound(
        url: URL,
        keyGroup: String? = nil,
        isRepeat: Bool = false,
        holdDuration: TimeInterval = 0,
        isKeyUp: Bool = false,
        isFallbackRelease: Bool = false
    ) {
        // Fast-path: Skip all logic if muted
        if isMuted { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        // --- Intelligent Silence Filter ---
        // If a key is held for > threshold, stop playing sounds
        if isRepeat && holdDuration > silenceThreshold {
            return
        }
        
        // Throttling: If repeats are faster than 70ms (14Hz), skip some to avoid "buzzing"
        let now = Date().timeIntervalSince1970
        if isRepeat && (now - lastRepeatTime) < 0.070 {
            return
        }
        if isRepeat { lastRepeatTime = now }
        
        guard let buffer = soundBuffers[url], !playerNodes.isEmpty else {
            return
        }

        ensureEngineRunning()
        
        // Defensive indexing to prevent crashing if pool size ever changes
        let safeIndex = currentNodeIndex % max(1, activePlayerLimit)
        let node = playerNodes[safeIndex]
        let pitch = pitchNodes[safeIndex]
        
        // --- Natural Variance Engine ---
        // 1. Master Pitch + Jitter
        let packPitchDelta = Self.pitchJitterDelta(for: packPitchJitterCents)
        let pitchRange = (basePitch - pitchJitterRange - packPitchDelta)...(basePitch + pitchJitterRange + packPitchDelta)
        pitch.rate = Float.random(in: pitchRange)
        
        // 2. Pro Max Mixer Logic
        let filename = url.lastPathComponent.lowercased()
        var categoryMultiplier: Float = volumeAlpha
        var resolvedKeyGroup = keyGroup ?? "alphanumeric"
        
        if resolvedKeyGroup == "alphanumeric" && filename.contains("space") {
            categoryMultiplier = volumeSpace
            resolvedKeyGroup = "space"
        } else if resolvedKeyGroup == "alphanumeric" && (filename.contains("enter") || filename.contains("return")) {
            categoryMultiplier = volumeEnter
            resolvedKeyGroup = "enter"
        } else if resolvedKeyGroup == "alphanumeric" && (filename.contains("backspace") || filename.contains("delete")) {
            resolvedKeyGroup = "backspace"
        } else if resolvedKeyGroup == "alphanumeric" && filename.contains("arrow") {
            resolvedKeyGroup = "arrow"
        } else if resolvedKeyGroup == "alphanumeric" && (filename.contains("shift") || filename.contains("cmd") || filename.contains("ctrl") || filename.contains("alt") || filename.contains("opt") || filename.contains("modifier")) {
            resolvedKeyGroup = "modifier"
        }

        if resolvedKeyGroup == "space" {
            categoryMultiplier = volumeSpace
        } else if resolvedKeyGroup == "enter" || resolvedKeyGroup == "return" {
            categoryMultiplier = volumeEnter
        }
        
        // 3. Volume Headroom + Jitter
        let baseVolume = Self.basePlaybackVolume(isRepeat: isRepeat, isKeyUp: isKeyUp)
        let volRange = (1.0 - volumeJitterRange)...(1.0 + volumeJitterRange)
        let jitter = Float.random(in: volRange)
        node.volume = Self.effectivePlaybackVolume(
            baseVolume: baseVolume,
            jitter: jitter,
            categoryMultiplier: categoryMultiplier,
            masterVolume: masterVolume,
            isMuted: isMuted
        ) * Self.packGainMultiplier(defaultGainDb: packDefaultGainDb)
          * (isKeyUp ? Self.releaseSampleGainMultiplier(releaseBlend: packReleaseBlend, isFallback: isFallbackRelease) : 1)
        node.pan = Self.stereoPanPosition(for: resolvedKeyGroup, stereoWidth: packStereoWidth)

        let jitterDelay = isRepeat ? 0 : Self.schedulingDelaySeconds(timingJitterMs: packTimingJitterMs)
        let scheduledTime: AVAudioTime?
        if jitterDelay > 0 {
            let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: jitterDelay)
            scheduledTime = AVAudioTime(hostTime: hostTime)
        } else {
            scheduledTime = nil
        }

        node.scheduleBuffer(buffer, at: scheduledTime) { }
        node.play()
        scheduleIdleShutdownIfNeeded()
        
        // Round robin
        currentNodeIndex = (safeIndex + 1) % max(1, activePlayerLimit)
    }

    deinit {
        stopObservingOutputHardwareChanges()
    }
}
