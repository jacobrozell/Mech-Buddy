import Foundation

/// How players tell their miniatures apart at the table ("orange base = Locust").
/// Proxies and unpainted minis made it easy to mix up which card was which.
public enum MiniMarker: String, Codable, Sendable, CaseIterable, Identifiable {
    case red, orange, yellow, green, blue, purple, white, grey, black

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}
