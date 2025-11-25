import Foundation

/// Represents a single blood glucose reading from an AccuChek device
public struct GlucoseSample: Identifiable, Codable, Sendable {
    public let id: Int
    public let epoch: Int64
    public let timestamp: String
    public let mgDL: UInt16
    public let mmolL: Double

    public init(id: Int, epoch: Int64, timestamp: String, mgDL: UInt16, mmolL: Double) {
        self.id = id
        self.epoch = epoch
        self.timestamp = timestamp
        self.mgDL = mgDL
        self.mmolL = mmolL
    }

    enum CodingKeys: String, CodingKey {
        case id
        case epoch
        case timestamp
        case mgDL = "mg/dL"
        case mmolL = "mmol/L"
    }

    /// Returns the date of the sample
    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(epoch))
    }

    /// Returns a formatted date string
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Glucose level category based on mg/dL value
    public var category: GlucoseCategory {
        switch mgDL {
        case 0..<70:
            return .low
        case 70..<100:
            return .normal
        case 100..<126:
            return .elevated
        default:
            return .high
        }
    }
}

/// Categories for blood glucose levels
public enum GlucoseCategory: String, CaseIterable, Sendable {
    case low = "Low"
    case normal = "Normal"
    case elevated = "Elevated"
    case high = "High"

    public var color: String {
        switch self {
        case .low: return "blue"
        case .normal: return "green"
        case .elevated: return "orange"
        case .high: return "red"
        }
    }
}

/// Represents information about a connected AccuChek device
public struct DeviceInfo: Identifiable, Codable, Sendable {
    public var id: String { "\(vendorId):\(productId)" }
    public let name: String
    public let vendorId: String
    public let productId: String

    public init(name: String, vendorId: String, productId: String) {
        self.name = name
        self.vendorId = vendorId
        self.productId = productId
    }
}

/// Configuration for supported device IDs
public struct DeviceConfig: Codable, Sendable {
    public let devices: [SupportedDevice]

    public init(devices: [SupportedDevice]) {
        self.devices = devices
    }
}

public struct SupportedDevice: Codable, Sendable {
    public let name: String
    public let vendorId: UInt16
    public let productId: UInt16

    public init(name: String, vendorId: UInt16, productId: UInt16) {
        self.name = name
        self.vendorId = vendorId
        self.productId = productId
    }
}
