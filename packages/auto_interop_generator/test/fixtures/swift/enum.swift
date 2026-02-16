import Foundation

/// HTTP methods for network requests.
public enum HTTPMethod {
    case get
    case post
    case put
    case delete
    case patch
}

/// Log severity levels.
public enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}
