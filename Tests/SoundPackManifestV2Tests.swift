import Foundation

@main
struct SoundPackManifestV2Tests {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() throws {
        let v2JSON = """
        {
          "manifestVersion": 2,
          "id": "upstream_boxjade",
          "name": "Box Jade",
          "brand": "Upstream",
          "switchType": "Clicky",
          "audio": {
            "sampleRate": 48000,
            "bitDepth": 24,
            "channels": 1
          },
          "rendering": {
            "defaultGainDb": -1.5,
            "stereoWidth": 0.24,
            "pitchJitterCents": 6.0
          },
          "groups": {
            "alphanumeric": {
              "down": ["down/alphanumeric/a_001.wav", "down/alphanumeric/a_002.wav"],
              "up": ["up/alphanumeric/a_up_001.wav"]
            },
            "space": {
              "down": ["down/space/space_001.wav"],
              "up": []
            }
          },
          "fallbacks": {
            "enter": "alphanumeric",
            "modifier": "alphanumeric"
          },
          "coverage": {
            "hasKeyUp": true,
            "groupCount": 2,
            "totalDownSamples": 3,
            "totalUpSamples": 1
          },
          "compatibility": {
            "mode": "legacy-flat"
          }
        }
        """

        let v2Definition = try SoundPackManager.decodePackDefinition(from: Data(v2JSON.utf8))
        expect(v2Definition.id == "upstream_boxjade", "v2 manifest id should decode")
        expect(v2Definition.compatibilityMode == "legacy-flat", "v2 compatibility mode should decode")
        expect(v2Definition.renderingProfile.defaultGainDb == -1.5, "v2 rendering gain should decode")
        expect(v2Definition.renderingProfile.stereoWidth == 0.24, "v2 stereo width should decode")
        expect(v2Definition.downSamples["alphanumeric"]?.count == 2, "v2 down samples should decode")
        expect(v2Definition.upSamples["alphanumeric"]?.count == 1, "v2 up samples should decode")

        let resolvedFallback = SoundPackManager.resolvedGroup(
            for: "enter",
            availableGroups: Set(v2Definition.downSamples.keys),
            fallbacks: v2Definition.fallbacks
        )
        expect(resolvedFallback == "alphanumeric", "fallback group should resolve through manifest fallbacks")

        let richFallback = SoundPackManager.resolvedGroup(
            for: "alphanumeric_left",
            availableGroups: ["alphanumeric"],
            fallbacks: SoundPackManager.defaultFallbacks
        )
        expect(richFallback == "alphanumeric", "rich runtime groups should fall back cleanly into legacy packs")

        let v1JSON = """
        {
          "id": "legacy_red",
          "name": "Legacy Red",
          "brand": "Community",
          "switchType": "Mechanical",
          "sampleRate": 48000,
          "bitDepth": 16,
          "keyVariants": 3,
          "hasKeyUp": false,
          "keyMapping": {
            "alphanumeric": ["alphanumeric_0.wav", "alphanumeric_1.wav"]
          },
          "keyUpMapping": {}
        }
        """

        let v1Definition = try SoundPackManager.decodePackDefinition(from: Data(v1JSON.utf8))
        expect(v1Definition.compatibilityMode == "legacy-v1", "v1 manifests should normalize into explicit legacy compatibility mode")
        expect(v1Definition.downSamples["alphanumeric"]?.count == 2, "v1 key mapping should normalize into down sample groups")

        let bundledCatalogVariant = SoundPackManager.catalogVariant(
            packName: "Cherry MX Blue",
            manifestData: Data(v2JSON.utf8)
        )
        expect(bundledCatalogVariant.brandKey == "cherry", "catalog normalization should extract the Cherry brand")
        expect(bundledCatalogVariant.switchKey == "mx blue", "catalog normalization should extract the MX Blue base switch")
        expect(bundledCatalogVariant.variantLabel == "default", "base pack should normalize into a default variant")
        expect(bundledCatalogVariant.switchType == "clicky", "catalog normalization should classify MX Blue as clicky")

        let absCatalogVariant = SoundPackManager.catalogVariant(
            packName: "Cherrymx Blue Abs",
            manifestData: Data(v2JSON.utf8)
        )
        expect(absCatalogVariant.brandKey == "cherry", "catalog normalization should standardize cherrymx into cherry")
        expect(absCatalogVariant.switchKey == "mx blue", "abs variant should remain under the MX Blue base switch")
        expect(absCatalogVariant.variantLabel == "abs", "abs variant should stay explicit")

        let nkCatalogVariant = SoundPackManager.catalogVariant(
            packName: "Nk Cream",
            manifestData: Data(v2JSON.utf8)
        )
        expect(nkCatalogVariant.brandKey == "novelkeys", "catalog normalization should standardize nk into novelkeys")
        expect(nkCatalogVariant.switchKey == "cream", "novelkeys cream should normalize to the cream base switch")
        expect(nkCatalogVariant.switchType == "linear", "cream should classify as linear")

        let groupedCatalog = SoundPackManager.organizedCatalog(from: [
            bundledCatalogVariant,
            absCatalogVariant,
            nkCatalogVariant
        ])
        expect(groupedCatalog.count == 2, "organized catalog should group entries by normalized brand")
        expect(groupedCatalog.first?.brandKey == "cherry", "catalog brands should sort alphabetically")
        let cherrySwitch = groupedCatalog.first?.switches.first
        expect(cherrySwitch?.name == "mx blue", "grouped catalog should keep the base switch name")
        expect(cherrySwitch?.variants.count == 2, "grouped catalog should preserve separate audio variants")
        expect(cherrySwitch?.variants.first?.displayName == "Cherry MX Blue - Bundled", "default variant should get a disambiguated display label when other variants exist")
        expect(cherrySwitch?.variants.last?.displayName == "Cherry MX Blue - ABS", "explicit variant labels should surface in the display name")

        let fallbackReleaseURL = URL(fileURLWithPath: "/tmp/down.wav")
        let nativeReleaseURL = URL(fileURLWithPath: "/tmp/up.wav")
        let rememberedDownstroke = SelectedSoundSample(sampleGroup: "alphanumeric", playbackGroup: "alphanumeric_left", url: fallbackReleaseURL)
        let nativeRelease = SelectedSoundSample(sampleGroup: "alphanumeric", playbackGroup: "alphanumeric_left", url: nativeReleaseURL)
        expect(SoundPackManager.resolvedKeyUpSample(nativeRelease: nil, fallbackPress: rememberedDownstroke) == nil, "packs without release samples should stay silent on key-up instead of replaying the downstroke")
        expect(SoundPackManager.resolvedKeyUpSample(nativeRelease: nativeRelease, fallbackPress: rememberedDownstroke)?.url == nativeReleaseURL, "native release samples should win over fallback downstrokes")
    }
}
