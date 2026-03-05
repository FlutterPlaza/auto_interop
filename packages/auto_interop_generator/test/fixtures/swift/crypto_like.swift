import Foundation

/// A protocol for block cipher modes of operation.
public protocol BlockMode {
    /// Encrypts a block of data.
    func encrypt(block: [UInt8]) throws -> [UInt8]
}

/// AES block cipher.
public class AES {
    /// Creates an AES cipher.
    public init(key: [UInt8], blockMode: BlockMode, padding: Padding) throws {
    }

    /// Encrypts bytes.
    public func encrypt(_ bytes: ArraySlice<UInt8>) throws -> Array<UInt8> {
    }

    /// Decrypts bytes.
    public func decrypt(_ bytes: ArraySlice<UInt8>) throws -> Array<UInt8> {
    }
}

/// Galois/Counter Mode.
public struct GCM {
    /// Creates a GCM instance.
    public init(iv: [UInt8], additionalAuthenticatedData: [UInt8]?, mode: GCM.Mode = .combined) {
    }
}

extension GCM : BlockMode {
    /// GCM encryption mode.
    public enum Mode {
        case combined
        case detached
    }
}

/// Padding schemes.
public enum Padding {
    case noPadding
    case zeroPadding
    case pkcs7
    case pkcs5
}

/// SHA-2 digest.
public struct SHA2 {
    public init(variant: SHA2.Variant) {
    }
    public func calculate(for bytes: [UInt8]) -> [UInt8] {
    }
}

extension SHA2 {
    /// SHA-2 variants.
    public enum Variant {
        case sha256
        case sha384
        case sha512
    }
}

/// HMAC authenticator.
public class HMAC {
    public init(key: [UInt8], variant: HMAC.Variant) throws {
    }
    public func authenticate(_ bytes: [UInt8]) throws -> [UInt8] {
    }
}

extension HMAC {
    public enum Variant {
        case sha256
        case sha384
        case sha512
    }
}
