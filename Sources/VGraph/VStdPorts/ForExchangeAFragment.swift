// Driven port: part of a graph as VGL text, and such text pasted back into a
// document. Its own port because `ForExportAGraph` is also Graphviz's, which
// has no use for a fragment.

public protocol VForExchangeAFragment {
    /// No `vgraph` header, no `vnotation`.
    func export(fragment: VGraph) throws(VError) -> String

    /// In the document's context: its notation's types, its free ids, its nodes
    /// as edge ends. `pasted` is the top-level nodes and groups, as renamed.
    func parse(fragment: String, into graph: VGraph, under group: Group?) throws(VError)
        -> (graph: VGraph, pasted: [String])
}
