import Foundation

// MARK: - Manifest Schema

struct SoundPackManifestV1: Codable {
    let id: String
    let name: String
    let brand: String
    let switchType: String
    let sampleRate: Int
    let bitDepth: Int
    let keyVariants: Int
    let hasKeyUp: Bool
    let keyMapping: [String: [String]]
    let keyUpMapping: [String: String]
}

private struct LegacyManifest: Codable {
    let name: String
    let author: String?
    let description: String?
    let switchType: String?
}

struct SoundPackManifestV2: Codable {
    let manifestVersion: Int
    let id: String
    let name: String
    let brand: String
    let switchType: String
    let description: String?
    let audio: SoundPackAudioMetadata
    let rendering: SoundPackRenderingHints?
    let groups: [String: SoundPackSampleGroup]
    let fallbacks: [String: String]?
    let coverage: SoundPackCoverage
    let compatibility: SoundPackCompatibilityMetadata?
}

struct SoundPackAudioMetadata: Codable {
    let sampleRate: Int
    let bitDepth: Int
    let channels: Int?
    let loudnessLUFS: Float?
    let peakDbfs: Float?
}

struct SoundPackRenderingHints: Codable {
    let defaultGainDb: Float?
    let stereoWidth: Float?
    let pitchJitterCents: Float?
    let timingJitterMs: Float?
    let releaseBlend: Float?
}

struct SoundPackSampleGroup: Codable {
    let down: [String]
    let up: [String]
}

struct SoundPackCoverage: Codable {
    let hasKeyUp: Bool
    let groupCount: Int?
    let totalDownSamples: Int?
    let totalUpSamples: Int?
    let tier: String?
}

struct SoundPackCompatibilityMetadata: Codable {
    let mode: String
    let source: String?
    let notes: String?
}

struct SoundPackRenderingProfile: Equatable {
    let defaultGainDb: Float
    let stereoWidth: Float
    let pitchJitterCents: Float
    let timingJitterMs: Float
    let releaseBlend: Float

    static let `default` = SoundPackRenderingProfile(
        defaultGainDb: 0,
        stereoWidth: 0.12,
        pitchJitterCents: 3,
        timingJitterMs: 0,
        releaseBlend: 0
    )
}

struct DecodedSoundPackDefinition {
    let id: String
    let name: String
    let brand: String
    let switchType: String
    let compatibilityMode: String
    let downSamples: [String: [String]]
    let upSamples: [String: [String]]
    let fallbacks: [String: String]
    let renderingProfile: SoundPackRenderingProfile
}

struct SelectedSoundSample {
    let sampleGroup: String
    let playbackGroup: String
    let url: URL
}

struct SoundPackCatalogVariant: Identifiable, Hashable {
    let packName: String
    let brandKey: String
    let brandDisplayName: String
    let switchKey: String
    let switchDisplayName: String
    let switchType: String
    let variantLabel: String
    let displayName: String
    let source: String
    let datasetMode: String
    let sampleCount: Int
    let groupCount: Int
    let hasKeyUp: Bool
    let qualityTier: String

    var id: String { packName }
}

struct SoundPackCatalogSwitch: Identifiable, Hashable {
    let brandKey: String
    let name: String
    let displayName: String
    let type: String
    let variants: [SoundPackCatalogVariant]

    var id: String { "\(brandKey):\(name)" }
}

struct SoundPackCatalogBrand: Identifiable, Hashable {
    let brandKey: String
    let displayName: String
    let switches: [SoundPackCatalogSwitch]

    var id: String { brandKey }
}

private struct SoundPackCatalogManifestSnapshot {
    let source: String
    let datasetMode: String
    let sampleCount: Int
    let groupCount: Int
    let hasKeyUp: Bool
    let qualityTier: String

    static let `default` = SoundPackCatalogManifestSnapshot(
        source: "unknown",
        datasetMode: "unknown",
        sampleCount: 0,
        groupCount: 0,
        hasKeyUp: false,
        qualityTier: "legacy"
    )
}

private struct ResolvedSoundPackAssets {
    let downPaths: [String: [URL]]
    let upPaths: [String: [URL]]
    let genericKeyUpURL: URL?
    let fallbacks: [String: String]
    let renderingProfile: SoundPackRenderingProfile
}

// MARK: - Sound Pack Manager

class SoundPackManager: ObservableObject {
    static let defaultFallbacks: [String: String] = [
        "space": "alphanumeric",
        "enter": "alphanumeric",
        "backspace": "alphanumeric",
        "modifier": "alphanumeric",
        "arrow": "alphanumeric",
        "tab": "modifier_left",
        "escape": "tab",
        "caps_lock": "modifier_left",
        "modifier_left": "modifier",
        "modifier_right": "modifier",
        "function": "number_row",
        "number_row": "alphanumeric",
        "alphanumeric_left": "alphanumeric",
        "alphanumeric_right": "alphanumeric",
        "punctuation": "alphanumeric_right",
        "navigation": "arrow",
        "numpad": "alphanumeric",
        "system": "modifier"
    ]

    @Published var installedPacks: [String] = []
    @Published var activePackName: String = "Cherry MX Blue" {
        didSet {
            UserDefaults.standard.set(activePackName, forKey: "ActivePack")
            loadPack(name: activePackName)
        }
    }
    @Published var isSwitching: Bool = false
    @Published var activeRenderingProfile: SoundPackRenderingProfile = .default
    @Published var packCatalog: [SoundPackCatalogBrand] = []
    @Published var installedPackVariants: [SoundPackCatalogVariant] = []

    /// Key-type string → array of file URLs for random selection
    var activeSoundPaths: [String: [URL]] = [:]

    /// Key-type string → array of key-up URLs for random selection
    var activeKeyUpPaths: [String: [URL]] = [:]

    /// Fallback generic keyup URL
    var genericKeyUpURL: URL?

    /// Logical group fallback map
    var groupFallbacks: [String: String] = SoundPackManager.defaultFallbacks

    var activePackVariant: SoundPackCatalogVariant? {
        installedPackVariants.first(where: { $0.packName == activePackName })
    }

    var activePackDisplayName: String {
        activePackVariant?.displayName ?? activePackName
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "ActivePack") {
            self.activePackName = saved
        }
        scanForPacks()
        loadPack(name: activePackName)
    }

    // MARK: - Runtime Helpers

    static func decodePackDefinition(from data: Data) throws -> DecodedSoundPackDefinition {
        if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = object["manifestVersion"] as? Int,
           version >= 2 {
            let manifest = try JSONDecoder().decode(SoundPackManifestV2.self, from: data)
            let fallbacks = Self.defaultFallbacks.merging(manifest.fallbacks ?? [:]) { _, new in new }
            let rendering = SoundPackRenderingProfile(
                defaultGainDb: manifest.rendering?.defaultGainDb ?? 0,
                stereoWidth: manifest.rendering?.stereoWidth ?? SoundPackRenderingProfile.default.stereoWidth,
                pitchJitterCents: manifest.rendering?.pitchJitterCents ?? SoundPackRenderingProfile.default.pitchJitterCents,
                timingJitterMs: manifest.rendering?.timingJitterMs ?? 0,
                releaseBlend: manifest.rendering?.releaseBlend ?? 0
            )

            return DecodedSoundPackDefinition(
                id: manifest.id,
                name: manifest.name,
                brand: manifest.brand,
                switchType: manifest.switchType,
                compatibilityMode: manifest.compatibility?.mode ?? "native-v2",
                downSamples: manifest.groups.mapValues(\.down),
                upSamples: manifest.groups.reduce(into: [:]) { result, entry in
                    if !entry.value.up.isEmpty {
                        result[entry.key] = entry.value.up
                    }
                },
                fallbacks: fallbacks,
                renderingProfile: rendering
            )
        }

        let manifest = try JSONDecoder().decode(SoundPackManifestV1.self, from: data)
        let upGroups = manifest.keyUpMapping.reduce(into: [String: [String]]()) { result, entry in
            result[entry.key] = [entry.value]
        }

        return DecodedSoundPackDefinition(
            id: manifest.id,
            name: manifest.name,
            brand: manifest.brand,
            switchType: manifest.switchType,
            compatibilityMode: "legacy-v1",
            downSamples: manifest.keyMapping,
            upSamples: upGroups,
            fallbacks: Self.defaultFallbacks,
            renderingProfile: .default
        )
    }

    static func resolvedGroup(
        for requestedGroup: String,
        availableGroups: Set<String>,
        fallbacks: [String: String]
    ) -> String? {
        if availableGroups.contains(requestedGroup) {
            return requestedGroup
        }

        var visited = Set<String>()
        var current = requestedGroup

        while let next = fallbacks[current], !visited.contains(next) {
            if availableGroups.contains(next) {
                return next
            }
            visited.insert(current)
            current = next
        }

        if availableGroups.contains("alphanumeric") {
            return "alphanumeric"
        }

        return availableGroups.first
    }

    private static func resolvedURLs(
        for relativePaths: [String],
        packDir: URL
    ) -> [URL] {
        relativePaths.compactMap { relativePath in
            let url = packDir.appendingPathComponent(relativePath)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    private static func decodePackAssets(at packDir: URL) -> ResolvedSoundPackAssets? {
        let manifestURL = packDir.appendingPathComponent("manifest.json")

        if let data = try? Data(contentsOf: manifestURL),
           let definition = try? decodePackDefinition(from: data) {
            let downPaths = definition.downSamples.reduce(into: [String: [URL]]()) { result, entry in
                let urls = resolvedURLs(for: entry.value, packDir: packDir)
                if !urls.isEmpty {
                    result[entry.key] = urls
                }
            }
            let upPaths = definition.upSamples.reduce(into: [String: [URL]]()) { result, entry in
                let urls = resolvedURLs(for: entry.value, packDir: packDir)
                if !urls.isEmpty {
                    result[entry.key] = urls
                }
            }

            let genericKeyUpURL: URL?
            let fallbackKeyUp = packDir.appendingPathComponent("keyup.wav")
            if FileManager.default.fileExists(atPath: fallbackKeyUp.path) {
                genericKeyUpURL = fallbackKeyUp
            } else {
                genericKeyUpURL = nil
            }

            return ResolvedSoundPackAssets(
                downPaths: downPaths,
                upPaths: upPaths,
                genericKeyUpURL: genericKeyUpURL,
                fallbacks: definition.fallbacks,
                renderingProfile: definition.renderingProfile
            )
        }

        return legacyConventionAssets(at: packDir)
    }

    private static func legacyConventionAssets(at packDir: URL) -> ResolvedSoundPackAssets? {
        var downPaths: [String: [URL]] = [:]
        var upPaths: [String: [URL]] = [:]

        guard let enumerator = FileManager.default.enumerator(at: packDir, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return nil
        }

        let urls = enumerator.allObjects.compactMap { $0 as? URL }
        for fileURL in urls where fileURL.pathExtension.lowercased() == "wav" {
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            let components = fileName.split(separator: "_")
            guard let keyGroup = components.first else { continue }
            let groupString = String(keyGroup)

            if groupString.hasSuffix("-up") || fileName == "keyup" {
                let baseGroup = groupString.replacingOccurrences(of: "-up", with: "")
                upPaths[baseGroup, default: []].append(fileURL)
            } else {
                downPaths[groupString, default: []].append(fileURL)
            }
        }

        let genericKeyUpURL: URL?
        let keyupURL = packDir.appendingPathComponent("keyup.wav")
        if FileManager.default.fileExists(atPath: keyupURL.path) {
            genericKeyUpURL = keyupURL
        } else {
            genericKeyUpURL = nil
        }

        return ResolvedSoundPackAssets(
            downPaths: downPaths,
            upPaths: upPaths,
            genericKeyUpURL: genericKeyUpURL,
            fallbacks: Self.defaultFallbacks,
            renderingProfile: .default
        )
    }

    static func catalogVariant(packName: String, manifestData: Data?) -> SoundPackCatalogVariant {
        let snapshot = catalogManifestSnapshot(from: manifestData)
        let seed = catalogSeed(for: packName)
        let brandDisplayName = brandDisplayName(for: seed.brandKey)
        let switchDisplayName = switchDisplayName(for: seed.switchKey)

        return SoundPackCatalogVariant(
            packName: packName,
            brandKey: seed.brandKey,
            brandDisplayName: brandDisplayName,
            switchKey: seed.switchKey,
            switchDisplayName: switchDisplayName,
            switchType: switchType(for: seed.switchKey),
            variantLabel: seed.variantLabel,
            displayName: catalogDisplayName(
                brandDisplayName: brandDisplayName,
                switchDisplayName: switchDisplayName,
                variantLabel: seed.variantLabel,
                variantCount: 1
            ),
            source: snapshot.source,
            datasetMode: snapshot.datasetMode,
            sampleCount: snapshot.sampleCount,
            groupCount: snapshot.groupCount,
            hasKeyUp: snapshot.hasKeyUp,
            qualityTier: snapshot.qualityTier
        )
    }

    static func organizedCatalog(from variants: [SoundPackCatalogVariant]) -> [SoundPackCatalogBrand] {
        let brands = Dictionary(grouping: variants, by: \.brandKey)

        return brands.keys.sorted().map { brandKey in
            let brandVariants = brands[brandKey, default: []]
            let switches = Dictionary(grouping: brandVariants, by: \.switchKey)

            let catalogSwitches = switches.keys.sorted().compactMap { switchKey -> SoundPackCatalogSwitch? in
                let switchVariants = switches[switchKey]?.sorted(by: { lhs, rhs in
                    let leftRank = variantSortRank(for: lhs.variantLabel)
                    let rightRank = variantSortRank(for: rhs.variantLabel)
                    if leftRank != rightRank {
                        return leftRank < rightRank
                    }
                    return lhs.packName < rhs.packName
                }) ?? []

                guard let firstVariant = switchVariants.first else {
                    return nil
                }

                let displayVariants = switchVariants.map { variant in
                    SoundPackCatalogVariant(
                        packName: variant.packName,
                        brandKey: variant.brandKey,
                        brandDisplayName: variant.brandDisplayName,
                        switchKey: variant.switchKey,
                        switchDisplayName: variant.switchDisplayName,
                        switchType: variant.switchType,
                        variantLabel: variant.variantLabel,
                        displayName: catalogDisplayName(
                            brandDisplayName: variant.brandDisplayName,
                            switchDisplayName: variant.switchDisplayName,
                            variantLabel: variant.variantLabel,
                            variantCount: switchVariants.count
                        ),
                        source: variant.source,
                        datasetMode: variant.datasetMode,
                        sampleCount: variant.sampleCount,
                        groupCount: variant.groupCount,
                        hasKeyUp: variant.hasKeyUp,
                        qualityTier: variant.qualityTier
                    )
                }

                return SoundPackCatalogSwitch(
                    brandKey: brandKey,
                    name: switchKey,
                    displayName: firstVariant.switchDisplayName,
                    type: firstVariant.switchType,
                    variants: displayVariants
                )
            }

            return SoundPackCatalogBrand(
                brandKey: brandKey,
                displayName: brandDisplayName(for: brandKey),
                switches: catalogSwitches
            )
        }
    }

    private static func catalogManifestSnapshot(from data: Data?) -> SoundPackCatalogManifestSnapshot {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .default
        }

        let compatibility = object["compatibility"] as? [String: Any]
        let coverage = object["coverage"] as? [String: Any]

        return SoundPackCatalogManifestSnapshot(
            source: compatibility?["source"] as? String ?? "unknown",
            datasetMode: compatibility?["mode"] as? String ?? "unknown",
            sampleCount: coverage?["totalDownSamples"] as? Int ?? 0,
            groupCount: coverage?["groupCount"] as? Int ?? 0,
            hasKeyUp: coverage?["hasKeyUp"] as? Bool ?? false,
            qualityTier: coverage?["tier"] as? String ?? "legacy"
        )
    }

    private static func catalogSeed(for packName: String) -> (brandKey: String, switchKey: String, variantLabel: String) {
        let rawNormalized = packName
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizedPackName(packName)

        if normalized == "apex pro" {
            return ("steelseries", "omnipoint", "apex pro")
        }

        if normalized.contains("razer green") {
            let variant = rawNormalized
                .replacingOccurrences(of: "razer green", with: "")
                .replacingOccurrences(of: #"[\(\)]"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ("razer", "green", variant.isEmpty ? "default" : variant)
        }

        if normalized.contains("holy panda") {
            return ("drop / invyr", "holy panda", "default")
        }

        if normalized == "creams" {
            return ("novelkeys", "cream", "creams dataset")
        }

        if rawNormalized.hasPrefix("nk cream") {
            return ("novelkeys", "cream", "nk mapped")
        }

        if normalized == "novelkeys cream" {
            return ("novelkeys", "cream", "default")
        }

        if normalized == "box jade" {
            return ("kailh", "box jade", "default")
        }

        if normalized == "akko lavender purple" {
            return ("akko", "lavender purple", "default")
        }

        if normalized == "eg crystal purple" {
            return ("everglide", "crystal purple", "default")
        }

        if normalized == "eg oreo" {
            return ("everglide", "oreo", "default")
        }

        if normalized.hasPrefix("banana split") {
            if normalized.contains("lubed") {
                return ("c3 equalz", "banana split", "lubed")
            }
            if normalized.contains("stock") {
                return ("c3 equalz", "banana split", "stock")
            }
            return ("c3 equalz", "banana split", "default")
        }

        if normalized.hasPrefix("topre purple hybrid") {
            let variant = normalized.hasSuffix(" pbt") ? "pbt" : "default"
            return ("topre", "purple hybrid", variant)
        }

        if normalized == "mx speed silver" {
            return ("cherry", "mx speed silver", "default")
        }

        if normalized.hasPrefix("cherry mx ") {
            let remainder = String(normalized.dropFirst("cherry mx ".count))
            let tokens = remainder.split(separator: " ").map(String.init)
            let knownVariants = Set(["abs", "pbt"])
            let variant = knownVariants.contains(tokens.last ?? "") ? tokens.last! : "default"
            let baseTokens = variant == "default" ? tokens : Array(tokens.dropLast())
            return ("cherry", "mx \(baseTokens.joined(separator: " "))", variant)
        }

        let tokens = normalized.split(separator: " ").map(String.init)
        guard let brand = tokens.first else {
            return ("community", normalized, "default")
        }

        let knownVariants = Set(["abs", "pbt", "lubed", "stock"])
        let variant = knownVariants.contains(tokens.last ?? "") ? tokens.last! : "default"
        let switchTokens = variant == "default" ? Array(tokens.dropFirst()) : Array(tokens.dropFirst().dropLast())
        return (brand, switchTokens.joined(separator: " "), variant)
    }

    private static func normalizedPackName(_ packName: String) -> String {
        packName
            .lowercased()
            .replacingOccurrences(of: "cherrymx", with: "cherry mx")
            .replacingOccurrences(of: #"\bnk\b"#, with: "novelkeys", options: .regularExpression)
            .replacingOccurrences(of: "boxjade", with: "box jade")
            .replacingOccurrences(of: "lavender purples", with: "lavender purple")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func brandDisplayName(for brandKey: String) -> String {
        switch brandKey {
        case "c3 equalz":
            return "C3 Equalz"
        case "drop / invyr":
            return "Drop / Invyr"
        case "novelkeys":
            return "NovelKeys"
        case "steelseries":
            return "SteelSeries"
        default:
            return titleCasedText(brandKey)
        }
    }

    private static func switchDisplayName(for switchKey: String) -> String {
        switch switchKey {
        case "mx blue":
            return "MX Blue"
        case "mx brown":
            return "MX Brown"
        case "mx red":
            return "MX Red"
        case "mx black":
            return "MX Black"
        case "mx speed silver":
            return "MX Speed Silver"
        case "holy panda":
            return "Holy Panda"
        case "box jade":
            return "Box Jade"
        case "crystal purple":
            return "Crystal Purple"
        case "purple hybrid":
            return "Purple Hybrid"
        case "omnipoint":
            return "OmniPoint"
        default:
            return titleCasedText(switchKey)
        }
    }

    private static func switchType(for switchKey: String) -> String {
        if switchKey.contains("blue") || switchKey.contains("green") || switchKey.contains("jade") {
            return "clicky"
        }
        if switchKey.contains("brown") || switchKey.contains("panda") || switchKey.contains("lavender") || switchKey.contains("oreo") || switchKey.contains("purple") || switchKey.contains("topre") {
            return "tactile"
        }
        if switchKey.contains("red") || switchKey.contains("black") || switchKey.contains("silver") || switchKey.contains("cream") || switchKey.contains("banana split") || switchKey.contains("omnipoint") {
            return "linear"
        }
        return "linear"
    }

    private static func catalogDisplayName(
        brandDisplayName: String,
        switchDisplayName: String,
        variantLabel: String,
        variantCount: Int
    ) -> String {
        let baseName = "\(brandDisplayName) \(switchDisplayName)"
        let label = variantDisplayName(for: variantLabel, variantCount: variantCount)
        guard !label.isEmpty else {
            return baseName
        }
        return "\(baseName) - \(label)"
    }

    private static func variantDisplayName(for variantLabel: String, variantCount: Int) -> String {
        switch variantLabel {
        case "default":
            return variantCount > 1 ? "Bundled" : ""
        case "abs":
            return "ABS"
        case "pbt":
            return "PBT"
        case "nk mapped":
            return "NK Mapped"
        case "creams dataset":
            return "Creams Dataset"
        case "apex pro":
            return "Apex Pro"
        default:
            return titleCasedText(variantLabel)
        }
    }

    private static func variantSortRank(for variantLabel: String) -> Int {
        switch variantLabel {
        case "default":
            return 0
        case "bundled":
            return 1
        case "abs":
            return 2
        case "pbt":
            return 3
        case "lubed":
            return 4
        case "stock":
            return 5
        default:
            return 10
        }
    }

    private static func titleCasedText(_ value: String) -> String {
        value
            .split(separator: " ")
            .map { word in
                switch word.lowercased() {
                case "mx":
                    return "MX"
                case "abs":
                    return "ABS"
                case "pbt":
                    return "PBT"
                case "nk":
                    return "NK"
                default:
                    return word.prefix(1).uppercased() + word.dropFirst().lowercased()
                }
            }
            .joined(separator: " ")
    }

    // MARK: - Pack Discovery

    private func scanForPacks() {
        guard let packDir = Bundle.main.url(forResource: "SoundPacks", withExtension: nil) else {
            print("[SoundPackManager] No SoundPacks directory found in bundle")
            return
        }

        do {
            let packDirectories = try FileManager.default
                .contentsOfDirectory(at: packDir, includingPropertiesForKeys: [.isDirectoryKey])
                .filter(\.hasDirectoryPath)

            let catalogVariants = packDirectories.map { packDirectory in
                let manifestURL = packDirectory.appendingPathComponent("manifest.json")
                let manifestData = try? Data(contentsOf: manifestURL)
                return Self.catalogVariant(
                    packName: packDirectory.lastPathComponent,
                    manifestData: manifestData
                )
            }

            let organizedCatalog = Self.organizedCatalog(from: catalogVariants)
            let orderedVariants = organizedCatalog.flatMap { brand in
                brand.switches.flatMap(\.variants)
            }

            packCatalog = organizedCatalog
            installedPackVariants = orderedVariants
            installedPacks = orderedVariants.map(\.packName)

            if !installedPacks.contains(activePackName), let firstPack = installedPacks.first {
                activePackName = firstPack
            }
        } catch {
            print("[SoundPackManager] Failed to scan for packs: \(error)")
        }
    }

    // MARK: - Pack Loading

    private func loadPack(name: String) {
        Task { @MainActor in
            self.isSwitching = true

            let resolvedAssets = await Task.detached(priority: .userInitiated) { () -> ResolvedSoundPackAssets? in
                print("[SoundPackManager] v3.1.0 Shifting to: \(name)...")

                guard let packDir = Bundle.main.url(forResource: "SoundPacks/\(name)", withExtension: nil) else {
                    print("[SoundPackManager] Pack directory not found: \(name)")
                    return nil
                }

                return Self.decodePackAssets(at: packDir)
            }.value

            if let resolvedAssets {
                self.activeSoundPaths = resolvedAssets.downPaths
                self.activeKeyUpPaths = resolvedAssets.upPaths
                self.genericKeyUpURL = resolvedAssets.genericKeyUpURL
                self.groupFallbacks = resolvedAssets.fallbacks
                self.activeRenderingProfile = resolvedAssets.renderingProfile
            }

            self.isSwitching = false
            print("[SoundPackManager] Shift Complete: \(name)")
        }
    }

    // MARK: - Sound Selection

    func getRandomDownSound(for keyType: String) -> SelectedSoundSample? {
        let availableGroups = Set(activeSoundPaths.keys)
        guard let resolvedKey = Self.resolvedGroup(for: keyType, availableGroups: availableGroups, fallbacks: groupFallbacks) else {
            return nil
        }

        guard let url = activeSoundPaths[resolvedKey]?.randomElement() else {
            return nil
        }

        return SelectedSoundSample(sampleGroup: resolvedKey, playbackGroup: keyType, url: url)
    }

    func getUpSound(for keyType: String) -> SelectedSoundSample? {
        let availableGroups = Set(activeKeyUpPaths.keys)
        if let resolvedKey = Self.resolvedGroup(for: keyType, availableGroups: availableGroups, fallbacks: groupFallbacks),
           let url = activeKeyUpPaths[resolvedKey]?.randomElement() {
            return SelectedSoundSample(sampleGroup: resolvedKey, playbackGroup: keyType, url: url)
        }

        guard let genericKeyUpURL else {
            return nil
        }

        return SelectedSoundSample(sampleGroup: "generic-up", playbackGroup: keyType, url: genericKeyUpURL)
    }

    static func resolvedKeyUpSample(
        nativeRelease: SelectedSoundSample?,
        fallbackPress _: SelectedSoundSample?
    ) -> SelectedSoundSample? {
        nativeRelease
    }

    /// Returns all sound URLs for the current pack (for pre-buffering)
    func allSoundURLs() -> [URL] {
        var urls: [URL] = []
        for paths in activeSoundPaths.values {
            urls.append(contentsOf: paths)
        }
        for paths in activeKeyUpPaths.values {
            urls.append(contentsOf: paths)
        }
        if let generic = genericKeyUpURL {
            urls.append(generic)
        }
        return urls
    }
}
