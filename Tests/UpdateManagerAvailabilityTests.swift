import Foundation

@main
struct UpdateManagerAvailabilityTests {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        expect(
            UpdateManager.isUsableFeedResponse(statusCode: 200, mimeType: "application/rss+xml", bodyPrefix: "<?xml version=\"1.0\"?><rss"),
            "RSS/XML responses should be accepted as valid update feeds"
        )
        expect(
            UpdateManager.isUsableFeedResponse(statusCode: 200, mimeType: "text/xml", bodyPrefix: "<rss"),
            "text/xml responses should also be accepted"
        )
        expect(
            !UpdateManager.isUsableFeedResponse(statusCode: 404, mimeType: "text/html", bodyPrefix: "<!doctype html>"),
            "404 HTML responses should not be treated as a usable appcast"
        )
        expect(
            !UpdateManager.isUsableFeedResponse(statusCode: 200, mimeType: "text/html", bodyPrefix: "<html>"),
            "HTML content should not be treated as a usable appcast even on 200 responses"
        )
        expect(
            UpdateManager.shouldStartUpdater(hasUsablePublicKey: true, isFeedReachable: true),
            "Updater should start when the signing key and feed are both ready"
        )
        expect(
            !UpdateManager.shouldStartUpdater(hasUsablePublicKey: false, isFeedReachable: true),
            "Updater should stay disabled without a usable signing key"
        )
        expect(
            !UpdateManager.shouldStartUpdater(hasUsablePublicKey: true, isFeedReachable: false),
            "Updater should stay disabled when the feed is unavailable"
        )
    }
}
