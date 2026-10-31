import JavaScriptKit
import VGraph

public struct ConsoleLogger: VForLogMessages {
    public init() {}

    public func log(_ message: String) {
        let console = JSObject.global.console
        _ = console.log(message)
    }

    public func error(_ message: String) {
        let console = JSObject.global.console
        _ = console.error(message)
    }
}
