import Foundation
import FlatlineKit

/// Shared defaults readable by the app, widget, and intents.
enum FlatlineDefaults {
    static let suite = UserDefaults(suiteName: SampleStore.appGroupID) ?? .standard
    private static let thresholdKey = "deathwatch.threshold"
    private static let automationFiredKey = "deathwatch.lastAutomationFiredAt"
    private static let onboardedKey = "deathwatch.onboarded"

    /// Battery fraction below which the death watch is meant to fire (0.20 = 20%).
    static var threshold: Double {
        get {
            let value = suite.double(forKey: thresholdKey)
            return value > 0 ? value : 0.20
        }
        set { suite.set(newValue, forKey: thresholdKey) }
    }

    /// Proof that the user's Shortcuts automation actually reached us.
    static var lastAutomationFiredAt: Date? {
        get { suite.object(forKey: automationFiredKey) as? Date }
        set { suite.set(newValue, forKey: automationFiredKey) }
    }

    static var hasOnboarded: Bool {
        get { suite.bool(forKey: onboardedKey) }
        set { suite.set(newValue, forKey: onboardedKey) }
    }

    private static let issueKey = "deathwatch.issue"
    /// Why the Lock Screen countdown couldn't start, if it couldn't.
    /// Nil means healthy. Shown on DeathScreen so failures are never silent.
    static var deathWatchIssue: String? {
        get { suite.string(forKey: issueKey) }
        set { suite.set(newValue, forKey: issueKey) }
    }
}
