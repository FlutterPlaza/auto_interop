import Foundation

/// A base image loader class.
public class ImageLoader {
    /// Loads an image from a URL.
    public func load(url: String) -> Data {
        // implementation
    }
}

extension ImageLoader {
    /// Loads an image and resizes it.
    public func loadResized(url: String, width: Int, height: Int) -> Data {
        // implementation
    }

    /// Clears the image cache.
    public func clearCache() {
        // implementation
    }
}
