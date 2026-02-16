import Foundation

/// Represents the result of a network operation.
public enum NetworkResult {
    /// A successful response with data and status code.
    case success(data: Data, statusCode: Int)
    /// A failure with an error message.
    case failure(message: String)
    /// The request is still loading.
    case loading
}
