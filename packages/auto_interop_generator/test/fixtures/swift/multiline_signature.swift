/// A client with multi-line function signatures.
public class MultilineClient {
    /// Fetches data with many parameters.
    public func fetchData(
        url: String,
        method: String,
        timeout: Int
    ) -> String {
        return ""
    }

    /// Uploads with multi-line params and async.
    public func upload(
        data: Data,
        destination: String
    ) async throws -> Bool {
        return true
    }

    public func simple(name: String) -> Int {
        return 0
    }
}
