/// Lives in VGraph rather than in any one adapter so that every module —
/// including ones that cannot see `App` — can reach it. Before this, three
/// separate no-op loggers existed (`NoOpLogger` in App, `SilentGraphvizLogger`
/// in VGraphvizLib, and per-file copies in tests) purely because of module
/// visibility.
public struct NoOpLogger: VForLogMessages {
    public init() {}
    public func log(_ message: String) {}
}
