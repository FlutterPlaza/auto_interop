import Foundation

/// Manages image downloading and caching.
public class SDWebImageManager {
    /// Loads an image from a URL.
    public func loadImage(url: String) async throws -> Data {
        // implementation
    }

    /// Prefetches images from multiple URLs.
    public func prefetch(urls: [String]) {
        // implementation
    }

    /// Clears the memory cache.
    public func clearMemoryCache() {
        // implementation
    }

    /// Clears the disk cache.
    public func clearDiskCache() async {
        // implementation
    }
}

/// Manages the image cache.
public class SDImageCache {
    /// Stores an image in the cache.
    public func store(data: Data, forKey key: String) async {
        // implementation
    }

    /// Retrieves an image from the cache.
    public func queryImage(forKey key: String) async -> Data? {
        // implementation
    }

    /// Removes an image from the cache.
    public func removeImage(forKey key: String) async {
        // implementation
    }

    /// Returns the total disk cache size in bytes.
    public func diskCacheSize() async -> Int {
        // implementation
    }
}

/// Configuration for the image loading pipeline.
public struct SDWebImageOptions {
    /// Whether to retry failed URLs.
    public var retryFailed: Bool
    /// Whether to use low priority.
    public var lowPriority: Bool
    /// Whether to cache in memory only.
    public var cacheMemoryOnly: Bool
    /// Custom scale factor.
    public var scaleFactor: Double
}

/// Image content modes.
public enum SDImageContentMode {
    case fill
    case aspectFit
    case aspectFill
}

/// Represents the result of an image operation.
public enum SDImageResult {
    /// Image loaded successfully.
    case success(data: Data, cacheType: String)
    /// Image loading failed.
    case failure(error: String)
}
