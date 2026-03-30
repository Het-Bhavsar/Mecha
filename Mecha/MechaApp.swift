import SwiftUI
import AppKit
import ServiceManagement

@main
struct MechaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Dependencies
    // Dependencies are now initialized in init() to support AppController wiring
    @StateObject private var eventManager: EventTapManager
    @StateObject private var audioManager: AudioEngineManager
    @StateObject private var soundPackManager: SoundPackManager
    @StateObject private var storeManager: StoreManager
    @StateObject private var statsManager: StatsManager
    @StateObject private var updateManager: UpdateManager
    
    // Persistent background controller that wires events to audio
    @StateObject private var appController: AppController
    
    init() {
        let event = EventTapManager()
        let audio = AudioEngineManager()
        let pack = SoundPackManager()
        let store = StoreManager()
        let stats = StatsManager()
        let updater = UpdateManager()
        
        self._eventManager = StateObject(wrappedValue: event)
        self._audioManager = StateObject(wrappedValue: audio)
        self._soundPackManager = StateObject(wrappedValue: pack)
        self._storeManager = StateObject(wrappedValue: store)
        self._statsManager = StateObject(wrappedValue: stats)
        self._updateManager = StateObject(wrappedValue: updater)
        
        self._appController = StateObject(wrappedValue: AppController(
            eventManager: event,
            audioManager: audio,
            soundPackManager: pack,
            statsManager: stats
        ))
    }

    private static let menuBarIcon: NSImage = {
        if let bundledImage = MenuBarIconAsset.bundledImage() {
            return bundledImage
        }

        let fallbackImage = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "Mecha") ?? NSImage()
        return MenuBarIconAsset.configure(image: fallbackImage)
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuView(
                eventManager: eventManager,
                audioManager: audioManager,
                soundPackManager: soundPackManager,
                storeManager: storeManager,
                statsManager: statsManager,
                updateManager: updateManager
            )
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView(
                audioManager: audioManager,
                soundPackManager: soundPackManager,
                storeManager: storeManager,
                statsManager: statsManager,
                updateManager: updateManager
            )
        }
        
        WindowGroup(id: "permissions") {
            PermissionsView(eventManager: eventManager)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon entirely, we are a menu bar app. 
        // Note: project.yml should also set LSUIElement = true.
        NSApp.setActivationPolicy(.accessory)
    }
}
