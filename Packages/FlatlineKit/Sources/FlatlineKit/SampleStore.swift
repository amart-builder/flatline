import Foundation

/// Persists battery samples as JSON in a shared container so the app, the
/// widget, and intent invocations all contribute to one history.
///
/// Writes from multiple processes are real here (a threshold crossing can wake
/// the intent, the widget, and the app at once), so every read-modify-write is
/// serialized through NSFileCoordinator — the sanctioned mechanism for App
/// Group files.
public struct SampleStore {
    public static let appGroupID = "group.com.alexmartin.flatline"
    static let maxSamples = 2000
    static let maxAge: TimeInterval = 14 * 24 * 3600
    static let futureTolerance: TimeInterval = 5 * 60

    private let fileURL: URL
    /// False means the App Group container didn't resolve (missing
    /// entitlement?) and this process is writing to its own private fallback —
    /// app and widget would be split-brained. Surfaced so callers can warn.
    public let usingAppGroup: Bool

    /// Uses the App Group container. Falls back to the app's own Application
    /// Support directory when the group isn't available (e.g. previews).
    public init() {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            self.init(directory: group, usingAppGroup: true)
        } else {
            self.init(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0],
                      usingAppGroup: false)
        }
    }

    /// Injectable directory for tests.
    public init(directory: URL, usingAppGroup: Bool = true) {
        fileURL = directory.appendingPathComponent("battery-samples.json")
        self.usingAppGroup = usingAppGroup
    }

    public func load() -> [BatterySample] {
        var samples: [BatterySample] = []
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([BatterySample].self, from: data) else { return }
            samples = decoded
        }
        return samples
    }

    /// Appends a sample, prunes old/excess entries, writes back — atomically
    /// with respect to other readers/writers in any process.
    /// Skips near-duplicate rapid re-reads so widget refreshes don't churn the
    /// file, and rejects future-stamped clock garbage so one bad sample can't
    /// wipe the history via the age-pruning cutoff.
    public func append(_ sample: BatterySample, now: Date = Date()) {
        guard sample.timestamp.timeIntervalSince(now) <= Self.futureTolerance else { return }

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordinationError) { url in
            var samples: [BatterySample] = []
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([BatterySample].self, from: data) {
                samples = decoded
            }

            if let last = samples.last,
               last.level == sample.level,
               last.isCharging == sample.isCharging,
               case let dt = sample.timestamp.timeIntervalSince(last.timestamp),
               dt >= 0, dt < 60 {
                return
            }
            samples.append(sample)

            let cutoff = min(sample.timestamp, now).addingTimeInterval(-Self.maxAge)
            samples.removeAll { $0.timestamp < cutoff }
            if samples.count > Self.maxSamples {
                samples.removeFirst(samples.count - Self.maxSamples)
            }

            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if let data = try? JSONEncoder().encode(samples) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
