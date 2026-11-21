import VGraph

public struct VGLFragments<Logger: ForLogMessages>: ForExchangeAFragment {
    let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public func export(fragment: VGraph) throws(VError) -> String {
        try VGLExporter().export(fragment: fragment)
    }

    public func parse(fragment: String, into graph: VGraph, under group: Group?) throws(VError)
        -> (graph: VGraph, pasted: [String])
    {
        try VGraphParser(logger: logger).parse(fragment: fragment, into: graph, under: group)
    }
}
