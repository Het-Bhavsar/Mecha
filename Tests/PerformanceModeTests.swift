import Foundation

@main
struct PerformanceModeTests {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let suiteName = "MechaPerformanceModeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fputs("Failed to create isolated UserDefaults suite\n", stderr)
            exit(1)
        }

        defaults.removePersistentDomain(forName: suiteName)

        expect(AudioEngineManager.resolvedPerformanceMode(from: defaults) == .balanced, "Fresh installs should default to balanced mode")

        defaults.set(PerformanceMode.powerSavings.rawValue, forKey: AudioEngineManager.performanceModeKey)
        expect(AudioEngineManager.resolvedPerformanceMode(from: defaults) == .powerSavings, "Stored performance mode should restore")

        let powerConfig = AudioEngineManager.configuration(for: .powerSavings)
        let balancedConfig = AudioEngineManager.configuration(for: .balanced)
        let zeroLatencyConfig = AudioEngineManager.configuration(for: .zeroLatency)

        expect(powerConfig.activePlayerCount < balancedConfig.activePlayerCount, "Power savings should use a smaller active player pool than balanced")
        expect(balancedConfig.activePlayerCount < zeroLatencyConfig.activePlayerCount, "Balanced should use a smaller active player pool than zero latency")
        expect(powerConfig.idleTimeout ?? 0 < balancedConfig.idleTimeout ?? 0, "Power savings should idle the engine sooner than balanced")
        expect(zeroLatencyConfig.idleTimeout == nil, "Zero latency should keep the engine primed")
        expect(zeroLatencyConfig.keepsEnginePrimed == true, "Zero latency should keep the engine warmed up")
        expect(powerConfig.keepsEnginePrimed == false, "Power savings should allow the engine to idle down")
        expect(powerConfig.statsFlushInterval > 0, "Performance profiles should expose a positive stats flush interval")

        defaults.removePersistentDomain(forName: suiteName)
    }
}
