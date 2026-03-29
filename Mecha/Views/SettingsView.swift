import SwiftUI
import ServiceManagement

private enum SettingsTab: String, Hashable {
    case performance = "Performance"
    case acoustics = "Master Tuning"
    case mixer = "Live Mixer"
    case sounds = "Sound Packs"
    case intelligence = "Intelligence"
    case licensing = "Mecha Pro"

    var sidebarTitle: String {
        rawValue
    }

    var symbol: String {
        switch self {
        case .performance:
            return "gauge.with.needle.fill"
        case .acoustics:
            return "tuningfork"
        case .mixer:
            return "slider.horizontal.3"
        case .sounds:
            return "waveform.path.ecg"
        case .intelligence:
            return "brain.head.profile"
        case .licensing:
            return "star.fill"
        }
    }

    var sidebarDescription: String {
        switch self {
        case .performance:
            return "Startup and output posture"
        case .acoustics:
            return "Pitch and texture shaping"
        case .mixer:
            return "Per-key-family balance"
        case .sounds:
            return "Installed switch profiles"
        case .intelligence:
            return "Repeat and silence logic"
        case .licensing:
            return "Access and version details"
        }
    }

    var detailTitle: String {
        switch self {
        case .performance:
            return "Performance"
        case .acoustics:
            return "Master Tuning"
        case .mixer:
            return "Live Mixer"
        case .sounds:
            return "Sound Packs"
        case .intelligence:
            return "Intelligence"
        case .licensing:
            return "Mecha Pro"
        }
    }

    var detailSubtitle: String {
        switch self {
        case .performance:
            return "Calibrate launch behavior, master output, and the overall playback posture."
        case .acoustics:
            return "Shape the character of the active switch profile without leaving the native macOS window chrome."
        case .mixer:
            return "Balance how each key family sits in the mix so dense typing still feels controlled."
        case .sounds:
            return "Choose the active profile and keep an eye on pack switching status."
        case .intelligence:
            return "Tune repeat suppression and timing thresholds for a tighter, calmer engine."
        case .licensing:
            return "Review license state, upgrade access, and build metadata."
        }
    }
}

private struct SettingsSidebarSection: Identifiable {
    let title: String
    let tabs: [SettingsTab]

    var id: String { title }
}

struct SettingsView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var soundPackManager: SoundPackManager
    @ObservedObject var storeManager: StoreManager
    
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var selectedTab: SettingsTab = .performance

    private let sidebarSections = [
        SettingsSidebarSection(title: "Dashboard", tabs: [.performance]),
        SettingsSidebarSection(title: "Acoustic Lab", tabs: [.acoustics, .mixer]),
        SettingsSidebarSection(title: "Library", tabs: [.sounds]),
        SettingsSidebarSection(title: "System", tabs: [.intelligence, .licensing])
    ]

    private let footerMeterHeights: [CGFloat] = [8, 12, 18, 14, 22, 16, 10, 14, 20, 12]
    
    var body: some View {
        GeometryReader { geometry in
            let metrics = SettingsWindowMetrics(topSafeAreaInset: geometry.safeAreaInsets.top)

            HStack(spacing: 0) {
                sidebar(metrics: metrics)
                Rectangle()
                    .fill(Color.white.opacity(SettingsWindowMetrics.dividerOpacity))
                    .frame(width: 1)
                detailPane(metrics: metrics)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.12),
                        Color(red: 0.05, green: 0.06, blue: 0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea(.container, edges: .top)
        }
        .settingsWindowChrome()
        .frame(minWidth: 880, minHeight: 560)
    }
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: SettingsWindowMetrics.sectionSpacing) {
            summaryStrip(items: [
                ("Startup", launchAtLogin ? "Enabled" : "Manual"),
                ("Profile", soundPackManager.activePackDisplayName),
                ("Output", audioManager.isMuted ? "Muted" : "\(Int(audioManager.masterVolume * 100))%")
            ])

            settingsCard(
                title: "System behavior",
                subtitle: "Keep the engine ready in the background without crowding the native title bar."
            ) {
                settingRow(
                    title: "Launch at login",
                    subtitle: "Open silently in the menu bar and keep the playback engine warmed up."
                ) {
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { _, newValue in
                            toggleLaunchAtLogin(newValue)
                        }
                }
            }

            settingsCard(
                title: "Master output",
                subtitle: "Dial in the overall loudness before your active pack and mix controls take over."
            ) {
                settingRow(
                    title: "Master volume",
                    subtitle: "Global output level for every keystroke."
                ) {
                    HStack(spacing: 12) {
                        Slider(value: $audioManager.masterVolume, in: 0...1, step: 0.1)
                            .tint(Color(red: 0.39, green: 0.65, blue: 1.0))
                        valueBadge("\(Int(audioManager.masterVolume * 100))%")
                    }
                }

                cardDivider

                settingRow(
                    title: "Mute output",
                    subtitle: "Silence playback immediately without changing your preferred level."
                ) {
                    Toggle("", isOn: $audioManager.isMuted)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                cardDivider

                settingRow(
                    title: "Active profile",
                    subtitle: "The current switch profile feeding the output stage."
                ) {
                    valueBadge(soundPackManager.activePackDisplayName)
                }
            }
        }
    }
    
    private var acousticsSection: some View {
        VStack(alignment: .leading, spacing: SettingsWindowMetrics.sectionSpacing) {
            settingsCard(
                title: "Global pitch",
                subtitle: "Move between a deeper thock and a brighter click while keeping the window chrome balanced and uncluttered."
            ) {
                settingRow(
                    title: "Base pitch",
                    subtitle: "Shift the overall resonant character of the active pack."
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Slider(value: $audioManager.basePitch, in: 0.5...1.5)
                                .tint(Color(red: 0.40, green: 0.65, blue: 1.0))
                            valueBadge("\(Int(audioManager.basePitch * 100))%")
                        }

                        HStack {
                            Text("Deep")
                            Spacer()
                            Text("Neutral")
                            Spacer()
                            Text("Bright")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.42))
                    }
                }
            }

            settingsCard(
                title: "Mechanical variance",
                subtitle: "Add small timing and impact variation so repeated typing feels less synthetic."
            ) {
                settingRow(
                    title: "Time jitter",
                    subtitle: "Subtle pitch drift between rapid key events."
                ) {
                    HStack(spacing: 12) {
                        Slider(value: $audioManager.pitchJitterRange, in: 0...0.1)
                            .tint(Color(red: 0.64, green: 0.50, blue: 1.0))
                        valueBadge("\(Int(audioManager.pitchJitterRange * 1000)) ms")
                    }
                }

                cardDivider

                settingRow(
                    title: "Impact variance",
                    subtitle: "Micro-changes in strike intensity to keep the mix alive."
                ) {
                    HStack(spacing: 12) {
                        Slider(value: $audioManager.volumeJitterRange, in: 0...0.2)
                            .tint(Color(red: 0.40, green: 0.65, blue: 1.0))
                        valueBadge("\(Int(audioManager.volumeJitterRange * 1000)) ms")
                    }
                }
            }
        }
    }
    
    private var mixerSection: some View {
        settingsCard(
            title: "Per-family balance",
            subtitle: "Keep the mix even across dense passages by setting a dedicated level for each key family."
        ) {
            mixerRow(
                title: "Alphanumerics",
                subtitle: "The backbone of the typing bed.",
                systemImage: "keyboard",
                value: $audioManager.volumeAlpha
            )

            cardDivider

            mixerRow(
                title: "Spacebar",
                subtitle: "Control the weight of longer travel keys.",
                systemImage: "arrow.left.and.right",
                value: $audioManager.volumeSpace
            )

            cardDivider

            mixerRow(
                title: "Enter / Return",
                subtitle: "Tune the punctuation hit that anchors each line.",
                systemImage: "return.left",
                value: $audioManager.volumeEnter
            )
        }
    }
    
    private var soundsSection: some View {
        VStack(alignment: .leading, spacing: SettingsWindowMetrics.sectionSpacing) {
            settingsCard(
                title: "Active profile",
                subtitle: "Choose the switch pack feeding the live engine. Profiles prebuffer into memory when they become active."
            ) {
                Picker("Active Acoustic Profile", selection: $soundPackManager.activePackName) {
                    ForEach(soundPackManager.installedPackVariants) { pack in
                        Text(pack.displayName).tag(pack.packName)
                    }
                }
                .pickerStyle(.radioGroup)

                cardDivider

                settingRow(
                    title: "Pack status",
                    subtitle: "Shows whether the active profile is currently being loaded."
                ) {
                    valueBadge(soundPackManager.isSwitching ? "Switching…" : "Ready")
                }
            }

            summaryStrip(items: [
                ("Installed", "\(soundPackManager.installedPackVariants.count) variants"),
                ("Active", soundPackManager.activePackDisplayName),
                ("Buffer", soundPackManager.isSwitching ? "Refreshing" : "Primed")
            ])
        }
    }
    
    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: SettingsWindowMetrics.sectionSpacing) {
            settingsCard(
                title: "Repeat handling",
                subtitle: "Control how quickly Mecha suppresses held keys so long repeats stay musical instead of buzzy."
            ) {
                settingRow(
                    title: "Silence threshold",
                    subtitle: "Held keys beyond this duration stop generating repeat sounds."
                ) {
                    HStack(spacing: 12) {
                        Slider(value: $audioManager.silenceThreshold, in: 0.1...2.0)
                            .tint(Color(red: 0.32, green: 0.82, blue: 0.61))
                        valueBadge("\(Int(audioManager.silenceThreshold * 1000)) ms")
                    }
                }
            }

            summaryStrip(items: [
                ("Latency", "< 5 ms"),
                ("Repeat gate", "\(Int(audioManager.silenceThreshold * 1000)) ms"),
                ("Processing", "Local only")
            ])
        }
    }
    
    private var licensingSection: some View {
        VStack(alignment: .leading, spacing: SettingsWindowMetrics.sectionSpacing) {
            if storeManager.isUnlocked {
                settingsCard(
                    title: "License status",
                    subtitle: "Your Pro access is active, so advanced acoustic controls remain available across the full settings shell."
                ) {
                    HStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color(red: 0.43, green: 0.72, blue: 1.0))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mecha Pro is active")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.96))
                            Text("Lifetime commercial access verified for this build.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.58))
                        }

                        Spacer()
                    }
                    .padding(SettingsWindowMetrics.cardPadding)
                    .background(
                        RoundedRectangle(cornerRadius: SettingsWindowMetrics.cardCornerRadius, style: .continuous)
                            .fill(Color(red: 0.18, green: 0.32, blue: 0.63).opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: SettingsWindowMetrics.cardCornerRadius, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
            } else {
                settingsCard(
                    title: "Trial access",
                    subtitle: "Your evaluation window is still active. Upgrade when you're ready to keep the advanced acoustic controls unlocked."
                ) {
                    settingRow(
                        title: "Time remaining",
                        subtitle: "Days left in the current local trial period."
                    ) {
                        valueBadge("\(storeManager.trialDaysRemaining) days")
                    }

                    cardDivider

                    Button(action: { storeManager.purchaseUnlock() }) {
                        HStack {
                            Label("Unlock Mecha Pro", systemImage: "star.fill")
                            Spacer()
                            Text("$9.99")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.32, green: 0.58, blue: 1.0))
                }
            }

            settingsCard(
                title: "Build information",
                subtitle: "Version metadata for this local build."
            ) {
                settingRow(
                    title: "Version",
                    subtitle: "Marketing version exposed in the app bundle."
                ) {
                    valueBadge(appVersion)
                }

                cardDivider

                settingRow(
                    title: "Build",
                    subtitle: "Incremental build identifier from the bundle."
                ) {
                    valueBadge(appBuild)
                }

                cardDivider

                Text("Prepared by Het Bhavsar for this local build.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var headerBadgeText: String {
        switch selectedTab {
        case .performance:
            return audioManager.isMuted ? "Muted" : "Live output"
        case .acoustics:
            return "Pitch \(Int(audioManager.basePitch * 100))%"
        case .mixer:
            return soundPackManager.activePackDisplayName
        case .sounds:
            return soundPackManager.isSwitching ? "Switching" : "\(soundPackManager.installedPackVariants.count) variants"
        case .intelligence:
            return "\(Int(audioManager.silenceThreshold * 1000)) ms gate"
        case .licensing:
            return storeManager.isUnlocked ? "Unlocked" : "Trial"
        }
    }

    private var footerStatusText: String {
        if soundPackManager.isSwitching {
            return "Refreshing acoustic buffers"
        }

        if audioManager.isMuted {
            return "Engine ready, output muted"
        }

        return "Native acoustic engine active"
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(SettingsWindowMetrics.dividerOpacity))
            .frame(height: 1)
    }

    private func sidebar(metrics: SettingsWindowMetrics) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Group {
                    if let nsImage = NSImage(named: "logo") {
                        Image(nsImage: nsImage)
                            .resizable()
                    } else {
                        Image(systemName: "keyboard.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                }
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.14),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mecha")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.96))
                    Text("Native acoustic controls")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.42))
                }
            }
            .padding(.leading, metrics.sidebarHeaderLeadingInset)
            .padding(.trailing, SettingsWindowMetrics.columnPadding)
            .padding(.vertical, metrics.chromeVerticalPadding)
            .frame(maxWidth: .infinity, minHeight: metrics.chromeRowHeight, alignment: .leading)
            .overlay(alignment: .bottom) { cardDivider }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SettingsWindowMetrics.sectionSpacing) {
                    ForEach(sidebarSections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(Color.white.opacity(0.34))
                                .padding(.horizontal, 8)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(section.tabs, id: \.self) { tab in
                                    sidebarButton(for: tab)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }

            sidebarFooter
        }
        .frame(width: SettingsWindowMetrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.11, blue: 0.14),
                    Color(red: 0.08, green: 0.09, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func sidebarButton(for tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.98) : Color.white.opacity(0.72))

                VStack(alignment: .leading, spacing: 3) {
                    Text(tab.sidebarTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.98) : Color.white.opacity(0.82))
                    Text(tab.sidebarDescription)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.65) : Color.white.opacity(0.42))
                }

                Spacer(minLength: 8)

                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    Color(red: 0.21, green: 0.38, blue: 0.73).opacity(0.58),
                                    Color(red: 0.13, green: 0.20, blue: 0.36).opacity(0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.035),
                                    Color.white.opacity(0.015)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(isSelected ? 0.14 : 0.06), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(isSelected ? 0.22 : 0.0), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Copyright © 2026 Het Bhavsar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.54))

            Text("All rights reserved.")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.34))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .overlay(alignment: .top) { cardDivider }
    }

    private func detailPane(metrics: SettingsWindowMetrics) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedTab.detailTitle)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.96))
                    Text(selectedTab.detailSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.54))
                }

                Spacer(minLength: 16)

                valueBadge(headerBadgeText)
            }
            .padding(.horizontal, SettingsWindowMetrics.contentPadding)
            .padding(.vertical, metrics.chromeVerticalPadding)
            .frame(maxWidth: .infinity, minHeight: metrics.chromeRowHeight, alignment: .leading)
            .overlay(alignment: .bottom) { cardDivider }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SettingsWindowMetrics.sectionSpacing) {
                    currentSection
                }
                .padding(.horizontal, SettingsWindowMetrics.contentPadding)
                .padding(.top, SettingsWindowMetrics.sectionSpacing)
                .padding(.bottom, SettingsWindowMetrics.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(footerMeterHeights.enumerated()), id: \.offset) { _, height in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.38, green: 0.68, blue: 1.0),
                                        Color(red: 0.22, green: 0.42, blue: 0.96)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 4, height: height)
                            .opacity(0.78)
                    }
                }

                Text(footerStatusText.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.48))

                Spacer(minLength: 16)

                valueBadge(soundPackManager.activePackDisplayName)
            }
            .padding(.horizontal, SettingsWindowMetrics.contentPadding)
            .frame(height: metrics.footerHeight)
            .overlay(alignment: .top) { cardDivider }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.11),
                        Color(red: 0.05, green: 0.06, blue: 0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color(red: 0.21, green: 0.36, blue: 0.62).opacity(0.28),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 24,
                    endRadius: 420
                )
            }
        )
    }

    @ViewBuilder
    private var currentSection: some View {
        switch selectedTab {
        case .performance:
            performanceSection
        case .acoustics:
            acousticsSection
        case .mixer:
            mixerSection
        case .sounds:
            soundsSection
        case .intelligence:
            intelligenceSection
        case .licensing:
            licensingSection
        }
    }

    private func summaryStrip(items: [(String, String)]) -> some View {
        HStack(spacing: 16) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.0.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color.white.opacity(0.42))
                    Text(item.1)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(SettingsWindowMetrics.cardPadding)
        .background(cardSurface(highlight: Color(red: 0.20, green: 0.34, blue: 0.62).opacity(0.18)))
    }

    private func settingsCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.56))
            }

            VStack(alignment: .leading, spacing: SettingsWindowMetrics.rowSpacing) {
                content()
            }
        }
        .padding(SettingsWindowMetrics.cardPadding)
        .background(cardSurface())
    }

    private func settingRow<Control: View>(
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.46))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: SettingsWindowMetrics.controlLabelWidth, alignment: .leading)

            control()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func mixerRow(
        title: String,
        subtitle: String,
        systemImage: String,
        value: Binding<Float>
    ) -> some View {
        settingRow(title: title, subtitle: subtitle) {
            HStack(spacing: 12) {
                Label("", systemImage: systemImage)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color.white.opacity(0.48))
                    .frame(width: 18)

                Slider(value: value, in: 0...2)
                    .tint(Color(red: 0.40, green: 0.65, blue: 1.0))

                valueBadge("\(Int(value.wrappedValue * 100))%")
            }
        }
    }

    private func valueBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.92))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }

    private func cardSurface(highlight: Color = Color.white.opacity(0.02)) -> some View {
        RoundedRectangle(cornerRadius: SettingsWindowMetrics.cardCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        highlight,
                        Color.white.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsWindowMetrics.cardCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 14)
    }
    
    private func toggleLaunchAtLogin(_ newValue: Bool) {
        do {
            if newValue { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            print("Failed to toggle Launch at Login: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Permissions View
struct PermissionsView: View {
    @ObservedObject var eventManager: EventTapManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 60)
                .foregroundColor(.blue)
            
            Text("Permissions Required")
                .font(.title)
                .bold()
            
            Text("Mecha requires Accessibility permissions to monitor keyboard events system-wide. This allows us to play audio whenever you type anywhere.")
                .multilineTextAlignment(.center)
            
            Text("Privacy Guarantee: Mecha does NOT log your keystrokes, save them to disk, or send them over the internet. Everything runs locally in memory.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Open System Settings") {
                eventManager.openSystemPrefs()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Check Status") {
                eventManager.checkTrust()
                if eventManager.isTrusted {
                    dismiss()
                }
            }
        }
        .padding(30)
        .frame(width: 400, height: 350)
        .onChange(of: eventManager.isTrusted) { _, isNowTrusted in
            if isNowTrusted {
                dismiss()
            }
        }
    }
}
