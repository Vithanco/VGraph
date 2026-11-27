// Invoked from `metadescription <Notation>` in VGL (see VGraphParser), but
// can also be called directly for CLI or WASM surfaces.

public enum NotationMarkdown {

    public static func render(
        entry: NotationEntry,
        displayTitle: String? = nil
    ) -> String {
        let sections: [[String]?] = [
            ["# \(displayTitle ?? entry.id.id)"],
            nonEmpty(entry.description.trimmingWhitespace()).map { ["> \($0)"] },
            paragraph("Purpose", entry.purpose),
            bulletList("When to use", entry.whenToUse.map { $0.trimmingWhitespace() }.filter { !$0.isEmpty }),
            nodeTypesTable(entry.nodeTypeDefinitions),
            Table(
                heading: "Edge types", intro: nil, header: ["From → To", "Meaning"],
                rows: entry.edgeTypeDefinitions.map {
                    ["\($0.edgeType.from.id) → \($0.edgeType.to.id)", escapeTableCell($0.description)]
                }
            ).lines,
            // Carries the syntax line as well as the table: a reader shown only the
            // type names still would not know a group can be typed at all.
            Table(
                heading: "Group types", intro: "A typed group: `group <id>: <GroupType> \"<label>\" { … }`",
                header: ["Type", "Description"],
                rows: entry.groupTypeDefinitions.map { [$0.groupType.id, escapeTableCell($0.description)] }
            ).lines,
            Table(
                heading: "Detailings",
                intro: "A detailed node holds nodes of its detail types: `group <id>: <NodeType> \"<label>\" { … }`",
                header: ["Type", "Detailed by"],
                rows: entry.content.detailings.map {
                    [$0.nodeType.id, $0.detailTypes.map { $0.id }.joined(separator: ", ")]
                }
            ).lines,
            checksSection(Notations.rules(of: entry)),
            paragraph("History", entry.history),
            bulletList("References", entry.references.map(link)),
        ]
        return page(sections)
    }

    /// The notation `graph` is written in. A `vnotation` lives in the document
    /// that declares it, not in the registry, so it is described from the graph
    /// that document parses into: what it checks, as nothing more is written down.
    public static func render(notationOf graph: VGraph, displayTitle: String? = nil) -> String {
        page([["# \(displayTitle ?? graph.notationName)"], checksSection(Notations.rules(in: graph))])
    }

    /// The checks no notation states as its own: told once, not per notation.
    public static func renderCommonChecks() -> String {
        page([["# Checks every notation runs"], bulletList(checksHeading, GenericQualityChecks.all.map { $0.rule })])
    }

    private static let checksHeading = "What Vithanco checks"

    private static func nodeTypesTable(_ definitions: [NodeTypeDefinition]) -> [String]? {
        let hasOtherNames = definitions.contains { !$0.alsoCalled.isEmpty }
        return Table(
            heading: "Node types", intro: nil,
            header: hasOtherNames ? ["Type", "Also called", "Description"] : ["Type", "Description"],
            rows: definitions.map {
                [inWords($0.nodeType.id)] + (hasOtherNames ? [$0.alsoCalled.joined(separator: ", ")] : [])
                    + [escapeTableCell($0.description)]
            }
        ).lines
    }

    /// `CriticalSuccessFactor` → `Critical Success Factor`; a run of capitals (`OR`) stays one word.
    private static func inWords(_ identifier: String) -> String {
        let characters = Array(identifier)
        var result = ""
        for (index, character) in characters.enumerated() {
            let previous = index > 0 ? characters[index - 1] : nil
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            let startsWord =
                character.isUppercase && previous.map { !$0.isUppercase || (next?.isLowercase ?? false) } ?? false
            if startsWord { result.append(" ") }
            result.append(character)
        }
        return result
    }

    /// Always present, so a page showing it never looks forgotten.
    private static func checksSection(_ rules: [String]) -> [String] {
        bulletList(checksHeading, rules) ?? ["## \(checksHeading)", "", "Only the checks every notation runs."]
    }

    private static func page(_ sections: [[String]?]) -> String {
        sections.compactMap { $0 }.map { ($0 + [""]).joined(separator: "\n") }.joined(separator: "\n")
    }

    private static func nonEmpty(_ text: String) -> String? {
        text.isEmpty ? nil : text
    }

    private static func paragraph(_ heading: String, _ text: String) -> [String]? {
        nonEmpty(text.trimmingWhitespace()).map { ["## \(heading)", "", $0] }
    }

    private static func bulletList(_ heading: String, _ bullets: [String]) -> [String]? {
        bullets.isEmpty ? nil : ["## \(heading)", ""] + bullets.map { "- \($0)" }
    }

    private struct Table {
        let heading: String
        let intro: String?
        let header: [String]
        let rows: [[String]]

        var lines: [String]? {
            guard !rows.isEmpty else { return nil }
            let introLines = intro.map { [$0, ""] } ?? []
            let separator = "|" + header.map { String(repeating: "-", count: $0.count + 2) }.joined(separator: "|") + "|"
            return ["## \(heading)", ""] + introLines + [row(header), separator] + rows.map { row($0) }
        }

        private func row(_ cells: [String]) -> String {
            "|" + cells.map { " \($0) " }.joined(separator: "|") + "|"
        }
    }

    private static func link(_ reference: NotationReference) -> String {
        guard let url = reference.url, !url.isEmpty else { return reference.title }
        return "[\(reference.title)](\(url))"
    }

    // MARK: - Tool-prompt fragments
    //
    // Narrower than `render(entry:)`: no title, tagline, or page-level
    // sections, so a `VGraphTool` can interpolate just the type facts into a
    // hand-written description without a heading-level collision. Reading
    // these live is what keeps a tool's type list from silently omitting a
    // type its own notation declares.

    /// `- \`Id\` — description`, one line per node type.
    public static func nodeTypeBullets(_ definitions: [NodeTypeDefinition]) -> String {
        definitions.map { "- `\($0.nodeType.id)` — \($0.description)" }.joined(separator: "\n")
    }

    /// `- \`Id\` — description`, one line per edge type, keyed by the edge
    /// type's own id. Use for notations where that id is the literal VGL
    /// token (`edge a -> b: <id>`).
    public static func edgeTypeBullets(_ definitions: [EdgeTypeDefinition]) -> String {
        definitions.map { "- `\($0.edgeType.id)` — \($0.description)" }.joined(separator: "\n")
    }

    /// `- From → To — description`, one line per edge type, keyed by its
    /// node-type pair. Use for notations where the edge type is inferred
    /// from that pair and never written explicitly in VGL.
    public static func edgeConnectionBullets(_ definitions: [EdgeTypeDefinition]) -> String {
        definitions.map { "- \($0.edgeType.from.id) → \($0.edgeType.to.id) — \($0.description)" }.joined(separator: "\n")
    }

    private static func escapeTableCell(_ text: String) -> String {
        let singleLine =
            text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        return singleLine.replacingOccurrences(of: "|", with: "\\|")
    }
}
