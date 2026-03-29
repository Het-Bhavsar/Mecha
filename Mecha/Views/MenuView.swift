import SwiftUI

struct MenuView: View {
    @ObservedObject var eventManager: EventTapManager
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var soundPackManager: SoundPackManager
    @ObservedObject var storeManager: StoreManager
    @ObservedObject var statsManager: StatsManager
    
    @State private var isMixerExpanded: Bool = false
    @Environment(\.openWindow) var openWindow

    private var acousticEnabledBinding: Binding<Bool> {
        Binding(
            get: { !audioManager.isMuted },
            set: { audioManager.isMuted = !$0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Header: Brand Identity
            HStack(spacing: 8) {
                if let nsImage = NSImage(named: "logo") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Mecha")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .fixedSize()
                    if soundPackManager.isSwitching {
                        Text("SHIFTING...")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.orange)
                    } else {
                        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0"
                        Text("v\(version) Master Engine")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.blue)
                    }
                }
                
                // Header Visualizer: Dynamic Acoustic Feedback
                Group {
                    if audioManager.isMuted {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.red)
                            .frame(width: 16, height: 2)
                    } else {
                        HStack(spacing: 2) {
                            ForEach(Array(audioManager.performanceMode.indicatorHeights.enumerated()), id: \.offset) { _, height in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.blue.opacity(0.8))
                                    .frame(width: 2, height: height)
                            }
                        }
                    }
                }
                .padding(.leading, 4)
                
                Spacer()
                
                // Quick Mute Toggle
                Button(action: { audioManager.isMuted.toggle() }) {
                    Image(systemName: audioManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(audioManager.isMuted ? .red : .primary)
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(.plain)
                .help(audioManager.isMuted ? "Unmute" : "Mute")
                
                statusIcon
            }
            
            Divider()
            
            // Permissions Alert: High-Visibility Card
            if !eventManager.isTrusted {
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.red)
                        Text("System Access Required")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    
                    Text("Keyboard sounds are blocked until Mecha is granted Accessibility access in System Settings.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        eventManager.checkTrust()
                        eventManager.openSystemPrefs()
                    }) {
                        Text("Grant System Access")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    Text("Tip: If the prompt doesn't appear, remove and re-add Mecha in System Settings manually.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            } else if storeManager.isUnlocked == false && storeManager.trialDaysRemaining == 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trial Expired")
                        .font(.caption)
                        .foregroundColor(.red)
                    Button("Unlock Lifetime Access") {
                        storeManager.purchaseUnlock()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Output", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Toggle("", isOn: acousticEnabledBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .controlSize(.mini)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: audioManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 14)
                            .foregroundColor(audioManager.isMuted ? .red : .secondary)

                        Slider(value: $audioManager.masterVolume, in: 0...1, step: 0.1)
                            .controlSize(.mini)

                        Text("\(Int(audioManager.masterVolume * 100))%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.04))
                .cornerRadius(8)

                
                // Master Suite Controls
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Acoustic Mixer", systemImage: "slider.horizontal.3")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        // Local toggle for UI expansion, decoupled from Mute
                        Toggle("", isOn: $isMixerExpanded)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .controlSize(.mini)
                    }
                    
                    if isMixerExpanded {
                        VStack(spacing: 6) {
                            MixerSlider(label: "Alpha", value: $audioManager.volumeAlpha, icon: "keyboard")
                            MixerSlider(label: "Space", value: $audioManager.volumeSpace, icon: "space")
                            MixerSlider(label: "Enter", value: $audioManager.volumeEnter, icon: "return")
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.spring(duration: 0.3), value: isMixerExpanded)
                .padding(8)
                .background(Color.black.opacity(0.04))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sound Pack").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                    Picker("", selection: $soundPackManager.activePackName) {
                        ForEach(soundPackManager.installedPackVariants) { pack in
                            Text(pack.displayName).tag(pack.packName)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                
                Divider()
                
                // V2 Stats
                HStack {
                    VStack(alignment: .leading) {
                        Text("Today's Keystrokes").font(.caption2).foregroundColor(.secondary)
                        Text("\(statsManager.dailyKeystrokes)").font(.subheadline)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Est. WPM").font(.caption2).foregroundColor(.secondary)
                        Text("\(statsManager.estimatedWPM)").font(.subheadline)
                    }
                }
                
                if !storeManager.isUnlocked {
                    Text("\(storeManager.trialDaysRemaining) Days remaining on Evaluation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            
            Divider()
            
            // Footer Controls
            HStack {
                Button("Pro Max Settings") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .bold))
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            eventManager.checkTrust()
            statsManager.refreshIfNeeded()
        }
    }
    
    private var statusIcon: some View {
        Group {
            if !eventManager.isTrusted {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .help("Accessibility Permissions Required")
            } else if storeManager.isUnlocked == false && storeManager.trialDaysRemaining == 0 {
                Image(systemName: "lock.fill")
                    .foregroundColor(.red)
                    .help("Trial Expired")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .help("Active")
            }
        }
    }
}

struct MixerSlider: View {
    let label: String
    @Binding var value: Float
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .frame(width: 14)
            Slider(value: $value, in: 0...2)
                .controlSize(.mini)
            Text("\(Int(value * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
