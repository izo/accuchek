// AccuChekKit - Swift Package for AccuChek Data Management
// Supports iOS and macOS

import Foundation

/// Main entry point for AccuChekKit
public enum AccuChekKit {
    /// Library version
    public static let version = "0.1.0"

    /// Supported platforms
    public enum Platform: String {
        case iOS
        case macOS
    }

    /// Current platform
    public static var currentPlatform: Platform {
        #if os(iOS)
        return .iOS
        #else
        return .macOS
        #endif
    }
}

// Re-export main types
public typealias Sample = GlucoseSample
public typealias Device = DeviceInfo
