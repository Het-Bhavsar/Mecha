import StoreKit
import SwiftUI
import AppKit

// MARK: - Store Manager
class StoreManager: ObservableObject {
    @Published var isUnlocked: Bool = false
    @Published var trialDaysRemaining: Int = 3
    
    // We will track the trial in UserDefaults for this prototype.
    // In production, use Keychain or server validation to avoid simple resets.
    
    init() {
        checkTrialStatus()
        Task { await updatePurchasedStatus() }
    }
    
    private func checkTrialStatus() {
        let trialStart = UserDefaults.standard.double(forKey: "TrialStartDate")
        
        if trialStart == 0 {
            // First Launch
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "TrialStartDate")
            trialDaysRemaining = 3
            isUnlocked = true
        } else {
            let passedDays = (Date().timeIntervalSince1970 - trialStart) / 86400
            let remaining = max(0, 3 - Int(passedDays))
            
            trialDaysRemaining = remaining
            if remaining == 0 {
                // Trial over
                isUnlocked = false
            } else {
                isUnlocked = true
            }
        }
    }
    
    // StoreKit 2 Stub
    func updatePurchasedStatus() async {
        // Query App Store for "com.yourcompany.clackmac.lifetime"
        // if user owns it:
        // DispatchQueue.main.async { self.isUnlocked = true }
    }
    
    func purchaseUnlock() {
        // Trigger StoreKit 2 purchase sheet here
        // Upon success, flip `isUnlocked = true` and maybe hide trial UI
        
        // Mock success
        self.isUnlocked = true
    }
    
    func restorePurchases() {
        Task { await updatePurchasedStatus() }
    }
}

// MARK: - Stats Manager (V2 Stub)
struct DailyStatsState {
    let dayStamp: String
    let count: Int
    let estimatedWPM: Int
}

class StatsManager: ObservableObject {
    static let dailyKeystrokesKey = "DailyKeystrokes"
    static let dailyKeystrokesDateKey = "DailyKeystrokesDate"
    static let estimatedWPMKey = "DailyEstimatedWPM"

    @Published var dailyKeystrokes: Int = 0
    @Published var estimatedWPM: Int = 0

    private let defaults: UserDefaults
    private let calendar: Calendar
    private var currentDayStamp: String = ""
    private var dayChangeObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var appDidBecomeActiveObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var persistenceTimer: Timer?
    private var persistenceInterval: TimeInterval = 4
    
    init(defaults: UserDefaults = .standard, calendar: Calendar = .autoupdatingCurrent) {
        self.defaults = defaults
        self.calendar = calendar
        loadStats()
        observeDayChange()
    }

    deinit {
        flushPendingStats()
        if let dayChangeObserver {
            NotificationCenter.default.removeObserver(dayChangeObserver)
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        if let appDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(appDidBecomeActiveObserver)
        }
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }

    static func dayStamp(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func reconciledDailyState(
        storedDayStamp: String?,
        storedCount: Int,
        storedEstimatedWPM: Int,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DailyStatsState {
        let todayStamp = dayStamp(for: now, calendar: calendar)
        guard let storedDayStamp, !storedDayStamp.isEmpty else {
            return DailyStatsState(
                dayStamp: todayStamp,
                count: 0,
                estimatedWPM: 0
            )
        }

        guard storedDayStamp == todayStamp else {
            return DailyStatsState(dayStamp: todayStamp, count: 0, estimatedWPM: 0)
        }

        return DailyStatsState(
            dayStamp: todayStamp,
            count: max(0, storedCount),
            estimatedWPM: max(0, storedEstimatedWPM)
        )
    }

    func incrementKeystroke(at date: Date = Date()) {
        let applyIncrement = {
            self.reconcileStatsIfNeeded(now: date)
            self.dailyKeystrokes += 1
            self.schedulePersistence()
            
            // Simple WPM fake logic
            if self.dailyKeystrokes % 50 == 0 {
                self.estimatedWPM = Int.random(in: 40...85)
                self.schedulePersistence()
            }
        }

        if Thread.isMainThread {
            applyIncrement()
        } else {
            DispatchQueue.main.async(execute: applyIncrement)
        }
    }

    func updatePersistenceInterval(_ interval: TimeInterval) {
        let sanitized = max(1, interval)
        persistenceInterval = sanitized
        if persistenceTimer != nil {
            schedulePersistence()
        }
    }

    func refreshIfNeeded(now: Date = Date()) {
        let refresh = {
            self.reconcileStatsIfNeeded(now: now)
        }

        if Thread.isMainThread {
            refresh()
        } else {
            DispatchQueue.main.async(execute: refresh)
        }
    }

    private func observeDayChange() {
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshIfNeeded(now: Date())
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshIfNeeded(now: Date())
        }

        appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshIfNeeded(now: Date())
        }

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushPendingStats()
        }
    }

    private func loadStats(now: Date = Date()) {
        let resolvedState = Self.reconciledDailyState(
            storedDayStamp: defaults.string(forKey: Self.dailyKeystrokesDateKey),
            storedCount: defaults.integer(forKey: Self.dailyKeystrokesKey),
            storedEstimatedWPM: defaults.integer(forKey: Self.estimatedWPMKey),
            now: now,
            calendar: calendar
        )
        apply(state: resolvedState, persist: true)
    }

    private func reconcileStatsIfNeeded(now: Date) {
        let resolvedState = Self.reconciledDailyState(
            storedDayStamp: currentDayStamp,
            storedCount: dailyKeystrokes,
            storedEstimatedWPM: estimatedWPM,
            now: now,
            calendar: calendar
        )

        guard resolvedState.dayStamp != currentDayStamp ||
                resolvedState.count != dailyKeystrokes ||
                resolvedState.estimatedWPM != estimatedWPM else {
            return
        }

        apply(state: resolvedState, persist: true)
    }

    private func apply(state: DailyStatsState, persist: Bool) {
        currentDayStamp = state.dayStamp
        dailyKeystrokes = state.count
        estimatedWPM = state.estimatedWPM

        if persist {
            persistCurrentStats()
        }
    }

    private func persistCurrentStats() {
        defaults.set(currentDayStamp, forKey: Self.dailyKeystrokesDateKey)
        defaults.set(dailyKeystrokes, forKey: Self.dailyKeystrokesKey)
        defaults.set(estimatedWPM, forKey: Self.estimatedWPMKey)
    }

    private func schedulePersistence() {
        persistenceTimer?.invalidate()
        persistenceTimer = Timer.scheduledTimer(withTimeInterval: persistenceInterval, repeats: false) { [weak self] _ in
            self?.flushPendingStats()
        }
        persistenceTimer?.tolerance = min(1.0, persistenceInterval * 0.5)
    }

    private func flushPendingStats() {
        persistenceTimer?.invalidate()
        persistenceTimer = nil
        persistCurrentStats()
    }
}
