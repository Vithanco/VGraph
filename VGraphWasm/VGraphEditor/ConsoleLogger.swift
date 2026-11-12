import JavaScriptKit
import VGraph

public struct ConsoleLogger: VForLogMessages {
    public init() {}

    // Release builds ship inside the Obsidian and VS Code plugins, where nothing
    // but errors belongs in the console (Obsidian's plugin guidelines). `warn` and
    // `debug` arrive here too, so debug builds keep the whole trace and release
    // builds only errors.
    public func log(_ message: String) {
        #if DEBUG
            let console = JSObject.global.console
            _ = console.log(message)
        #endif
    }

    public func error(_ message: String) {
        let console = JSObject.global.console
        _ = console.error(message)
    }
}
