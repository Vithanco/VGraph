extension VGraph {
    func declaring(frameKeys: [ItemKey: [String]]) -> VGraph {
        updatedSelfWith(notationDefinition: notationDefinition.declaring(frameKeys: frameKeys))
    }

    func declaring(keysGivenTwice: [KeyGivenTwice]) -> VGraph {
        updatedSelfWith(notationDefinition: notationDefinition.declaring(keysGivenTwice: keysGivenTwice))
    }

    /// The frame keys a `vnotation` wrote on a type, with their values, for
    /// the exporter to write back exactly those.
    public func declaredFrame(of key: ItemKey) -> [(key: String, value: String)] {
        guard let keys = notationDefinition.declaredFrameKeys[key],
            let frame = value(Attributes.Group.frame, of: key, through: .vnotation)
        else { return [] }
        return keys.compactMap { name in frame.vnotationValue(of: name).map { (key: name, value: $0) } }
    }
}
