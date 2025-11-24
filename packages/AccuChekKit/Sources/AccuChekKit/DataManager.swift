import Foundation

/// Manages glucose data storage and retrieval
@MainActor
public final class DataManager: ObservableObject {
    @Published public private(set) var samples: [GlucoseSample] = []
    @Published public private(set) var connectedDevices: [DeviceInfo] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: String?

    private let fileManager = FileManager.default

    public init() {}

    /// Load samples from a JSON file
    public func loadSamples(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        samples = try decoder.decode([GlucoseSample].self, from: data)
    }

    /// Export samples to JSON format
    public func exportToJSON(samples: [GlucoseSample]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(samples)
    }

    /// Export samples to CSV format
    public func exportToCSV(samples: [GlucoseSample]) -> String {
        var csv = "ID,Timestamp,Epoch,mg/dL,mmol/L\n"
        for sample in samples {
            csv += "\(sample.id),\(sample.timestamp),\(sample.epoch),\(sample.mgDL),\(String(format: "%.1f", sample.mmolL))\n"
        }
        return csv
    }

    /// Save samples to a JSON file
    public func saveSamples(_ samples: [GlucoseSample], to url: URL) throws {
        let data = try exportToJSON(samples: samples)
        try data.write(to: url)
    }

    /// Save samples to a CSV file
    public func saveAsCSV(_ samples: [GlucoseSample], to url: URL) throws {
        let csv = exportToCSV(samples: samples)
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Get statistics for the samples
    public func statistics(for samples: [GlucoseSample]) -> GlucoseStatistics {
        guard !samples.isEmpty else {
            return GlucoseStatistics(count: 0, average: 0, min: 0, max: 0, inRange: 0)
        }

        let values = samples.map { Int($0.mgDL) }
        let total = values.reduce(0, +)
        let average = Double(total) / Double(values.count)
        let inRangeCount = samples.filter { $0.category == .normal || $0.category == .elevated }.count
        let inRangePercentage = Double(inRangeCount) / Double(samples.count) * 100

        return GlucoseStatistics(
            count: samples.count,
            average: average,
            min: values.min() ?? 0,
            max: values.max() ?? 0,
            inRange: inRangePercentage
        )
    }

    /// Update samples
    public func updateSamples(_ newSamples: [GlucoseSample]) {
        samples = newSamples
    }

    /// Clear all data
    public func clearData() {
        samples = []
        lastError = nil
    }
}

/// Statistics for glucose readings
public struct GlucoseStatistics: Sendable {
    public let count: Int
    public let average: Double
    public let min: Int
    public let max: Int
    public let inRange: Double  // Percentage

    public init(count: Int, average: Double, min: Int, max: Int, inRange: Double) {
        self.count = count
        self.average = average
        self.min = min
        self.max = max
        self.inRange = inRange
    }
}
