import Foundation

/// Persists battery samples as JSON in a shared container so the app, the
/// widget, and intent invocations all contribute to one history.
public struct SampleStore {
    public static let appGroupID = "group.com.alexmartin.flatline"
    static let maxSamples = 2000
    static let maxAge: TimeInterval = 14 * 24 * 3600

    private let fileURL: URL

    /// Uses the App Group container. Falls back to the app's own Application
    /// Support directory when the group isn't available (e.g. previews).
    public init() {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.init(directory: base)
    }

    /// Injectable directory for tests.
    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("battery-samples.json")
    }

    public func load() -> [BatterySample] {
        guard let data = try? Data(contentsOf: fileURL),
              let samples = try? JSONDecoder().decode([BatterySample].self, from: data) else {
            return []
        }
        return samples
    }

    /// Appends a sample, prunes old/excess entries, writes back.
    /// Skips the write when the newest stored sample is identical and recent,
    /// so widget refreshes don't churn the file.
    public func append(_ sample: BatterySample) {
        var samples = load()
        if let last = samples.last,
           last.level == sample.level,
           last.isCharging == sample.isCharging,
           sample.timestamp.timeIntervalSince(last.timestamp) < 60 {
            return
        }
        samples.append(sample)

        let cutoff = sample.timestamp.addingTimeInterval(-Self.maxAge)
        samples.removeAll { $0.timestamp < cutoff }
        if samples.count > Self.maxSamples {
            samples.removeFirst(samples.count - Self.maxSamples)
        }

        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let data = try? JSONEncoder().encode(samples) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
