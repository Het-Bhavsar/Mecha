import Foundation

struct UpdateConfiguration: Equatable {
    let owner: String
    let repository: String
    let feedBaseURL: URL
    let publicEDKey: String

    var feedURL: URL {
        feedBaseURL.appending(path: "appcast.xml")
    }

    var hasUsablePublicKey: Bool {
        guard let data = Data(base64Encoded: publicEDKey) else {
            return false
        }

        return !data.isEmpty
    }

    func releaseTag(for version: String) -> String {
        "v\(version)"
    }

    func releaseAssetName(for version: String) -> String {
        "Mecha_v\(version).zip"
    }

    func releaseAssetURL(for version: String) -> URL {
        let tag = releaseTag(for: version)
        let assetName = releaseAssetName(for: version)
        return URL(string: "https://github.com/\(owner)/\(repository)/releases/download/\(tag)/\(assetName)")!
    }

    func releaseNotesURL(for version: String) -> URL {
        URL(string: "https://github.com/\(owner)/\(repository)/releases/tag/\(releaseTag(for: version))")!
    }

    static func fromEnvironment(_ environment: [String: String]) -> UpdateConfiguration {
        let owner = environment["GITHUB_OWNER"] ?? "Het-Bhavsar"
        let repository = environment["GITHUB_REPO"] ?? "Mecha"
        let baseURLString = environment["APPCAST_BASE_URL"] ?? "https://het-bhavsar.github.io/Mecha"
        let baseURL = URL(string: baseURLString) ?? URL(string: "https://het-bhavsar.github.io/Mecha")!
        let publicKey = environment["SPARKLE_PUBLIC_ED_KEY"] ?? ""

        return UpdateConfiguration(
            owner: owner,
            repository: repository,
            feedBaseURL: baseURL,
            publicEDKey: publicKey
        )
    }

    static func fromBundle(_ bundle: Bundle = .main) -> UpdateConfiguration {
        var environment: [String: String] = [:]

        for key in ["GITHUB_OWNER", "GITHUB_REPO", "APPCAST_BASE_URL", "SUPublicEDKey"] {
            if let value = bundle.object(forInfoDictionaryKey: key) as? String, !value.isEmpty {
                environment[key == "SUPublicEDKey" ? "SPARKLE_PUBLIC_ED_KEY" : key] = value
            }
        }

        return UpdateConfiguration.fromEnvironment(environment)
    }
}
