import Foundation

@main
struct UpdateConfigurationTests {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let configuration = UpdateConfiguration(
            owner: "Het-Bhavsar",
            repository: "Mecha",
            feedBaseURL: URL(string: "https://het-bhavsar.github.io/Mecha")!,
            publicEDKey: "XqX/41XEIYKAzdmOXdwWmYCxOfH5Uk32AKUgOdTv75E="
        )

        expect(configuration.feedURL.absoluteString == "https://het-bhavsar.github.io/Mecha/appcast.xml", "Feed URL should append appcast.xml to the configured base URL")
        expect(configuration.releaseTag(for: "3.0.26") == "v3.0.26", "Release tags should be prefixed with v")
        expect(configuration.releaseAssetName(for: "3.0.26") == "Mecha_v3.0.26.zip", "Updater archives should be versioned zip assets")
        expect(configuration.releaseAssetURL(for: "3.0.26").absoluteString == "https://github.com/Het-Bhavsar/Mecha/releases/download/v3.0.26/Mecha_v3.0.26.zip", "Release asset URLs should target GitHub Releases")
        expect(configuration.releaseNotesURL(for: "3.0.26").absoluteString == "https://github.com/Het-Bhavsar/Mecha/releases/tag/v3.0.26", "Release notes should point at the GitHub release page")
        expect(configuration.hasUsablePublicKey, "A base64-encoded public EdDSA key should be treated as usable")
    }
}
