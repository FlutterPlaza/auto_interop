import Foundation

public class NetworkService {
    public func fetchData(url: String) throws -> String {
        return ""
    }

    public func uploadData(data: Data, to url: String) async throws -> Bool {
        return true
    }

    public func syncMethod(value: Int) -> Int {
        return value
    }
}

public func riskyOperation(input: String) throws -> String {
    return input
}

public func safeOperation(input: String) -> String {
    return input
}

public func asyncAndThrowing(data: String) async throws -> Bool {
    return true
}
