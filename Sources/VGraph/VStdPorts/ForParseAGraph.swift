/// This is the main use case interface for the Parser module
public protocol VForParseAGraph {
    func parse(source: String) throws(VError) -> VGraph
}
