// Outbound port for exporting (serializing) a VGraph to a text format.

public protocol VForExportAGraph {
    func export(graph: VGraph) throws(VError) -> String
}
