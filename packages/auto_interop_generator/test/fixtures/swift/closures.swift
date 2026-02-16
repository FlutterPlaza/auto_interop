import Foundation

/// An event handler that uses closure callbacks.
public class EventHandler {
    /// Registers a callback for string events.
    public func onEvent(callback: (String) -> Void) {
        // implementation
    }

    /// Registers a callback that transforms data.
    public func transform(mapper: (String) -> Int) -> Int {
        // implementation
    }

    /// Registers an optional completion handler.
    public func fetchWithCompletion(url: String, completion: ((String, Bool) -> Void)?) {
        // implementation
    }
}
