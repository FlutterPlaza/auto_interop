import Foundation

/// A protocol for objects that can be serialized to JSON.
public protocol JSONSerializable {
    /// Converts this object to a JSON string.
    func toJSON() -> String
    /// Creates an instance from a JSON string.
    func fromJSON(json: String) -> Bool
    /// The content type for this serialization format.
    var contentType: String { get }
}

/// A protocol for cacheable resources.
public protocol Cacheable {
    /// The cache key for this resource.
    var cacheKey: String { get }
    /// Time-to-live in seconds.
    func ttl() -> Int
}
