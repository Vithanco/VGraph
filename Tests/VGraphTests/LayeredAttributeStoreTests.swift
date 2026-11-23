import Testing

@testable import VGraph

/// `AttributeStore` grown to ADR-0030's layers, with VGraph's own
/// attributes. Redundancy is judged along each key's chain.
@Suite("AttributeStore layers")
struct LayeredAttributeStoreTests {
    let n1 = ItemKey(.node, "n1")
    let circle = ItemKey(.nodeType, "Circle")
    let g = ItemKey(.group, "g")
    let boundary = ItemKey(.groupType, "Boundary")
    let viewA = AttributeLayer("viewA")
    let viewB = AttributeLayer("viewB")

    let color = Attributes.Node.backgroundColor
    // As the store holds them: `VColor` writes the alpha channel too.
    let red = VColor(hexString: "#ff0000")!.asString
    let blue = VColor(hexString: "#0000ff")!.asString
    let green = VColor(hexString: "#00ff00")!.asString

    ///     engine ─ builtin ─ vnotation ─ model ─┬─ viewA
    ///                                           └─ viewB
    let store: AttributeStore
    let chains = ChainTable([ItemKey(.node, "n1"): ItemKey(.nodeType, "Circle"), ItemKey(.group, "g"): ItemKey(.groupType, "Boundary")])

    init() throws {
        store = try AttributeStore()
            .define(VGraph().attributeDefinitions)
            .addLayer(viewA, parent: .model, admission: .view)
            .addLayer(viewB, parent: .model, admission: .view)
    }

    func color(_ hex: String) throws -> Attribute { try color.attribute(fromString: hex) }
    func folded(_ value: Bool) throws -> Attribute { Attributes.Group.isFolded.attribute(value) }

    func value(_ store: AttributeStore, _ id: Attribute.Id, _ key: ItemKey, through layer: AttributeLayer = .model)
        throws -> String
    {
        try store.resolve(id, for: key, through: layer, chains: chains).value
    }

    /// Values stay strings, so the store checks the type a write claims, not
    /// the text itself; a typed definition parses the text before it gets here.
    @Test
    func aWriteClaimingAnotherTypeIsRejected() throws {
        let asNumber = AttributeDefinition(
            id: color.id, name: "backgroundColor", description: "", defaultValue: "0", target: .node,
            typeAsString: "Int")
        let expected = try #require(store.definitions[color.id]).typeAsString
        #expect(throws: VError.attributeTypeMismatch(color.id, expected: expected, found: "Int")) {
            try store.set(asNumber.attribute(fromString: "3"), for: n1, in: .model, chains: chains)
        }
    }

    @Test
    func layersFormATree() throws {
        #expect(throws: VError.unknownAttributeLayer(AttributeLayer("nowhere"))) {
            try store.addLayer(AttributeLayer("viewC"), parent: AttributeLayer("nowhere"), admission: .view)
        }
        #expect(throws: VError.duplicateAttributeLayer(viewA)) {
            try store.addLayer(viewA, parent: .model, admission: .view)
        }
        #expect(throws: VError.unknownAttributeLayer(AttributeLayer("viewC"))) {
            try store.resolve(color.id, for: n1, through: AttributeLayer("viewC"), chains: chains)
        }
    }

    @Test
    func withNothingSetTheDefaultIsReturned() throws {
        let resolved = try store.resolve(color.id, for: n1, through: .model, chains: chains)
        #expect(resolved == ResolvedAttribute(color.asDefinition.defaultValue, from: .default))
    }

    @Test
    func anElementFallsBackToItsType() throws {
        let typed = try store.set(color(red), for: circle, in: .builtin, chains: chains)
        let resolved = try typed.resolve(color.id, for: n1, through: .model, chains: chains)
        #expect(resolved == ResolvedAttribute(red, from: .layer(.builtin, key: circle)))
    }

    @Test
    func aViewNamingOnlyTheTypeBeatsTheModelOnTheElement() throws {
        let styled = try store.set(color(red), for: n1, in: .model, chains: chains).set(color(green), for: circle, in: viewA, chains: chains)
        #expect(try value(styled, color.id, n1, through: viewA) == green)
        #expect(try value(styled, color.id, n1, through: .model) == red)
    }

    @Test
    func withinALayerTheElementBeatsItsType() throws {
        let styled = try store.set(color(green), for: circle, in: viewA, chains: chains).set(color(blue), for: n1, in: viewA, chains: chains)
        #expect(try value(styled, color.id, n1, through: viewA) == blue)
    }

    @Test("Given a view layer holding a value, when it is removed, then the layer and its value are gone")
    func removingALayerForgetsItsValues() throws {
        let styled = try store.set(color(green), for: n1, in: viewA, chains: chains)
        let removed = try styled.removeLayer(viewA)
        #expect(throws: VError.unknownAttributeLayer(viewA)) {
            try removed.values(in: viewA, for: n1)
        }
    }

    @Test("Given two view layers and a model value, when one view is removed, then the model and the other view are unchanged")
    func removingALayerLeavesTheRest() throws {
        let styled = try store.set(color(red), for: n1, in: .model, chains: chains)
            .set(color(green), for: circle, in: viewA, chains: chains)
            .set(color(blue), for: n1, in: viewB, chains: chains)
        let removed = try styled.removeLayer(viewA)
        #expect(try value(removed, color.id, n1, through: .model) == red)
        #expect(try value(removed, color.id, n1, through: viewB) == blue)
    }

    @Test
    func aQueryReadsOnlyItsOwnPath() throws {
        let styled = try store.set(color(green), for: n1, in: viewB, chains: chains)
        #expect(try value(styled, color.id, n1, through: viewA) == color.asDefinition.defaultValue)
        #expect(try value(styled, color.id, n1, through: viewB) == green)
    }

    @Test
    func resolveAllReturnsWhatIsSetButNoDefaults() throws {
        let styled = try store.set(color(red), for: circle, in: .builtin, chains: chains)
            .set(Attributes.Node.label.attribute(fromString: "Hello"), for: n1, in: .model, chains: chains)
        let all = try styled.resolveAll(for: n1, through: .model, chains: chains)
        #expect(
            all == [
                color.id: ResolvedAttribute(red, from: .layer(.builtin, key: circle)),
                Attributes.Node.label.id: ResolvedAttribute("Hello", from: .layer(.model, key: n1)),
            ])
    }

    @Test
    func aContentAttributeSetInAViewThrows() throws {
        let label = try Attributes.Node.label.attribute(fromString: "Hello")
        #expect(throws: VError.attributeNotAdmitted(label.id, key: n1, layer: viewA)) {
            try store.set(label, for: n1, in: viewA, chains: chains)
        }
        #expect(throws: VError.attributeNotAdmitted(label.id, key: n1, layer: viewA)) {
            try store.remove(label.id, for: n1, in: viewA, chains: chains)
        }
    }

    @Test
    func theModelNeverHoldsValuesOnTypesAndTheNotationNeverOnElements() throws {
        #expect(throws: VError.attributeNotAdmitted(color.id, key: circle, layer: .model)) {
            try store.set(color(red), for: circle, in: .model, chains: chains)
        }
        #expect(throws: VError.attributeNotAdmitted(color.id, key: n1, layer: .builtin)) {
            try store.set(color(red), for: n1, in: .builtin, chains: chains)
        }
    }

    @Test
    func aDiagramOnlyAttributeIsRejectedOffTheRoot() throws {
        let direction = Attributes.Group.layoutDirection.attribute(.leftToRight)
        #expect(throws: VError.attributeNotAdmitted(direction.id, key: g, layer: .model)) {
            try store.set(direction, for: g, in: .model, chains: chains)
        }
        let onRoot = try store.set(direction, for: .root, in: .model, chains: chains)
        #expect(try onRoot.values(in: .model, for: .root)[direction.id] != nil)
    }

    /// Which loops get a marker is presentation: a view may choose its own,
    /// for the whole diagram only.
    @Test
    func aViewChoosesItsOwnLoopMarkers() throws {
        let none = Attributes.Group.loopMarkers.attribute(LoopMarkers.none)
        let chosen = try store.set(none, for: .root, in: viewA, chains: chains)
        #expect(try value(chosen, none.id, .root, through: viewA) == none.stringValue)
        #expect(throws: VError.attributeNotAdmitted(none.id, key: g, layer: viewA)) {
            try store.set(none, for: g, in: viewA, chains: chains)
        }
    }

    @Test
    func aValueEqualToTheDefaultIsNotStored() throws {
        let same = try store.set(color(color.asDefinition.defaultValue), for: circle, in: .builtin, chains: chains)
        #expect(try same.values(in: .builtin, for: circle).isEmpty)
    }

    /// A computed value is a fact, not an override: "wrapped to no
    /// lines" must not read back as "never wrapped".
    @Test
    func aComputedValueEqualToTheDefaultIsKept() throws {
        let wrapped = try store.set(Attributes.Node.wrappedText.attribute([]), for: n1, in: .model, chains: chains)
        #expect(try wrapped.values(in: .model, for: n1)[Attributes.Node.wrappedText.id] != nil)
    }

    /// ADR-0030: "a model `false` beats a type's `true`".
    @Test
    func unfoldedBeatsAFoldedType() throws {
        let unfolded = try store.set(folded(true), for: boundary, in: .builtin, chains: chains).set(folded(false), for: g, in: .model, chains: chains)
        #expect(try value(unfolded, Attributes.Group.isFolded.id, g) == "false")
    }

    /// ADR-0030: where the type is not folded anyway, `unfolded` is redundant.
    @Test
    func unfoldedIsRedundantWhereTheTypeIsNotFolded() throws {
        let unfolded = try store.set(folded(false), for: g, in: .model, chains: chains)
        #expect(try unfolded.values(in: .model, for: g).isEmpty)
    }

    /// ADR-0030: "if the notation later changes the colour, an element that
    /// only repeated the old colour follows".
    @Test
    func anElementRepeatingItsTypeFollowsTheNotation() throws {
        let repeated = try store.set(color(red), for: circle, in: .builtin, chains: chains)
            .set(color(red), for: n1, in: .model, chains: chains)
            .set(color(blue), for: circle, in: .builtin, chains: chains)
        #expect(try value(repeated, color.id, n1) == blue)
    }

    @Test
    func aTypeChangingToAnElementsValuePrunesIt() throws {
        let pruned = try store.set(color(blue), for: n1, in: .model, chains: chains).set(color(blue), for: circle, in: .vnotation, chains: chains)
        #expect(try pruned.values(in: .model, for: n1).isEmpty)
        #expect(try value(pruned, color.id, n1) == blue)
    }

    @Test
    func removingAnAncestorsValueCanMakeAnOverrideRedundant() throws {
        let shielded = try store.set(color(red), for: circle, in: .builtin, chains: chains)
            .set(color(blue), for: n1, in: .model, chains: chains)
            .set(color(red), for: n1, in: viewA, chains: chains)
        #expect(try shielded.values(in: viewA, for: n1)[color.id] == red)
        let exposed = try shielded.remove(color.id, for: n1, in: .model, chains: chains)
        #expect(try exposed.values(in: viewA, for: n1).isEmpty)
    }

    /// The layer's own type value outranks its ancestors' element value, so
    /// matching the ancestor is not redundant.
    @Test
    func anOverrideOfItsLayersTypeValueIsKept() throws {
        let overridden = try store.set(color(red), for: n1, in: .model, chains: chains)
            .set(color(green), for: circle, in: viewA, chains: chains)
            .set(color(red), for: n1, in: viewA, chains: chains)
        #expect(try value(overridden, color.id, n1, through: viewA) == red)
    }

    @Test
    func anAncestorChangeKeepsAnOverrideOfItsLayersTypeValue() throws {
        let overridden = try store.set(color(blue), for: n1, in: .model, chains: chains)
            .set(color(green), for: circle, in: viewA, chains: chains)
            .set(color(red), for: n1, in: viewA, chains: chains)
            .set(color(red), for: n1, in: .model, chains: chains)
        #expect(try value(overridden, color.id, n1, through: viewA) == red)
    }

    @Test
    func removingItsLayersTypeValueMakesAnOverrideRedundant() throws {
        let exposed = try store.set(color(red), for: n1, in: .model, chains: chains)
            .set(color(green), for: circle, in: viewA, chains: chains)
            .set(color(red), for: n1, in: viewA, chains: chains)
            .remove(color.id, for: circle, in: viewA, chains: chains)
        #expect(try exposed.values(in: viewA, for: n1).isEmpty)
    }

    /// A bulk write judges values only after all are in place, so the type
    /// value is there before the element's override is judged.
    @Test
    func aMergedOverrideOfItsOwnTypeValueIsKept() throws {
        let merged = try store.set(color(red), for: n1, in: .model, chains: chains)
            .merging([(n1, color(red)), (circle, color(green))], into: viewA, chains: chains)
        #expect(try value(merged, color.id, n1, through: viewA) == red)
    }

    @Test
    func siblingsNeverPruneEachOther() throws {
        let both = try store.set(color(green), for: n1, in: viewA, chains: chains).set(color(green), for: n1, in: viewB, chains: chains)
        #expect(try both.values(in: viewA, for: n1)[color.id] == green)
        #expect(try both.values(in: viewB, for: n1)[color.id] == green)
    }

    @Test
    func mergingIntoALayerPrunesItsDescendantsAndChecksAdmission() throws {
        let merged = try store.set(color(blue), for: n1, in: .model, chains: chains)
            .merging([(circle, color(blue))], into: .builtin, chains: chains)
        #expect(try merged.values(in: .model, for: n1).isEmpty)
        #expect(throws: VError.attributeNotAdmitted(color.id, key: n1, layer: .builtin)) {
            try store.merging([(n1, color(blue))], into: .builtin, chains: chains)
        }
    }

    @Test
    /// The key's type is the graph's to forget, not the store's.
    func removingAKeyClearsEveryLayer() throws {
        let removed = try store.set(color(blue), for: n1, in: .model, chains: chains)
            .set(color(green), for: n1, in: viewA, chains: chains)
            .set(color(red), for: circle, in: .builtin, chains: chains)
            .removeKey(n1)
        #expect(try removed.values(in: .model, for: n1).isEmpty)
        #expect(try removed.values(in: viewA, for: n1).isEmpty)
        #expect(try removed.values(in: .builtin, for: circle)[color.id] == red)
    }

    /// How a detailed node turns into a node and back, keeping its values (ADR-0032).
    @Test
    func rekeyingMovesAKeysValuesInEveryLayer() throws {
        let moved = try store.set(color(blue), for: g, in: .model, chains: chains)
            .set(color(green), for: g, in: viewA, chains: chains)
            .set(color(red), for: circle, in: .builtin, chains: chains)
            .rekeying(from: g, to: n1)
        #expect(try moved.values(in: .model, for: g).isEmpty)
        #expect(try moved.values(in: viewA, for: g).isEmpty)
        #expect(try moved.values(in: .model, for: n1)[color.id] == blue)
        #expect(try moved.values(in: viewA, for: n1)[color.id] == green)
        #expect(
            try moved.resolve(color.id, for: n1, through: .model, chains: chains)
                == ResolvedAttribute(blue, from: .layer(.model, key: n1)))
        #expect(try moved.values(in: .builtin, for: circle)[color.id] == red)
    }

    @Test
    func anEditLeavesThePreviousVersionUnchanged() throws {
        let before = try store.set(color(blue), for: n1, in: .model, chains: chains)
        _ = try before.set(color(blue), for: circle, in: .builtin, chains: chains).removeKey(n1)
        #expect(try before.values(in: .model, for: n1)[color.id] == blue)
    }
}

/// The chains a test declares, standing in for a graph's structure.
struct ChainTable: ChainSource {
    let types: [ItemKey: ItemKey]

    init(_ types: [ItemKey: ItemKey] = [:]) { self.types = types }

    func type(of key: ItemKey) -> ItemKey? { types[key] }

    func members(of type: ItemKey) -> [ItemKey] {
        types.filter { $0.value == type }.map { $0.key }
    }
}
