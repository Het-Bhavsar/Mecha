import AppKit
import SwiftUI

struct SettingsWindowChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            SettingsWindowAccessor { window in
                if !window.styleMask.contains(.fullSizeContentView) {
                    window.styleMask.insert(.fullSizeContentView)
                }

                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.isMovableByWindowBackground = true
                if window.toolbar != nil {
                    window.toolbar = nil
                }

                window.backgroundColor = NSColor(
                    calibratedRed: 0.08,
                    green: 0.09,
                    blue: 0.12,
                    alpha: 1
                )

                if #available(macOS 11.0, *) {
                    window.tabbingMode = .disallowed
                }
            }
        )
    }
}

extension View {
    func settingsWindowChrome() -> some View {
        modifier(SettingsWindowChromeModifier())
    }
}

private struct SettingsWindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                configure(window)
            }
        }
    }
}
