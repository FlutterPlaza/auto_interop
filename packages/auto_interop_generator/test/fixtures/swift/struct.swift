import Foundation

/// Represents a geographic coordinate.
public struct Coordinate {
    /// The latitude value.
    public let latitude: Double
    /// The longitude value.
    public let longitude: Double
    /// An optional label for this coordinate.
    public var label: String?
}

/// Configuration for a network request.
public struct RequestConfig {
    public let url: String
    public let method: String
    public var timeout: Int
    public var headers: [String: String]
}
