public struct AttributeStore: VProtocol {
    public struct Counts: VProtocol {
        let definitions: Int
        /// Values held, across every layer.
        let entries: Int
    }

    public private(set) var definitions: AttributeDefContainer

    struct LayerInfo: VProtocol {
        let parent: AttributeLayer?
        let admission: LayerAdmission
    }
    /// A map per layer and kind, so an edit copies one kind's map, not the store.
    typealias LayerValues = [ItemKind: [String: AttributeContainer]]

    var layers: [AttributeLayer: LayerInfo]
    var layerValues: [AttributeLayer: LayerValues]
    /// Only values a rule produced; every other value was written directly.
    var ruleSources: [AttributeLayer: [ItemKey: [Attribute.Id: String]]]

    public init() {
        self.definitions = [:]
        // ADR-0030's stack; views branch off the model.
        self.layers = [
            .engine: LayerInfo(parent: nil, admission: .notation),
            .builtin: LayerInfo(parent: .engine, admission: .notation),
            .vnotation: LayerInfo(parent: .builtin, admission: .notation),
            .model: LayerInfo(parent: .vnotation, admission: .model),
        ]
        self.layerValues = [:]
        self.ruleSources = [:]
    }

    /// Every layer, by name: the order of a dictionary changes between runs.
    public var layerNames: [AttributeLayer] {
        layers.keys.sorted { $0.rawValue < $1.rawValue }
    }

    func getAttributeDefinition(_ id: Attribute.Id) throws(VError) -> AttributeDefinition {
        guard let definition = definitions[id] else {
            throw VError.attributeNotFound(id)
        }
        return definition
    }

    public func define(_ definition: AttributeDefinition) throws(VError) -> Self {
        if let previous = definitions[definition.id] {
            guard previous != definition else {
                return self
            }
            throw VError.definitionAlreadyExists(definition.id)
        }
        var result = self
        result.definitions[definition.id] = definition
        return result
    }

    public func define<T: AttributeType>(_ definition: TypedAttributeDefinition<T>) throws(VError) -> Self {
        return try define(definition.asDefinition)
    }

    public func define(_ definitions: AttributeDefContainer) -> AttributeStore {
        var result = self
        for definition in definitions.values {
            if let added = try? result.define(definition) {
                result = added
            }
        }
        return result
    }

    public var counts: Counts {
        var entries = 0
        for (_, byKind) in layerValues {
            for (_, byId) in byKind {
                for (_, container) in byId { entries += container.count }
            }
        }
        return Counts(definitions: definitions.count, entries: entries)
    }
}
