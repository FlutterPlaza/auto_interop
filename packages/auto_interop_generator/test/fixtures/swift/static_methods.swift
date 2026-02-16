import Foundation

/// A utility class with static methods.
public class MathUtils {
    /// Adds two integers.
    public static func add(a: Int, b: Int) -> Int {
        return a + b
    }

    /// Multiplies two doubles.
    public static func multiply(a: Double, b: Double) -> Double {
        return a * b
    }

    /// A class method that creates a formatted string.
    public class func format(value: Double, decimals: Int) -> String {
        return ""
    }

    /// An instance method.
    public func instanceMethod() -> String {
        return "instance"
    }
}
