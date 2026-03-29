import Foundation

@main
struct StatsManagerTests {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.formatOptions = [.withInternetDateTime]

        let beforeMidnight = formatter.date(from: "2026-03-30T23:59:30+05:30")!
        let afterMidnight = formatter.date(from: "2026-03-31T00:00:05+05:30")!

        expect(StatsManager.dayStamp(for: beforeMidnight, calendar: calendar) == "2026-03-30", "day stamp should use local calendar boundaries")
        expect(StatsManager.dayStamp(for: afterMidnight, calendar: calendar) == "2026-03-31", "day stamp should advance after local midnight")

        let carriedState = StatsManager.reconciledDailyState(
            storedDayStamp: "2026-03-30",
            storedCount: 128,
            storedEstimatedWPM: 62,
            now: beforeMidnight,
            calendar: calendar
        )
        expect(carriedState.dayStamp == "2026-03-30", "same-day stats should preserve the stored day stamp")
        expect(carriedState.count == 128, "same-day stats should preserve the daily count")
        expect(carriedState.estimatedWPM == 62, "same-day stats should preserve WPM")

        let resetState = StatsManager.reconciledDailyState(
            storedDayStamp: "2026-03-30",
            storedCount: 128,
            storedEstimatedWPM: 62,
            now: afterMidnight,
            calendar: calendar
        )
        expect(resetState.dayStamp == "2026-03-31", "new-day stats should switch to the new day stamp")
        expect(resetState.count == 0, "new-day stats should reset the daily count at local midnight")
        expect(resetState.estimatedWPM == 0, "new-day stats should reset WPM at local midnight")

        let legacyUndatedState = StatsManager.reconciledDailyState(
            storedDayStamp: nil,
            storedCount: 412,
            storedEstimatedWPM: 71,
            now: afterMidnight,
            calendar: calendar
        )
        expect(legacyUndatedState.dayStamp == "2026-03-31", "legacy undated stats should migrate onto the current local day")
        expect(legacyUndatedState.count == 0, "legacy undated stats should reset instead of carrying a stale count into today")
        expect(legacyUndatedState.estimatedWPM == 0, "legacy undated stats should reset WPM instead of preserving stale values")
    }
}
