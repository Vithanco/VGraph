// Pins the exact strings produced today by the reflection-based
// `HasReadableNames` / `NameDescribable` defaults — i.e. `"\(self)"` for
// enum cases and `"\(type(of: self))"` for type names.
//
// Embedded Swift has no enum-case reflection. Phase 1 of the embedded
// migration replaces these defaults with hand-written `switch self` per
// conforming enum and explicit `static let typeName` per conforming type.
// This file is the wire-format contract Phase 1 must reproduce byte-for-byte.
//
// Each test pins:
//  - `value`         — programmatic case-name (defaults to `"\(self)"`)
//  - `readableName`  — UI/display string (defaults to `"\(self)"`, often overridden)
//  - `alias`         — alias of readableName (defaults to readableName, sometimes overridden)
//  - `asString`      — VGL wire format (defaults to alias)
//  - `typeName`      — static type identifier (defaults to "\(type(of: self))"-derived)

import Testing

@testable import VGraph

@Suite("Reflection contract — HasReadableNames")
struct ReflectionContractTests_HasReadableNames {

    // MARK: DiagramLogic

    @Test func diagramLogic_typeName() {
        #expect(DiagramLogic.typeName == "DiagramLogic")
    }

    @Test func diagramLogic_cases() {
        let cases: [(c: DiagramLogic, value: String, readableName: String, alias: String, asString: String)] = [
            (.noLogic, "noLogic", "None", "None", "None"),
            (.sufficientCause, "sufficientCause", "Sufficient Cause", "Sufficient Cause", "Sufficient Cause"),
            (.necessaryCondition, "necessaryCondition", "Necessary Condition", "Necessary Condition", "Necessary Condition"),
        ]
        for e in cases {
            #expect(e.c.value == e.value, "DiagramLogic.\(e.c).value")
            #expect(e.c.readableName == e.readableName, "DiagramLogic.\(e.c).readableName")
            #expect(e.c.alias == e.alias, "DiagramLogic.\(e.c).alias")
            #expect(e.c.asString == e.asString, "DiagramLogic.\(e.c).asString")
        }
    }

    // MARK: AttributeTarget

    @Test func attributeTarget_typeName() {
        #expect(AttributeTarget.typeName == "AttributeTarget")
    }

    @Test func attributeTarget_cases() {
        let cases: [(c: AttributeTarget, value: String, readableName: String, alias: String, asString: String)] = [
            (.node, "node", "Node", "Node", "Node"),
            (.edge, "edge", "Edge", "Edge", "Edge"),
            (.graph, "graph", "Graph", "Graph", "Graph"),
        ]
        for e in cases {
            #expect(e.c.value == e.value, "AttributeTarget.\(e.c).value")
            #expect(e.c.readableName == e.readableName, "AttributeTarget.\(e.c).readableName")
            #expect(e.c.alias == e.alias, "AttributeTarget.\(e.c).alias")
            #expect(e.c.asString == e.asString, "AttributeTarget.\(e.c).asString")
        }
    }
}

@Suite("Reflection contract — EnumAttributeType (simple)")
struct ReflectionContractTests_EnumAttributeType_Simple {

    // MARK: LoopDirection

    @Test func loopDirection_typeName() {
        #expect(LoopDirection.typeName == "LoopDirection")
    }

    @Test func loopDirection_cases() {
        let cases: [(c: LoopDirection, value: String, readableName: String, alias: String, asString: String)] = [
            (.clockwise, "clockwise", "Clockwise", "Clockwise", "Clockwise"),
            (.counterClockwise, "counterClockwise", "CounterClockwise", "CounterClockwise", "CounterClockwise"),
            (.error, "error", "Error", "Error", "Error"),
        ]
        for e in cases {
            #expect(e.c.value == e.value, "LoopDirection.\(e.c).value")
            #expect(e.c.readableName == e.readableName, "LoopDirection.\(e.c).readableName")
            #expect(e.c.alias == e.alias, "LoopDirection.\(e.c).alias")
            #expect(e.c.asString == e.asString, "LoopDirection.\(e.c).asString")
        }
    }

    // MARK: LoopStyle  (no overrides — value == readableName == alias == asString == case name)

    @Test func loopStyle_typeName() {
        #expect(LoopStyle.typeName == "LoopStyle")
    }

    @Test func loopStyle_cases() {
        let cases: [(c: LoopStyle, name: String)] = [
            (.none, "none"),
            (.balancing, "balancing"),
            (.reinforcing, "reinforcing"),
        ]
        for e in cases {
            #expect(e.c.value == e.name, "LoopStyle.\(e.c).value")
            #expect(e.c.readableName == e.name, "LoopStyle.\(e.c).readableName")
            #expect(e.c.alias == e.name, "LoopStyle.\(e.c).alias")
            #expect(e.c.asString == e.name, "LoopStyle.\(e.c).asString")
        }
    }

    // MARK: FoldingState

    @Test func foldingState_typeName() {
        #expect(FoldingState.typeName == "FoldingState")
    }

    @Test func foldingState_cases() {
        let cases: [(c: FoldingState, name: String)] = [
            (.normal, "normal"),
            (.folded, "folded"),
            (.hidden, "hidden"),
        ]
        for e in cases {
            #expect(e.c.value == e.name, "FoldingState.\(e.c).value")
            #expect(e.c.readableName == e.name, "FoldingState.\(e.c).readableName")
            #expect(e.c.alias == e.name, "FoldingState.\(e.c).alias")
            #expect(e.c.asString == e.name, "FoldingState.\(e.c).asString")
        }
    }

    // MARK: LayoutDirection

    @Test func layoutDirection_typeName() {
        #expect(LayoutDirection.typeName == "LayoutDirection")
    }

    @Test func layoutDirection_cases() {
        let cases: [(c: LayoutDirection, value: String, readableName: String, alias: String, asString: String)] = [
            (.topToBottom, "topToBottom", "Top to Bottom", "Top to Bottom", "Top to Bottom"),
            (.leftToRight, "leftToRight", "Left to Right", "Left to Right", "Left to Right"),
            (.bottomToTop, "bottomToTop", "Bottom to Top", "Bottom to Top", "Bottom to Top"),
            (.rightToLeft, "rightToLeft", "Right to Left", "Right to Left", "Right to Left"),
        ]
        for e in cases {
            #expect(e.c.value == e.value, "LayoutDirection.\(e.c).value")
            #expect(e.c.readableName == e.readableName, "LayoutDirection.\(e.c).readableName")
            #expect(e.c.alias == e.alias, "LayoutDirection.\(e.c).alias")
            #expect(e.c.asString == e.asString, "LayoutDirection.\(e.c).asString")
        }
    }

    // MARK: GraphStyleType  (no overrides anywhere)

    @Test func graphStyleType_typeName() {
        #expect(GraphStyleType.typeName == "GraphStyleType")
    }

    @Test func graphStyleType_cases() {
        let cases: [(c: GraphStyleType, name: String)] = [
            (.none, "none"),
            (.filled, "filled"),
            (.striped, "striped"),
            (.rounded, "rounded"),
        ]
        for e in cases {
            #expect(e.c.value == e.name, "GraphStyleType.\(e.c).value")
            #expect(e.c.readableName == e.name, "GraphStyleType.\(e.c).readableName")
            #expect(e.c.alias == e.name, "GraphStyleType.\(e.c).alias")
            #expect(e.c.asString == e.name, "GraphStyleType.\(e.c).asString")
        }
    }
}

@Suite("Reflection contract — EnumAttributeType (alias-override)")
struct ReflectionContractTests_EnumAttributeType_AliasOverride {

    // MARK: Attributes.Group.StyleType  (alias="" for .empty)

    @Test func groupStyleType_typeName() {
        // Nested type → pinned current behaviour (whatever reflection produces today)
        #expect(Attributes.Group.StyleType.typeName == "StyleType")
    }

    @Test func groupStyleType_cases() {
        let cases: [(c: Attributes.Group.StyleType, value: String, readableName: String, alias: String, asString: String)] = [
            (.empty, "empty", "empty", "", ""),
            (.filled, "filled", "filled", "filled", "filled"),
            (.striped, "striped", "striped", "striped", "striped"),
            (.rounded, "rounded", "rounded", "rounded", "rounded"),
            (.radial, "radial", "radial", "radial", "radial"),
        ]
        for e in cases {
            #expect(e.c.value == e.value, "Group.StyleType.\(e.c).value")
            #expect(e.c.readableName == e.readableName, "Group.StyleType.\(e.c).readableName")
            #expect(e.c.alias == e.alias, "Group.StyleType.\(e.c).alias")
            #expect(e.c.asString == e.asString, "Group.StyleType.\(e.c).asString")
        }
    }

    // MARK: Attributes.Group.Labeljust  (alias="" for .c)

    @Test func groupLabeljust_typeName() {
        #expect(Attributes.Group.Labeljust.typeName == "Labeljust")
    }

    @Test func groupLabeljust_cases() {
        let cases: [(c: Attributes.Group.Labeljust, value: String, readableName: String, alias: String, asString: String)] = [
            (.r, "r", "r", "r", "r"),
            (.l, "l", "l", "l", "l"),
            (.c, "c", "c", "", ""),
        ]
        for e in cases {
            #expect(e.c.value == e.value, "Group.Labeljust.\(e.c).value")
            #expect(e.c.readableName == e.readableName, "Group.Labeljust.\(e.c).readableName")
            #expect(e.c.alias == e.alias, "Group.Labeljust.\(e.c).alias")
            #expect(e.c.asString == e.asString, "Group.Labeljust.\(e.c).asString")
        }
    }

    // MARK: Attributes.Edge.StyleType  (alias="" for .empty; String-raw enum)

    @Test func edgeStyleType_typeName() {
        #expect(Attributes.Edge.StyleType.typeName == "StyleType")
    }

    @Test func edgeStyleType_cases() {
        let cases: [(c: Attributes.Edge.StyleType, value: String, readableName: String, alias: String, asString: String)] = [
            (.empty, "empty", "empty", "", ""),
            (.dashed, "dashed", "dashed", "dashed", "dashed"),
            (.dotted, "dotted", "dotted", "dotted", "dotted"),
            (.solid, "solid", "solid", "solid", "solid"),
            (.invis, "invis", "invis", "invis", "invis"),
            (.bold, "bold", "bold", "bold", "bold"),
            (.tapered, "tapered", "tapered", "tapered", "tapered"),
            (.radial, "radial", "radial", "radial", "radial"),
        ]
        for e in cases {
            #expect(e.c.value == e.value, "Edge.StyleType.\(e.c).value")
            #expect(e.c.readableName == e.readableName, "Edge.StyleType.\(e.c).readableName")
            #expect(e.c.alias == e.alias, "Edge.StyleType.\(e.c).alias")
            #expect(e.c.asString == e.asString, "Edge.StyleType.\(e.c).asString")
        }
    }
}

@Suite("Reflection contract — Associated-value enums")
struct ReflectionContractTests_AssociatedValueEnums {

    // MARK: RatioType  (mixed: non-assoc cases + numeric(Double))

    @Test func ratioType_typeName() {
        #expect(RatioType.typeName == "Ratio")
    }

    @Test func ratioType_nonAssocCases() {
        let cases: [(c: RatioType, readableName: String, asString: String)] = [
            (.fill, "Fill", "fill"),
            (.compress, "Compress", "compress"),
            (.expand, "Expand", "expand"),
            (.auto, "Auto", "auto"),
        ]
        for e in cases {
            #expect(e.c.readableName == e.readableName, "RatioType.\(e.c).readableName")
            #expect(e.c.asString == e.asString, "RatioType.\(e.c).asString")
        }
    }

    @Test func ratioType_numericCase() {
        let r = RatioType.numeric(2.5)
        #expect(r.readableName == "Numeric (2.5)")
        #expect(r.asString == "2.5")
    }

}
