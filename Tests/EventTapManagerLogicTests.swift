import Foundation

@main
struct EventTapManagerLogicTests {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        expect(
            EventTapManager.resolvedOperationalTrust(systemTrustGranted: false, eventTapExists: true) == false,
            "A preexisting event tap must not be treated as real trust when Accessibility permission is still false"
        )
        expect(
            EventTapManager.shouldContinueTrustPolling(systemTrustGranted: false, eventTapExists: true) == true,
            "Polling should continue while the system still reports trust as false, even if an event tap object already exists"
        )
        expect(
            EventTapManager.shouldRestartTap(previouslyTrusted: false, systemTrustGranted: true, eventTapExists: true) == true,
            "When trust flips on after launch, the manager should rebuild the event tap instead of keeping a possibly stale pre-trust tap"
        )
        expect(
            EventTapManager.shouldRestartTap(previouslyTrusted: true, systemTrustGranted: true, eventTapExists: true) == false,
            "A healthy trusted tap should not be rebuilt on every poll"
        )
    }
}
