import AppIntents
import FlatlineKit

/// Fired by the user's Shortcuts automation ("When battery falls below 20%").
/// Runs in the background with no confirmation: record a sample, estimate,
/// light up the Lock Screen.
///
/// Must be a LiveActivityIntent (not a plain AppIntent): that conformance is
/// the only thing that lets a background-launched process start a Live
/// Activity. It also guarantees perform() runs on the main thread, which
/// UIDevice battery reads require.
struct StartDeathWatchIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Death Watch"
    static let description = IntentDescription(
        "Estimates when your phone will die and puts the countdown on your Lock Screen. Wire it to a low-battery automation in Shortcuts."
    )

    func perform() async throws -> some IntentResult {
        BatteryReader.recordSample()
        FlatlineDefaults.lastAutomationFiredAt = .now

        let estimate = BatteryReader.estimate()
        if estimate.isCharging {
            await DeathWatch.end()
        } else {
            await DeathWatch.startOrUpdate(estimate: estimate)
        }
        return .result()
    }
}

/// Optional companion: wire to a "When charger connects" automation.
struct CancelDeathWatchIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cancel Death Watch"
    static let description = IntentDescription(
        "Ends the death countdown (the patient survived). Wire it to a charger-connected automation in Shortcuts."
    )

    func perform() async throws -> some IntentResult {
        BatteryReader.recordSample()
        await DeathWatch.end()
        return .result()
    }
}
