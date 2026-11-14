public struct AttributeStore: VProtocol {
    public private(set) var definitions: AttributeDefContainer

    struct LayerInfo: VProtocol {
        let parent: AttributeLayer?
        let admission: LayerAdmission
    }
    /// A map per layer and kind, so an edit copies one kind's map, not the store.
    typealias LayerValues = [ItemKind: [String: AttributeContainer]]

    var layers: [AttributeLayer: LayerInfo]
    var layerValues: [AttributeLayer: LayerValues]

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
}
