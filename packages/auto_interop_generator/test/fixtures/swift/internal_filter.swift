/// Tests that internal declarations are properly filtered.
public class PublicService {
    public func publicMethod() -> String {
        return ""
    }
}

internal func internalHelper() -> String {
    return ""
}

internal class InternalClass {
    func doWork() {}
}
