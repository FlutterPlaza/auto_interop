import Foundation

public class AttributedService {
    @discardableResult
    public func process(input: String) -> String {
        return input
    }

    @available(iOS 15.0, *)
    public func modernMethod(data: Data) -> Bool {
        return true
    }

    @objc
    public func bridgedMethod(name: String) -> Void {
    }

    public func normalMethod(value: Int) -> Int {
        return value
    }
}

public struct AttributedStruct {
    @discardableResult
    public func compute(x: Double) -> Double {
        return x
    }

    public let name: String
}

public protocol AttributedProtocol {
    @discardableResult
    func validate(input: String) -> Bool
}

@discardableResult
public func attributedTopLevel(data: String) -> String {
    return data
}
