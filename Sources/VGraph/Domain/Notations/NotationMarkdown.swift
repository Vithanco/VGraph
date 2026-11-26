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
            Table(
                heading: "Node types", intro: nil, header: ["Type", "Description"],
                rows: entry.nodeTypeDefinitions.map { [$0.nodeType.id, escapeTableCell($0.description)] }
            ).lines,
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
            checksSection(Notations.rules(of: entry), otherwise: "Only the checks every notation runs."),
            paragraph("History", entry.history),
            bulletList("References", entry.references.map(link)),
        ]
        return sections.compactMap { $0 }.map { ($0 + [""]).joined(separator: "\n") }.joined(separator: "\n")
    }

    /// The checks no notation states as its own: told once, not per notation.
    public static func renderCommonChecks() -> String {
        let sections = [["# Checks every notation runs"], checksSection(GenericQualityChecks.all.map { $0.rule })]
        return sections.compactMap { $0 }.map { ($0 + [""]).joined(separator: "\n") }.joined(separator: "\n")
    }

    /// Always present when `otherwise` is given, so a page showing it never looks forgotten.
    private static func checksSection(_ rules: [String], otherwise: String? = nil) -> [String]? {
        let heading = "What Vithanco checks"
        if let list = bulletList(heading, rules) { return list }
        return otherwise.map { ["## \(heading)", "", $0] }
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
