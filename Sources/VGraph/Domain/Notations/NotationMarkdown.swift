// Invoked from `metadescription <Notation>` in VGL (see VGraphParser), but
// can also be called directly for CLI or WASM surfaces.

public enum NotationMarkdown {

    public static func render(
        entry: NotationEntry,
        displayTitle: String? = nil
    ) -> String {
        var lines: [String] = []

        let title = displayTitle ?? entry.id.id
        lines.append("# \(title)")
        lines.append("")

        let tagline = entry.description.trimmingWhitespace()
        if !tagline.isEmpty {
            lines.append("> \(tagline)")
            lines.append("")
        }

        let purpose = entry.purpose.trimmingWhitespace()
        if !purpose.isEmpty {
            lines.append("## Purpose")
            lines.append("")
            lines.append(purpose)
            lines.append("")
        }

        let whenToUse = entry.whenToUse.map { $0.trimmingWhitespace() }.filter { !$0.isEmpty }
        if !whenToUse.isEmpty {
            lines.append("## When to use")
            lines.append("")
            for bullet in whenToUse {
                lines.append("- \(bullet)")
            }
            lines.append("")
        }

        let nodeDefs = entry.nodeTypeDefinitions
        if !nodeDefs.isEmpty {
            lines.append("## Node types")
            lines.append("")
            lines.append("| Type | Description |")
            lines.append("|------|-------------|")
            for def in nodeDefs {
                let typeId = def.nodeType.id
                let desc = escapeTableCell(def.description)
                lines.append("| \(typeId) | \(desc) |")
            }
            lines.append("")
        }

        let edgeDefs = entry.edgeTypeDefinitions
        if !edgeDefs.isEmpty {
            lines.append("## Edge types")
            lines.append("")
            lines.append("| From → To | Meaning |")
            lines.append("|-----------|---------|")
            for def in edgeDefs {
                let from = def.edgeType.from.id
                let to = def.edgeType.to.id
                let desc = escapeTableCell(def.description)
                lines.append("| \(from) → \(to) | \(desc) |")
            }
            lines.append("")
        }

        // Carries the syntax line as well as the table: a reader shown only the
        // type names still would not know a group can be typed at all.
        let groupDefs = entry.groupTypeDefinitions
        if !groupDefs.isEmpty {
            lines.append("## Group types")
            lines.append("")
            lines.append("Boundaries: `group <id>: <GroupType> \"<label>\" { … }`")
            lines.append("")
            lines.append("| Type | Description |")
            lines.append("|------|-------------|")
            for def in groupDefs {
                let typeId = def.groupType.id
                let desc = escapeTableCell(def.description)
                lines.append("| \(typeId) | \(desc) |")
            }
            lines.append("")
        }

        let detailings = entry.content.detailings
        if !detailings.isEmpty {
            lines.append("## Detailings")
            lines.append("")
            lines.append("A detailed node holds nodes of its detail types: `group <id>: <NodeType> \"<label>\" { … }`")
            lines.append("")
            lines.append("| Type | Detailed by |")
            lines.append("|------|-------------|")
            for detailing in detailings {
                let detailTypes = detailing.detailTypes.map { $0.id }.joined(separator: ", ")
                lines.append("| \(detailing.nodeType.id) | \(detailTypes) |")
            }
            lines.append("")
        }

        let history = entry.history.trimmingWhitespace()
        if !history.isEmpty {
            lines.append("## History")
            lines.append("")
            lines.append(history)
            lines.append("")
        }

        let refs = entry.references
        if !refs.isEmpty {
            lines.append("## References")
            lines.append("")
            for ref in refs {
                if let url = ref.url, !url.isEmpty {
                    lines.append("- [\(ref.title)](\(url))")
                } else {
                    lines.append("- \(ref.title)")
                }
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
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
