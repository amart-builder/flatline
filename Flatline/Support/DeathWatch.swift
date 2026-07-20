import ActivityKit
import Foundation
import FlatlineKit

/// Starts, updates, and ends the Lock Screen / Dynamic Island Live Activity.
enum DeathWatch {
    /// Starts a new activity or re-anchors the existing one. Later threshold
    /// crossings (15%, 10%, 5%) come through here again with fresher estimates.
    static func startOrUpdate(estimate: Estimate) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let deathDate = estimate.deathDate,
              let level = estimate.level else { return }

        let state = DeathWatchAttributes.ContentState(
            deathDate: deathDate,
            level: level,
            ratePerHour: estimate.ratePerHour
        )
        // Estimates go stale: tell the system to dim the activity if nothing
        // re-anchors it for 2 hours.
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(2 * 3600))

        if let existing = Activity<DeathWatchAttributes>.activities.first {
            Task { await existing.update(content) }
        } else {
            _ = try? Activity.request(attributes: DeathWatchAttributes(), content: content)
        }
    }

    /// Ends every death watch activity (the patient survived: charger connected).
    static func end() {
        Task {
            for activity in Activity<DeathWatchAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
