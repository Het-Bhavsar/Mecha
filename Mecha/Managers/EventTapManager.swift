import Cocoa
import CoreGraphics

class EventTapManager: ObservableObject {
    @Published var isTrusted: Bool = AXIsProcessTrusted()
    
    // Callbacks to send the event to the Audio Engine
    var onKeyDown: ((String, Bool, TimeInterval) -> Void)?
    var onKeyUp: ((String, Bool) -> Void)?
    
    // Used to track long-press keys so we don't spam audio
    private var activeKeys: Set<Int64> = []
    private var lastPressTimes: [Int64: TimeInterval] = [:]
    private var firstPressTimes: [Int64: TimeInterval] = [:]
    
    fileprivate var eventPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private var trustTimer: Timer?
    
    init() {
        checkTrustAndStart()
        
        // Scalable approach: Actively poll until the user grants access
        // This bypasses the need for the user to click "Check Status" manually
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.eventPort == nil {
                self.checkTrustAndStart(prompt: false)
            } else {
                self.trustTimer?.invalidate()
                self.trustTimer = nil
            }
        }
    }
    
    /// Checks trust and attempts to start the tap. Only prompts on explicit demand.
    func checkTrustAndStart(prompt: Bool = true) {
        log("[Permissions] Explicitly triggering system prompt: \(prompt)")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        let systemSaysTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        DispatchQueue.main.async {
            // If we don't have the port yet, let's aggressively try to get it
            if self.eventPort == nil {
                self.startTap()
            }
            
            // Scalable fix: Never rely blindly on the buggy TCC API `systemSaysTrusted`
            // True trust is defined exclusively by whether the OS gave us a valid event loop port!
            self.isTrusted = systemSaysTrusted || (self.eventPort != nil)
        }
    }
    
    // Legacy alias for SwiftUI views calling `eventManager.checkTrust()`
    func checkTrust() {
        checkTrustAndStart(prompt: true)
    }
    
    func openSystemPrefs() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func log(_ message: String) {
        print(message)
        let logPath = "/tmp/clackmac.log"
        if let fileHandle = FileHandle(forWritingAtPath: logPath) {
            fileHandle.seekToEndOfFile()
            let logText = "\(Date()): \(message)\n"
            fileHandle.write(logText.data(using: .utf8)!)
            fileHandle.closeFile()
        } else {
            try? "\(Date()): \(message)\n".write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }

    private func startTap() {
        log("[EventTap] Attempting to start tap...")
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: customEventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            log("[EventTap] Failed to create CGEventTap - likely permissions issue")
            return
        }
        
        self.eventPort = port
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            log("[EventTap] CGEventTap started successfully. CFRunLoopSource added to main loop.")
        }
    }
    
    func handleEvent(type: CGEventType, event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        switch type {
        case .keyDown:
            let now = Date().timeIntervalSince1970
            let lastTime = lastPressTimes[keyCode] ?? 0
            
            // 1. Detect if this is the start of a hold
            if !activeKeys.contains(keyCode) {
                firstPressTimes[keyCode] = now
            }
            
            // 2. Core logic: If key is already pushed AND it's been < 250ms, it's a repeat.
            let isRepeat = activeKeys.contains(keyCode) && (now - lastTime < 0.25)
            let holdDuration = now - (firstPressTimes[keyCode] ?? now)
            
            lastPressTimes[keyCode] = now
            activeKeys.insert(keyCode)
            
            let typeString = mapKeyCode(Int(keyCode))
            self.onKeyDown?(typeString, isRepeat, holdDuration)
            
        case .keyUp:
            activeKeys.remove(keyCode)
            firstPressTimes.removeValue(forKey: keyCode)
            let typeString = mapKeyCode(Int(keyCode))
            self.onKeyUp?(typeString, false)
        case .flagsChanged:
            if !activeKeys.contains(keyCode) {
                activeKeys.insert(keyCode)
                let typeString = mapKeyCode(Int(keyCode))
                self.onKeyDown?(typeString, false, 0)
            } else {
                activeKeys.remove(keyCode)
                let typeString = mapKeyCode(Int(keyCode))
                self.onKeyUp?(typeString, false)
            }
        default:
            break
        }
    }
    
    // Simplify exact specific keys to a handful of broad archetypes
    // These zones line up with richer imported pack groups and still fall back cleanly for legacy packs.
    private func mapKeyCode(_ code: Int) -> String {
        switch code {
        case 49: return "space"
        case 36, 52: return "enter" // strict enter vs fn+enter
        case 51: return "backspace"
        case 48: return "tab"
        case 53: return "escape"
        case 57: return "caps_lock"
        case 55, 56, 58, 59, 63: return "modifier_left" // left cmd, shift, option, control, fn
        case 54, 60, 61, 62: return "modifier_right"
        case 64, 79, 80, 90, 96, 97, 98, 99, 100, 101, 103, 105, 106, 107, 109, 111, 113, 118, 120, 122: return "function"
        case 123...126: return "arrow"
        case 114, 115, 116, 117, 119, 121: return "navigation"
        case 65, 67, 69, 71, 72, 73, 75, 76, 77, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92: return "numpad"
        case 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 50: return "number_row"
        case 0, 1, 2, 3, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 17: return "alphanumeric_left"
        case 4, 16, 31, 32, 34, 35, 37, 38, 40, 45, 46: return "alphanumeric_right"
        case 30, 33, 39, 41, 42, 43, 44, 47: return "punctuation"
        default: return "alphanumeric"
        }
    }
    
    deinit {
        stopTap()
    }
    
    private func stopTap() {
        if let port = eventPort {
            CGEvent.tapEnable(tap: port, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventPort = nil
        runLoopSource = nil
        activeKeys.removeAll()
    }
}

private func customEventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passRetained(event) }
    
    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    
    // Ignore timeout events entirely, just return the event
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        CGEvent.tapEnable(tap: manager.eventPort!, enable: true)
        return Unmanaged.passRetained(event)
    }
    
    manager.handleEvent(type: type, event: event)
    
    return Unmanaged.passRetained(event)
}
