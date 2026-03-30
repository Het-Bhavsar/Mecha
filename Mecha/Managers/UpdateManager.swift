import AppKit
import Combine
import Foundation
import Sparkle

@MainActor
final class UpdateManager: NSObject, ObservableObject {
    enum FeedAvailability: Equatable {
        case checking
        case available
        case unavailable(String)
    }

    @Published private(set) var canCheckForUpdates: Bool = false
    @Published private(set) var sessionInProgress: Bool = false
    @Published var automaticallyChecksForUpdates: Bool = false
    @Published private(set) var feedAvailability: FeedAvailability = .checking

    let configuration: UpdateConfiguration

    private let updaterController: SPUStandardUpdaterController
    private var cancellables: Set<AnyCancellable> = []
    private var sparkleCanCheckForUpdates: Bool = false
    private var updaterStarted = false
    private var feedProbeTask: Task<Void, Never>?

    override init() {
        configuration = UpdateConfiguration.fromBundle()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        super.init()
        bindUpdaterState()
        refreshFeedAvailabilityIfNeeded(force: true)
    }

    var feedURLString: String {
        configuration.feedURL.absoluteString
    }

    var feedURL: URL {
        configuration.feedURL
    }

    var updateBehaviorDescription: String {
        if sessionInProgress {
            return "Checking GitHub release updates right now."
        }

        switch feedAvailability {
        case .checking:
            return "Validating the GitHub release feed before enabling updates."
        case .unavailable(let message):
            return message
        case .available:
            break
        }

        return automaticallyChecksForUpdates
            ? "Automatic update checks are enabled for the GitHub release feed."
            : "Automatic checks are off. You can still check manually at any time."
    }

    func checkForUpdates() {
        guard canCheckForUpdates else {
            refreshFeedAvailabilityIfNeeded(force: true)
            return
        }

        updaterController.checkForUpdates(nil)
    }

    func refreshFeedAvailabilityIfNeeded(force: Bool = false) {
        if !force {
            if case .available = feedAvailability {
                return
            }
            if case .checking = feedAvailability {
                return
            }
        }

        guard configuration.hasUsablePublicKey else {
            feedAvailability = .unavailable("Updates are unavailable because this build is missing a valid Sparkle signing key.")
            refreshAvailability()
            return
        }

        feedAvailability = .checking
        refreshAvailability()

        feedProbeTask?.cancel()
        let feedURL = configuration.feedURL
        feedProbeTask = Task { [weak self] in
            let reachable = await Self.probeFeed(at: feedURL)
            await MainActor.run {
                guard let self else { return }
                if reachable {
                    self.feedAvailability = .available
                    self.startUpdaterIfNeeded()
                } else {
                    self.feedAvailability = .unavailable("Updates are unavailable until the GitHub release feed is published.")
                    self.sessionInProgress = false
                }
                self.refreshAvailability()
            }
        }
    }

    private func bindUpdaterState() {
        let updater = updaterController.updater

        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates

        updater.publisher(for: \.canCheckForUpdates, options: [.initial, .new])
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.sparkleCanCheckForUpdates = value
                self?.refreshAvailability()
            }
            .store(in: &cancellables)

        updater.publisher(for: \.sessionInProgress, options: [.initial, .new])
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.sessionInProgress = value
            }
            .store(in: &cancellables)

        $automaticallyChecksForUpdates
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self, weak updater] enabled in
                guard let self else { return }
                guard self.updaterStarted else { return }
                updater?.automaticallyChecksForUpdates = enabled
            }
            .store(in: &cancellables)
    }

    private func startUpdaterIfNeeded() {
        guard !updaterStarted else { return }
        guard Self.shouldStartUpdater(hasUsablePublicKey: configuration.hasUsablePublicKey, isFeedReachable: isFeedReachable) else {
            refreshAvailability()
            return
        }

        let updater = updaterController.updater
        updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates

        do {
            try updater.start()
            updaterStarted = true
            sparkleCanCheckForUpdates = updater.canCheckForUpdates
        } catch {
            feedAvailability = .unavailable(error.localizedDescription)
        }

        refreshAvailability()
    }

    private var isFeedReachable: Bool {
        if case .available = feedAvailability {
            return true
        }
        return false
    }

    private func refreshAvailability() {
        canCheckForUpdates = updaterStarted && sparkleCanCheckForUpdates && isFeedReachable
    }

    static func shouldStartUpdater(hasUsablePublicKey: Bool, isFeedReachable: Bool) -> Bool {
        hasUsablePublicKey && isFeedReachable
    }

    static func isUsableFeedResponse(statusCode: Int, mimeType: String?, bodyPrefix: String) -> Bool {
        guard (200..<300).contains(statusCode) else {
            return false
        }

        let normalizedMimeType = (mimeType ?? "").lowercased()
        let normalizedBodyPrefix = bodyPrefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedMimeType.contains("xml") || normalizedMimeType.contains("rss") {
            return true
        }

        return normalizedBodyPrefix.hasPrefix("<?xml") || normalizedBodyPrefix.hasPrefix("<rss")
    }

    static func probeFeed(at url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }

            let bodyPrefix = String(decoding: data.prefix(256), as: UTF8.self)
            return isUsableFeedResponse(
                statusCode: httpResponse.statusCode,
                mimeType: response.mimeType,
                bodyPrefix: bodyPrefix
            )
        } catch {
            return false
        }
    }
}
