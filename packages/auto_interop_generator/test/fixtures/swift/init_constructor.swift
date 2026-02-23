/// A class with an init constructor.
public class NetworkSession {
    public var baseURL: String

    public init(baseURL: String, timeout: Int = 30) {
        self.baseURL = baseURL
    }

    public func request(path: String) -> String {
        return ""
    }
}

/// A struct with an init.
public struct Config {
    public let host: String
    public let port: Int

    public init(host: String, port: Int = 8080) {
        self.host = host
        self.port = port
    }
}
