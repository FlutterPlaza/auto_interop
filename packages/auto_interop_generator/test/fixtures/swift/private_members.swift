import Foundation

/// A class with mixed visibility.
public class MixedVisibility {
    /// Public method.
    public func publicMethod() -> String {
        return _helper()
    }

    /// Another public method.
    public func anotherPublic(value: Int) -> Int {
        return value
    }

    private func _helper() -> String {
        return "hidden"
    }

    fileprivate func _internalHelper() -> Bool {
        return true
    }

    internal func internalMethod() -> String {
        return "internal"
    }

    private var _secretValue: String = "secret"
    public var publicValue: String = "visible"
}
