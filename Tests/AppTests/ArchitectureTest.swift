// Structural rules the compiler cannot enforce. Both held by convention until
// something quietly broke them.

import Foundation
import Testing

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // AppTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // repo root

private func swiftFiles(under path: String) -> [URL] {
    let root = repoRoot.appendingPathComponent(path)
    guard let walker = FileManager.default.enumerator(atPath: root.path) else { return [] }
    return walker.compactMap { entry in
        guard let name = entry as? String, name.hasSuffix(".swift") else { return nil }
        return root.appendingPathComponent(name)
    }
}

struct ArchitectureTest {
    /// The use-case layer must see ports only. An adapter import here means a
    /// concrete technology reached the domain and the seam is gone; the wiring
    /// belongs in `Sources/App/Composition/`.
    @Test func appDomainImportsNoAdapterModules() throws {
        let allowed: Set<String> = ["VGraph", "MathUtils"]
        var violations: [String] = []

        for file in swiftFiles(under: "Sources/App/Domain") {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n") where line.hasPrefix("import ") {
                let module = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
                if !allowed.contains(module) {
                    violations.append("\(file.lastPathComponent): import \(module)")
                }
            }
        }

        #expect(violations.isEmpty, "adapter imports in App/Domain: \(violations)")
    }

    /// A driver reaches its adapters through `App`'s composition and never names
    /// one, so that swapping a wiring is a change in one place.
    ///
    /// Only this notices. SwiftPM lets a target import anything in its
    /// *transitive* graph, so removing `VGraphSVG` from a driver's dependency
    /// list does not stop it importing `VGraphSVG` — verified by adding the
    /// import and a live `VSVGRenderer` to `vgraph-cli`, which compiled and
    /// linked with the dependency gone.
    ///
    /// `VGraphWasm` is deliberately not covered: ADR-0015's F1 mounts the
    /// preview by building an ElementaryUI view over `VSVGNode`, so the wasm
    /// editor is *meant* to depend on the SVG hexagon's IR.
    @Test func nativeDriversImportNoAdapterModules() throws {
        let adapters: Set<String> = ["VGraphSVG", "VGLanguage", "VGraphvizLib"]
        var violations: [String] = []

        for driver in [
            "Sources/VGraphCLI", "Sources/VGraphMCP", "Sources/VGraphMCPHTTP",
            "Sources/VGraphMCPTools", "Tests/TestSupport",
        ] {
            for file in swiftFiles(under: driver) {
                let source = try String(contentsOf: file, encoding: .utf8)
                for line in source.split(separator: "\n") where line.hasPrefix("import ") {
                    let module = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
                    if adapters.contains(module) {
                        violations.append("\(file.lastPathComponent): import \(module)")
                    }
                }
            }
        }

        #expect(violations.isEmpty, "adapter imports in a driver: \(violations)")
    }

    /// Each core port is declared `VFor*` and re-exported as `For*` by the
    /// hexagons that speak it — the re-export *is* that hexagon's port
    /// declaration. Collapsing the two names still compiles and still passes
    /// every behavioural test, so nothing but this check notices.
    /// See docs/hexagonal-architecture.md.
    @Test func everyCorePortIsReExportedUnderItsPlainName() throws {
        var declared: [String] = []
        for file in swiftFiles(under: "Sources/VGraph/VStdPorts") {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n") {
                guard let range = line.range(of: "public protocol VFor") else { continue }
                let rest = line[range.lowerBound...].dropFirst("public protocol ".count)
                let name = rest.prefix { $0.isLetter || $0.isNumber }
                declared.append(String(name))
            }
        }

        #expect(!declared.isEmpty, "no VFor* ports found — did the layout move?")

        var reExports: Set<String> = []
        for file in swiftFiles(under: "Sources") {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n") where line.contains("typealias") {
                guard let eq = line.firstIndex(of: "=") else { continue }
                let rhs = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                if rhs.hasPrefix("VFor") { reExports.insert(rhs) }
            }
        }

        let missing = declared.filter { !reExports.contains($0) }
        #expect(missing.isEmpty, "core ports with no For* re-export: \(missing)")
    }

    // MARK: - Embedded Swift

    /// The wasm graph compiles under Embedded Swift, which rejects key paths and
    /// prints `(cannot print value in embedded Swift)` for a type interpolated
    /// by reflection. A native-only `swift test` never compiles that graph, so
    /// without this the first signal is a failed wasm build.
    @Test func wasmGraphUsesNoKeyPathsOrReflectedTypeNames() throws {
        var violations: [String] = []
        for file in wasmGraphSwiftFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for hit in embeddedViolations(in: source) {
                violations.append("\(file.lastPathComponent): \(hit)")
            }
        }
        #expect(violations.isEmpty, "not Embedded-compatible: \(violations)")
    }

    @Test func embeddedCheckSeesKeyPathsAndReflectedTypeNames() {
        #expect(embeddedViolations(in: "xs.map(\\.id)").count == 1)
        #expect(embeddedViolations(in: "xs.map(\\Node.id)").count == 1)
        #expect(embeddedViolations(in: "\"\\(type(of: x))\"").count == 1)
        #expect(embeddedViolations(in: "xs.map { $0.id }").isEmpty)
        #expect(embeddedViolations(in: "// map(\\.id) fails to compile").isEmpty)
        #expect(embeddedViolations(in: "\"line\\n\\(x)\"").isEmpty)
    }

    // MARK: - Driving ports (ADR-0013)

    /// The three driving ports must not overlap. This is the *negative* half of
    /// the split and the only half worth enforcing: `DrivingPortsTest` shows
    /// each pane can do its own job, while what the ADR actually bought is that
    /// a diagram pane **cannot** reach `textEdited`, and a text pane cannot
    /// render or undo. Nothing else notices if a member joins a second port —
    /// everything still compiles and every behavioural test still passes.
    @Test func drivingPortSurfacesAreDisjoint() throws {
        let ports = try drivingPortMembers()
        #expect(ports.count == 3, "expected three driving ports, found \(ports.keys.sorted())")

        var overlaps: [String] = []
        for (one, two) in pairs(of: ports.keys.sorted()) {
            let shared = ports[one]!.intersection(ports[two]!).sorted()
            if !shared.isEmpty { overlaps.append("\(one) ∩ \(two) = \(shared)") }
        }

        #expect(overlaps.isEmpty, "driving ports share members: \(overlaps)")
    }

    /// The ADR's table, as a fixture. A member moving between actors is a real
    /// decision — this is what makes it a deliberate one rather than a diff
    /// nobody read.
    @Test func eachDrivingPortOffersExactlyItsActorsSurface() throws {
        let expected: [String: Set<String>] = [
            "ForEditVGL": ["textEdited", "textEditingEnded", "highlightHTML"],
            "ForEditAGraphVisually": [
                "label", "render",
                // Named commands, growing alongside the generic path (phase 4).
                "toggleFolding", "delete", "setLabel", "setURL", "removeURL", "urlToOpen",
                // Grouping's inverse, and deliberately not the same command as
                // `delete`, which takes the contents with it (ADR-0018).
                "ungroup",
                // A node becoming a detailed node, and whether its type allows
                // it — a model command, never a side effect of unfolding
                // (ADR-0032).
                "decompose", "canDecompose",
                "changeDirection", "split", "addSuccessor", "addPredecessor", "connect", "changeType",
                // Widening the notation rather than breaking it: the way *out*
                // of a break, on an edge wearing a minted type (ADR-0024).
                "declareEdgeType", "hasUnknownType",
                // A node born attached to nothing, in the group pointed at — the
                // root group when that is blank canvas (ADR-0016).
                "addNode",
                // A group made of several elements at once. Both the strict and
                // the detaching form (ADR-0018).
                "addGroup",
                // Queries that replace `origin` for menu building (phase 5).
                "kind", "nodeType", "isDetailed", "detailCount", "isFolded", "storedURL", "canRename", "nodeTypes",
                "rootGroupId",
                // A group's boundary kind, and the kinds on offer — what makes
                // `changeType` answerable for a group (ADR-0020).
                "groupTypes", "groupType",
                "successorCandidates", "predecessorCandidates", "retypeCandidates",
                "reverseCandidates", "splitCandidates", "connectCandidates", "ambiguousEdges",
                "connectSources", "connectTargets",
                // What a chooser calls a relationship, for the notations whose
                // edge-type ids do not read as a menu entry.
                "menuTitle",
                // Questions about a *set* of elements, which is what the pane
                // holds once it has a [[Selection]] the domain never sees
                // (ADR-0018).
                "outermostElements", "groupingTarget",
                // Reparenting, and where a drag may drop (ADR-0019).
                "move", "moveDestinations",
                // Moving one edge end to another node, and where it may land
                // (ADR-0021).
                "reattach", "reattachTargets", "reattachCandidates",
                // The node at one end of an edge, for a reattach choice prompt.
                "node",
                // Which loops a CLD marks, a setting of the whole diagram offered
                // on the canvas menu (ADR-0028).
                "loopMarkers", "setLoopMarkers",
                // The same for the layout direction, and the views: which one is
                // shown, and making, relabelling and deleting them (ADR-0029).
                "layoutDirection", "setLayoutDirection",
                "views", "activeView", "selectView", "createView", "duplicateActiveView", "renameView",
                "deleteView",
            ],
            "ForManageADocument": [
                "replaceDocument", "exportVGL", "canUndo", "canRedo", "undo", "redo",
                // Opening a [[Diagram as document]]: the VGL an artefact carries,
                // relayed to the renderer that chose how to carry it. On the
                // toolbar's port because the pane draws and the toolbar opens.
                "sourceVGL",
            ],
        ]

        #expect(try drivingPortMembers() == expected)
    }

    /// Every public member of `GraphSession` belongs to a driving port or is on
    /// the list of things deliberately left off one. The ADR calls this "a small
    /// tax on each addition, and it is the point" — a wish until something
    /// collects it.
    @Test func everyPublicSessionMemberHasAPortDecision() throws {
        /// Deliberately on no port: an inspection surface rather than an editing
        /// one — `origin` included, since the diagram pane reads the graph
        /// through `label(of:)` and nothing else (ADR-0013).
        ///
        /// The generic path is no longer *public* at all, so it drops out of
        /// this check by itself rather than needing an entry here.
        let noPort: Set<String> = [
            "origin", "currentVersion", "diff", "diffToParent", "unifiedDiffToParent",
        ]

        let onSomePort = try drivingPortMembers().values.reduce(into: Set<String>()) {
            $0.formUnion($1)
        }
        let undecided = try publicMembersOfGraphSession()
            .subtracting(onSomePort)
            .subtracting(noPort)

        #expect(
            undecided.isEmpty,
            """
            public GraphSession members on no port and not listed as deliberate: \
            \(undecided.sorted()). Put each on one of the three driving ports, or \
            add it to `noPort` above with a reason.
            """)
    }

    /// A driving port obeys the same two-name rule as a driven one: declared
    /// once in the core as `VFor*`, re-exported under its plain name by the
    /// hexagon that speaks it (AGENTS.md, "Each port protocol is declared in the
    /// core"). ADR-0013 originally exempted them and let `Ports/Inbound/`
    /// declare its own protocols; that exemption is withdrawn, so the two port
    /// folders now read alike.
    ///
    /// The mirror of `everyCorePortIsReExportedUnderItsPlainName`: that one
    /// checks every core port reaches a hexagon, this one that no driving port
    /// skips the core on its way there.
    @Test func everyDrivingPortIsDeclaredInTheCore() throws {
        let declaredInCore = try protocolMembers(under: "Sources/VGraph/VStdPorts").keys
        var missing: [String] = []
        for port in try drivingPortNames() where !declaredInCore.contains("V\(port)") {
            missing.append(port)
        }

        #expect(missing.isEmpty, "driving ports not declared in VStdPorts: \(missing.sorted())")
    }

    /// `Ports/Inbound/` holds re-exports and nothing else. A `protocol` here is
    /// the old shape growing back, and it compiles perfectly well — only this
    /// notices.
    @Test func inboundDeclaresNoProtocolOfItsOwn() throws {
        let declared = try protocolMembers(under: "Sources/App/Ports/Inbound").keys.sorted()
        #expect(declared.isEmpty, "protocols declared in Ports/Inbound: \(declared)")
    }

}

// MARK: - Reading the declarations

/// The plain names `Ports/Inbound/` re-exports — which ports App *offers*. The
/// folder is the list; the declarations it points at live in the core.
private func drivingPortNames() throws -> Set<String> {
    var result: Set<String> = []

    for file in swiftFiles(under: "Sources/App/Ports/Inbound") {
        let source = try String(contentsOf: file, encoding: .utf8)
        for raw in source.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("public typealias "), let eq = line.firstIndex(of: "=") else {
                continue
            }
            let name = line.dropFirst("public typealias ".count).prefix { $0.isLetter || $0.isNumber }
            let rhs = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if rhs == "V\(name)" { result.insert(String(name)) }
        }
    }

    return result
}

/// Requirement names per driving port, keyed by the *plain* name — so the ADR's
/// table stays readable even though the declaration is `VFor*` in the core. Base
/// names only: overloads are one member of one actor's surface.
private func drivingPortMembers() throws -> [String: Set<String>] {
    let core = try protocolMembers(under: "Sources/VGraph/VStdPorts")
    var result: [String: Set<String>] = [:]

    for port in try drivingPortNames() {
        guard let members = core["V\(port)"] else { continue }
        result[port] = members
    }

    return result
}

/// Every `public protocol` declared under `path`, with the member names in its
/// body. One protocol per file is the convention everywhere this reads.
private func protocolMembers(under path: String) throws -> [String: Set<String>] {
    var result: [String: Set<String>] = [:]

    for file in swiftFiles(under: path) {
        let source = try String(contentsOf: file, encoding: .utf8)
        var name: String?
        var members: Set<String> = []

        for raw in source.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("public protocol ") {
                name = String(
                    line.dropFirst("public protocol ".count).prefix { $0.isLetter || $0.isNumber })
            } else if let member = declaredMemberName(in: line) {
                members.insert(member)
            }
        }

        if let name { result[name] = members }
    }

    return result
}

/// `public` members of `GraphSession`, less `init`.
private func publicMembersOfGraphSession() throws -> Set<String> {
    let file = repoRoot.appendingPathComponent("Sources/App/Domain/GraphSession.swift")
    let source = try String(contentsOf: file, encoding: .utf8)
    var result: Set<String> = []

    for raw in source.split(separator: "\n") {
        var line = raw.trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("public ") else { continue }
        line = String(line.dropFirst("public ".count))
        // `public private(set) var origin` — the access modifier on the setter
        // does not change that the getter is public.
        if line.hasPrefix("private(set) ") { line = String(line.dropFirst("private(set) ".count)) }
        if let member = declaredMemberName(in: line), member != "init" { result.insert(member) }
    }

    return result
}

/// The name a `func`/`var` line declares, or `nil` for anything else — a
/// comment, an attribute, a continuation line, a nested `where` clause.
private func declaredMemberName(in line: String) -> String? {
    if line.hasPrefix("func ") {
        return String(line.dropFirst("func ".count).prefix { $0.isLetter || $0.isNumber })
    }
    if line.hasPrefix("var ") {
        return String(line.dropFirst("var ".count).prefix { $0.isLetter || $0.isNumber })
    }
    return nil
}

private func pairs(of names: [String]) -> [(String, String)] {
    var result: [(String, String)] = []
    for i in names.indices {
        for j in names.indices where j > i { result.append((names[i], names[j])) }
    }
    return result
}

/// Targets compiled into the wasm module (AGENTS.md, "Embedded Swift").
/// `VGraphWasm/Sources/Generated` is BridgeJS output, not hand-written.
private func wasmGraphSwiftFiles() -> [URL] {
    let dirs = [
        "Sources/VGraph", "Sources/VGLanguage", "Sources/VGraphSVG", "Sources/VGraphvizLib",
        "Sources/App", "Sources/EditorCore", "Sources/MathUtils", "VGraphWasm/VGraphEditor",
    ]
    let main = repoRoot.appendingPathComponent("VGraphWasm/Sources/Main.swift")
    return dirs.flatMap(swiftFiles(under:)) + [main]
}

private func embeddedViolations(in source: String) -> [String] {
    var hits: [String] = []
    for (index, raw) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("//") { continue }
        let isKeyPath = line.range(of: #"\\(\.|[A-Z][A-Za-z0-9_]*\.)[A-Za-z_]"#, options: .regularExpression) != nil
        if isKeyPath { hits.append("line \(index + 1): key path") }
        if line.contains("\\(type(of:") { hits.append("line \(index + 1): reflected type name") }
    }
    return hits
}
