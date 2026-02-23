/// Tests that braces inside strings don't confuse the block finder.
public class Formatter {
    public func format(data: String) -> String {
        let template = "{ \"key\": \"value\" }"
        return template
    }

    public func render(name: String) -> String {
        // This comment has { braces } too
        return "Hello"
    }
}
