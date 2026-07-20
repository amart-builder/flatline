import ActivityKit
import Foundation
import FlatlineKit

/// Starts, updates, and ends the Lock Screen / Dynamic Island Live Activity.
///
/// Every entry point is async and awaited by callers: these run in a
/// background-launched process that can be suspended the moment the intent
/// returns, so fire-and-forget Tasks would silently die.
enum DeathWatch {
    /// Starts a new activity or re-anchors the existing one. Later threshold
    /// crossings (15%, 10%, 5%) come through here again with fresher estimates.
    static func startOrUpdate(estimate: Estimate) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            FlatlineDefaults.deathWatchIssue = "Live Activities are turned off for Flatline. Enable them in Settings > Flatline."
            return
        }
        guard let deathDate = estimate.deathDate, let level = estimate.level else { return }

        let state = DeathWatchAttributes.ContentState(
            deathDate: deathDate,
            level: level,
            ratePerHour: estimate.ratePerHour
        )
        // Estimates go stale: tell the system to dim the activity if nothing
        // re-anchors it for 2 hours.
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(2 * 3600))

        if let existing = Activity<DeathWatchAttributes>.activities.first {
            await existing.update(content)
            FlatlineDefaults.deathWatchIssue = nil
        } else {
            do {
                _ = try Activity.request(attributes: DeathWatchAttributes(), content: content)
                FlatlineDefaults.deathWatchIssue = nil
            } catch {
                // Surfaced on DeathScreen; a silent failure here is the
                // product failing invisibly.
                FlatlineDefaults.deathWatchIssue = "Couldn't start the Lock Screen countdown (\(error.localizedDescription))."
            }
        }
    }

    /// Ends every death watch activity (the patient survived: charger connected).
    static func end() async {
        for activity in Activity<DeathWatchAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
