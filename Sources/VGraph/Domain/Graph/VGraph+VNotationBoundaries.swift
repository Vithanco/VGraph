extension VGraph {
    func declaring(boundaryKeys: [ItemKey: [String]]) -> VGraph {
        updatedSelfWith(notationDefinition: notationDefinition.declaring(boundaryKeys: boundaryKeys))
    }

    /// The boundary keys a `vnotation` wrote on a type, with their values, for
    /// the exporter to write back exactly those.
    public func declaredBoundary(of key: ItemKey) -> [(key: String, value: String)] {
        guard let keys = notationDefinition.declaredBoundaryKeys[key],
            let boundary = value(Attributes.Group.boundaryChrome, of: key, through: .vnotation)
        else { return [] }
        return keys.compactMap { name in boundary.vnotationValue(of: name).map { (key: name, value: $0) } }
    }
}
