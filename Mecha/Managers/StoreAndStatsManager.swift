import StoreKit
import SwiftUI

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
class StatsManager: ObservableObject {
    @Published var dailyKeystrokes: Int = 0
    @Published var estimatedWPM: Int = 0
    
    init() {
        loadStats()
    }
    
    func incrementKeystroke() {
        DispatchQueue.main.async {
            self.dailyKeystrokes += 1
            UserDefaults.standard.set(self.dailyKeystrokes, forKey: "DailyKeystrokes")
            
            // Simple WPM fake logic
            if self.dailyKeystrokes % 50 == 0 {
                self.estimatedWPM = Int.random(in: 40...85)
            }
        }
    }
    
    private func loadStats() {
        self.dailyKeystrokes = UserDefaults.standard.integer(forKey: "DailyKeystrokes")
    }
}
