// VGraph Parser
// A parser for the VGraph grammar, depending on nothing outside the package.

import VGraph

class Parser {
    private let tokens: [Token]
    private var current = 0
    private var nodeIds: Set<String> = []

    private let comments: [LexedComment]
    private var commentCursor = 0

    // Highlight side-tables, populated as a by-product of parsing and consumed by
    // the semantic highlighter. Identifier roles by token start offset; node/edge
    // source spans by id (duplicate edge endpoints: last wins).
    private(set) var semanticIdentifiers: [Int: VGLTokenRole] = [:]

    /// Token start offset → the icon name at it. A node type's icon is a quoted
    /// string, so the highlighter cannot spot it the way it spots a node type.
    private(set) var iconNameSpans: [Int: String] = [:]
    /// A name a view's statement gives, by token start: checked against the graph
    /// afterwards, since a view may name what the model no longer has.
    private(set) var viewNames: [Int: (name: String, isGroup: Bool)] = [:]
    /// A group declaration's type, by token start: there a node type is valid
    /// too, making a detailed node (ADR-0032). A view's `group type:` is not.
    private(set) var groupTypeSlots: Set<Int> = []
    private(set) var nodeSpans: [String: (start: Int, length: Int)] = [:]
    private(set) var edgeSpans: [String: (start: Int, length: Int)] = [:]

    static func edgeSpanKey(from: String, to: String) -> String { "\(from)\u{1}\(to)" }

    init(tokens: [Token], comments: [LexedComment] = []) {
        self.tokens = tokens
        self.comments = comments
    }

    // MARK: - Comment attachment

    /// Blank lines *inside* the run are restored from the gaps between the
    /// comments' line numbers; the run's edges never held any.
    private func takeLeadingComments(before line: Int) -> String? {
        var lines: [String] = []
        var previousLine = 0
        while commentCursor < comments.count, comments[commentCursor].line < line {
            let comment = comments[commentCursor]
            commentCursor += 1
            if comment.isTrailing { continue }
            if !lines.isEmpty {
                for _ in 0..<(comment.line - previousLine - 1) { lines.append("") }
            }
            lines.append(comment.text)
            previousLine = comment.line
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// Dropping these *here* is what makes them dropped at all: left unclaimed,
    /// they would be taken as the leading run of the next declaration after the
    /// brace — annotating something they never described.
    private func discardComments(throughLine line: Int) {
        while commentCursor < comments.count, comments[commentCursor].line <= line {
            commentCursor += 1
        }
    }

    private func takeTrailingComment(on line: Int) -> String? {
        guard commentCursor < comments.count else { return nil }
        let comment = comments[commentCursor]
        guard comment.isTrailing, comment.line == line else { return nil }
        commentCursor += 1
        return comment.text
    }

    func parse() throws(VParserError) -> ASTNode {
        // Collect zero or more vnotation declarations
        // (must appear before vgraph/metagraph/metadescription).
        var vnotations: [ASTNode] = []
        while check(.vnotation) {
            vnotations.append(try vnotationDecl())
        }
        if check(.vview) {
            throw VParserError.unexpectedToken("'vview' must come after the vgraph block, not before it")
        }
        let doc: ASTNode
        if check(.metagraph) {
            doc = try metagraphDecl()
        } else if check(.metadescription) {
            doc = try metadescriptionDecl()
        } else {
            doc = try document()
        }
        var views: [VViewDecl] = []
        while check(.vview) {
            let view = try viewDecl()
            guard !views.contains(where: { $0.name == view.name }) else {
                throw VParserError.unexpectedToken("View '\(view.name)' is declared twice")
            }
            views.append(view)
        }
        if vnotations.isEmpty && views.isEmpty {
            // backward compatible: plain vgraph/metagraph/metadescription files
            // return the node directly
            return doc
        }
        return .file(vnotations: vnotations, document: doc, views: views)
    }

    private static let presentationOnly = "a view sets presentation only"

    private static let edgesAreNeverSelected = "A view holds no edges: edges are never selected, one shows when both its ends do"
    private static let foldedNeedsAGroup = "Expected 'group' or 'node type:' after 'folded'"

    private func viewRule() throws(VParserError) -> ViewRule {
        let word = advance().lexeme
        markPrevious(.keyword)
        if word == "expand" {
            guard check(.number), let steps = Int(peek().lexeme), steps >= 0 else {
                throw VParserError.unexpectedToken("expand needs a whole number of steps, as in 'expand 1'")
            }
            _ = advance()
            _ = match(.semicolon)
            return .expand(steps)
        }
        let selector = try selector(after: word)
        _ = match(.semicolon)
        return word == "include" ? .include(selector) : .exclude(selector)
    }

    private func selector(after word: String) throws(VParserError) -> Selector {
        let subject: Selector.Subject
        if check(.unknown), peek().lexeme == "*" {
            _ = advance()
            subject = .everything
        } else if check(.edge) {
            throw VParserError.unexpectedToken(Parser.edgesAreNeverSelected)
        } else if check(.node) || check(.group) {
            let isNode = advance().type == .node
            let isType = check(.identifier) && peek().lexeme == "type" && checkNext(.colon)
            if isType {
                _ = advance()
                markPrevious(.keyword)
                _ = advance()
            }
            var names: [String] = []
            repeat {
                let role: VGLTokenRole = isType ? (isNode ? .nodeType : .groupType) : .nodeId
                names.append(try identifier(role))
                if !isType { viewNames[previous().start] = (names[names.count - 1], !isNode) }
            } while match(.comma)
            switch (isNode, isType) {
            case (true, false): subject = .nodes(names)
            case (true, true): subject = .nodeTypes(names)
            case (false, false): subject = .groups(names)
            case (false, true): subject = .groupTypes(names)
            }
        } else {
            throw VParserError.unexpectedToken("'\(word)' takes node, group or *")
        }

        var reach: Selector.Reach?
        if check(.unknown), peek().lexeme == "+" {
            _ = advance()
            reach = .around(try distance(after: "+"))
        } else if check(.identifier), ["downstream", "upstream"].contains(peek().lexeme) {
            let direction = advance().lexeme
            markPrevious(.keyword)
            let steps = try distance(after: direction)
            reach = direction == "downstream" ? .downstream(steps) : .upstream(steps)
        }
        if check(.leftBracket) {
            throw VParserError.unexpectedToken("\(word) only chooses elements; it sets no attribute")
        }
        return Selector(subject, reach: reach)
    }

    private func distance(after word: String) throws(VParserError) -> Int {
        guard check(.number), let steps = Int(peek().lexeme), steps >= 0 else {
            throw VParserError.unexpectedToken("the distance is missing after '\(word)': a whole number of steps")
        }
        _ = advance()
        return steps
    }

    private func notSupportedYet(_ what: String) -> VParserError {
        .unexpectedToken("\(what) is not supported yet in a view; selectors and rules come later")
    }

    private func viewDecl() throws(VParserError) -> VViewDecl {
        try consume(.vview, "Expected 'vview'")
        let name = try identifier()
        let label = try optionalLabel()
        let attrs = try parseVNotationAttrs()
        try consume(.leftBrace, "Expected '{' after vview declaration")
        var statements: [VViewStatementDecl] = []
        var rules: [ViewRule] = []
        while !check(.rightBrace) && !isAtEnd() {
            if check(.identifier), ["include", "exclude", "expand"].contains(peek().lexeme) {
                rules.append(try viewRule())
            } else {
                statements.append(try viewStatement())
            }
        }
        discardComments(throughLine: peek().line)
        try consume(.rightBrace, "Expected '}' after vview body")
        return VViewDecl(name: name, label: label, attrs: attrs, statements: statements, rules: rules)
    }

    private func viewStatement() throws(VParserError) -> VViewStatementDecl {
        if check(.edge) { throw VParserError.unexpectedToken(Parser.edgesAreNeverSelected) }
        if check(.vview) { throw VParserError.unexpectedToken("A vview cannot sit inside another") }

        let folded = match(.folded)
        let target: VViewStatementDecl.Target
        if match(.group) {
            target = .group
        } else if match(.node) {
            target = .node
        } else {
            throw VParserError.unexpectedToken(
                folded ? Parser.foldedNeedsAGroup : "A view holds node and group statements")
        }

        let isType = check(.identifier) && peek().lexeme == "type" && checkNext(.colon)
        // Only a group folds; a node type may, for its detailed nodes (ADR-0032).
        if folded, target == .node, !isType { throw VParserError.unexpectedToken(Parser.foldedNeedsAGroup) }
        if isType {
            _ = advance()
            _ = advance()
        }

        var names: [String] = []
        repeat {
            if check(.unknown), ["*", "+"].contains(peek().lexeme) {
                throw notSupportedYet("'\(peek().lexeme)'")
            }
            if check(.identifier), ["downstream", "upstream"].contains(peek().lexeme), checkNext(.identifier) {
                throw notSupportedYet("'\(peek().lexeme)'")
            }
            let role: VGLTokenRole = isType ? (target == .node ? .nodeType : .groupType) : .nodeId
            names.append(try identifier(role))
            if !isType { viewNames[previous().start] = (names[names.count - 1], target == .group) }
        } while match(.comma)

        if check(.colon) || check(.label) || check(.leftBrace) {
            let what = check(.colon) ? "give an element a type" : check(.label) ? "label an element" : "give a group members"
            throw VParserError.unexpectedToken("\(Parser.presentationOnly): it cannot \(what)")
        }

        var attrs: [(key: String, value: String)] = folded ? [(key: "isFolded", value: "true")] : []
        attrs.append(contentsOf: try parseVNotationAttrs())
        _ = match(.semicolon)
        return VViewStatementDecl(target: target, isType: isType, names: names, attrs: attrs)
    }

    // MARK: - metagraph declaration

    private func metagraphDecl() throws(VParserError) -> ASTNode {
        try consume(.metagraph, "Expected 'metagraph'")
        let notationName = try identifier(.notation)
        let label = try optionalLabel()
        _ = match(.semicolon)  // Optional trailing semicolon
        return .metagraph(notationName: notationName, label: label)
    }

    // MARK: - metadescription declaration

    /// Syntactically identical to `metagraph`; the semantic difference (emit a
    /// Markdown self-description alongside the structural metagraph) is handled
    /// in `VGraphParser.convert(...)`.
    private func metadescriptionDecl() throws(VParserError) -> ASTNode {
        try consume(.metadescription, "Expected 'metadescription'")
        let notationName = try identifier(.notation)
        let label = try optionalLabel()
        _ = match(.semicolon)  // Optional trailing semicolon
        return .metadescription(notationName: notationName, label: label)
    }

    // MARK: - vnotation declaration

    private func vnotationDecl() throws(VParserError) -> ASTNode {
        try consume(.vnotation, "Expected 'vnotation'")
        let name = try identifier(.notation)

        // Optional: extends <BuiltinNotation>
        var extendsNotation: String? = nil
        if check(.identifier) && peek().lexeme == "extends" {
            _ = advance()  // consume "extends"
            markPrevious(.keyword)
            extendsNotation = try identifier(.notation)
        }

        try consume(.leftBrace, "Expected '{' after vnotation declaration")

        var graphAttrs: [(key: String, value: String)] = []
        var nodeTypes: [VNotationNodeTypeDecl] = []
        var edgeTypes: [VNotationEdgeTypeDecl] = []
        var groupTypes: [VNotationGroupTypeDecl] = []
        var icons: [VNotationIconDecl] = []
        var qualityChecks: [String] = []
        var transforms: [String] = []

        while !check(.rightBrace) && !isAtEnd() {
            if match(.node) {
                // node type: <TypeName> [attrs]
                let typeWord = try identifier(.keyword)
                guard typeWord == "type" else {
                    throw VParserError.unexpectedToken("Expected 'type' after 'node' in vnotation body")
                }
                try consume(.colon, "Expected ':' after 'node type'")
                let typeName = try identifier(.nodeType)
                let block = try parseVNotationAttrs(detailedByAllowed: true)
                _ = match(.semicolon)
                nodeTypes.append(VNotationNodeTypeDecl(name: typeName, attrs: block.attrs, detailedBy: block.detailedBy))
            } else if match(.edge) {
                // edge type: <edge_id> from: <TypeName> to: <TypeName> [attrs]
                let typeWord = try identifier(.keyword)
                guard typeWord == "type" else {
                    throw VParserError.unexpectedToken("Expected 'type' after 'edge' in vnotation body")
                }
                try consume(.colon, "Expected ':' after 'edge type'")
                let edgeId = try identifier(.edgeType)

                // from: <TypeName>
                let fromWord = try identifier(.keyword)
                guard fromWord == "from" else {
                    throw VParserError.unexpectedToken("Expected 'from:' in edge type declaration")
                }
                try consume(.colon, "Expected ':' after 'from'")
                let fromType = try identifier(.nodeType)

                // to: <TypeName>
                let toWord = try identifier(.keyword)
                guard toWord == "to" else {
                    throw VParserError.unexpectedToken("Expected 'to:' in edge type declaration")
                }
                try consume(.colon, "Expected ':' after 'to'")
                let toType = try identifier(.nodeType)

                let rawAttrs = try parseVNotationAttrs()
                _ = match(.semicolon)
                edgeTypes.append(VNotationEdgeTypeDecl(id: edgeId, from: fromType, to: toType, attrs: rawAttrs))
            } else if match(.group) {
                let typeWord = try identifier(.keyword)
                guard typeWord == "type" else {
                    throw VParserError.unexpectedToken("Expected 'type' after 'group' in vnotation body")
                }
                try consume(.colon, "Expected ':' after 'group type'")
                let typeName = try identifier(.groupType)
                let rawAttrs = try parseVNotationAttrs()
                _ = match(.semicolon)
                groupTypes.append(VNotationGroupTypeDecl(name: typeName, attrs: rawAttrs))
            } else if check(.identifier) {
                let key = try identifier(.attrKey)
                if key == "icon" && check(.identifier) {
                    // `icon flame [...]` declares artwork; `icon: "flame"` names one.
                    markPrevious(.keyword)
                    icons.append(try parseVNotationIcon())
                } else if key == "qualityCheck" {
                    // qualityCheck: name or qualityCheck: name(param, param, ...)
                    try consume(.colon, "Expected ':' after 'qualityCheck'")
                    let spec = try parseQualityCheckSpec()
                    _ = match(.semicolon)
                    qualityChecks.append(spec)
                } else if key == "transform" {
                    // transform: name
                    try consume(.colon, "Expected ':' after 'transform'")
                    let transformName = try identifier()
                    _ = match(.semicolon)
                    transforms.append(transformName)
                } else {
                    // Generic graph-level attribute: key: value
                    try consume(.colon, "Expected ':' after '\(key)'")
                    let val = try value()
                    _ = match(.semicolon)
                    graphAttrs.append((key: key, value: val))
                }
            } else {
                // Skip unknown tokens to be lenient
                _ = advance()
            }
        }

        try consume(.rightBrace, "Expected '}' after vnotation body")

        return .vnotationDecl(
            name: name,
            extendsNotation: extendsNotation,
            graphAttrs: graphAttrs,
            nodeTypes: nodeTypes,
            edgeTypes: edgeTypes,
            groupTypes: groupTypes,
            icons: icons,
            qualityChecks: qualityChecks,
            transforms: transforms
        )
    }

    /// `icon <name> [viewBox: "<four numbers>", path: "<path data>"]`.
    private func parseVNotationIcon() throws(VParserError) -> VNotationIconDecl {
        let name = try identifier(.attrValue)
        let attrs = try parseVNotationAttrs()

        var viewBox: String?
        var path: String?
        for attr in attrs {
            switch attr.key.lowercased() {
            case "viewbox": viewBox = attr.value
            case "path": path = attr.value
            default:
                throw VParserError.unexpectedToken(
                    "Unknown attribute '\(attr.key)' on icon '\(name)'. An icon takes viewBox: and path:")
            }
        }

        guard let viewBox else {
            throw VParserError.unexpectedToken("Icon '\(name)' needs a viewBox: of four numbers")
        }
        guard let path else {
            throw VParserError.unexpectedToken("Icon '\(name)' needs a path:")
        }
        guard let artwork = IconArtwork.make(viewBox: viewBox, path: path) else {
            throw VParserError.unexpectedToken(
                "Icon '\(name)' is not drawable: viewBox: must be four numbers with a positive width and height, "
                    + "and path: must be SVG path data of at most \(IconArtwork.maxPathLength) characters")
        }

        return VNotationIconDecl(name: name, artwork: artwork)
    }

    /// Returns the spec as a string like `"treeStructure"` or `"nodeCountRange(Battle, 1, 20)"`.
    private func parseQualityCheckSpec() throws(VParserError) -> String {
        let name = try identifier()
        guard check(.leftParen) else { return name }
        _ = advance()  // consume '('
        var params: [String] = []
        while !check(.rightParen) && !isAtEnd() {
            if check(.identifier) || check(.number) {
                params.append(advance().lexeme)
            } else if check(.label) {
                let val = try value()
                params.append(val)
            }
            if check(.comma) { _ = advance() }
        }
        try consume(.rightParen, "Expected ')' after quality check parameters")
        return "\(name)(\(params.joined(separator: ", ")))"
    }

    /// Parse optional `[key: value; key: value]` attribute block into raw pairs.
    private func parseVNotationAttrs() throws(VParserError) -> [(key: String, value: String)] {
        try parseVNotationAttrs(detailedByAllowed: false).attrs
    }

    /// On a node type, `detailedBy: (A, B)` lists the types its nodes are detailed by.
    private func parseVNotationAttrs(detailedByAllowed: Bool) throws(VParserError)
        -> (attrs: [(key: String, value: String)], detailedBy: [String])
    {
        guard check(.leftBracket) else { return ([], []) }
        _ = advance()  // consume '['
        var attrs: [(key: String, value: String)] = []
        var detailedBy: [String] = []
        while !check(.rightBracket) && !isAtEnd() {
            let key = try identifier(.attrKey)
            try consume(.colon, "Expected ':' after attribute key '\(key)'")
            if key == "detailedBy" {
                guard detailedByAllowed else {
                    throw VParserError.unexpectedToken("'detailedBy:' belongs on a node type")
                }
                detailedBy += try nodeTypeList()
                if check(.semicolon) || check(.comma) { _ = advance() }
                continue
            }
            let val = try value()
            if key == "icon" {
                iconNameSpans[previous().start] = val
            }
            attrs.append((key: key, value: val))
            if check(.semicolon) || check(.comma) { _ = advance() }
        }
        try consume(.rightBracket, "Expected ']' after attributes")
        return (attrs, detailedBy)
    }

    /// `(A, B)`, each name marked as a node type.
    private func nodeTypeList() throws(VParserError) -> [String] {
        try consume(.leftParen, "Expected '(' before the list of node types")
        var names: [String] = []
        while !check(.rightParen) && !isAtEnd() {
            names.append(try identifier(.nodeType))
            if !match(.comma) { break }
        }
        try consume(.rightParen, "Expected ')' after the list of node types")
        return names
    }

    private func document() throws(VParserError) -> ASTNode {
        let leading = takeLeadingComments(before: peek().line)
        try consume(.vgraph, "Expected 'vgraph' at the beginning of document")
        let id = try identifier(.nodeId)
        try consume(.colon, "Expected ':' after vgraph id")
        let type = try identifier(.notation)

        // Parse optional comma-separated extensions: (, IDENTIFIER)*
        var extensions: [String] = []
        while match(.comma) {
            extensions.append(try identifier(.notation))
        }

        let label = try optionalLabel()

        try consume(.leftBrace, "Expected '{' after vgraph declaration")
        let trailing = takeTrailingComment(on: previous().line)

        var statements: [ASTNode] = []
        while !check(.rightBrace) && !isAtEnd() {
            try statements.append(statement())
        }

        discardComments(throughLine: peek().line)
        try consume(.rightBrace, "Expected '}' after vgraph body")

        return .document(
            id: id, type: type, extensions: extensions, label: label, children: statements,
            comments: Comments(leading: leading, trailing: trailing))
    }

    private func statement() throws(VParserError) -> ASTNode {
        if check(.vview) {
            throw VParserError.unexpectedToken("'vview' must come after the vgraph block, not inside it")
        }
        // A bare attribute is not an element and cannot hold a comment; leaving
        // the run unclaimed lets the next real declaration take it.
        let leading = declaresAnElement(peek().type) ? takeLeadingComments(before: peek().line) : nil

        // Handle "folded group" as a two-keyword sequence
        if match(.folded) {
            try consume(.group, "Expected 'group' after 'folded'")
            let statement = try group(isFolded: true, leading: leading)
            _ = match(.semicolon)  // Optional semicolon
            return statement
        }
        if match(.group) {
            let statement = try group(isFolded: false, leading: leading)
            _ = match(.semicolon)  // Optional semicolon
            return statement
        }
        if match(.node) {
            let statement = try node(leading: leading)
            _ = match(.semicolon)  // Optional semicolon
            return withTrailingComment(statement)
        }
        if match(.edge) {
            let statement = try edge(leading: leading)
            _ = match(.semicolon)  // Optional semicolon
            return withTrailingComment(statement)
        }

        let statement = try attribute()
        _ = match(.semicolon)  // Optional semicolon
        return statement
    }

    private func declaresAnElement(_ type: TokenType) -> Bool {
        type == .folded || type == .group || type == .node || type == .edge
    }

    /// Groups are excluded: theirs is claimed at their header line, since their
    /// last token is a closing brace lines away.
    private func withTrailingComment(_ statement: ASTNode) -> ASTNode {
        guard let trailing = takeTrailingComment(on: previous().line) else { return statement }
        switch statement {
        case .node(let id, let type, let label, let attributes, let comments):
            return .node(
                id: id, type: type, label: label, attributes: attributes,
                comments: Comments(leading: comments.leading, trailing: trailing))
        case .edge(let fromId, let toId, let type, let label, let attributes, let comments):
            return .edge(
                fromId: fromId, toId: toId, type: type, label: label, attributes: attributes,
                comments: Comments(leading: comments.leading, trailing: trailing))
        default:
            return statement
        }
    }

    private func group(isFolded: Bool, leading: String? = nil) throws(VParserError) -> ASTNode {
        let id = try identifier()

        // Optional `: <GroupType>` types the group (e.g. a C4 Organisation),
        // mirroring node typing; a node type there makes it a detailed node.
        var type: String? = nil
        if match(.colon) {
            type = try identifier(.groupType)
            groupTypeSlots.insert(previous().start)
        }

        let label = try optionalLabel()

        try consume(.leftBrace, "Expected '{' after group declaration")
        let trailing = takeTrailingComment(on: previous().line)

        var statements: [ASTNode] = []
        while !check(.rightBrace) && !isAtEnd() {
            try statements.append(statement())
        }

        discardComments(throughLine: peek().line)
        try consume(.rightBrace, "Expected '}' after group body")

        return .group(
            id: id, type: type, label: label, isFolded: isFolded, children: statements,
            comments: Comments(leading: leading, trailing: trailing))
    }

    private func node(leading: String? = nil) throws(VParserError) -> ASTNode {
        let id = try identifier(.nodeId)
        let idToken = previous()
        nodeSpans[id] = (idToken.start, idToken.end - idToken.start)

        if nodeIds.contains(id) {
            throw VParserError.duplicateNodeId(id)
        }
        nodeIds.insert(id)

        try consume(.colon, "Expected ':' after node id")
        let type = try identifier(.nodeType)
        let label = try optionalLabel()

        let attributes = try parseOptionalAttributes()

        return .node(
            id: id, type: type, label: label, attributes: attributes,
            comments: Comments(leading: leading, trailing: nil))
    }

    private func edge(leading: String? = nil) throws(VParserError) -> ASTNode {
        let sourceId = try identifier(.nodeId)
        let startOffset = previous().start

        if !nodeIds.contains(sourceId) {
            throw VParserError.undefinedNode(sourceId)
        }

        try consume(.arrow, "Expected '->' in edge declaration")
        let targetId = try identifier(.nodeId)
        var endOffset = previous().end

        if !nodeIds.contains(targetId) {
            throw VParserError.undefinedNode(targetId)
        }

        var type: String? = nil
        if check(.colon) {
            _ = advance()  // consume the colon
            type = try identifier(.edgeType)
            endOffset = previous().end
        }

        edgeSpans[Parser.edgeSpanKey(from: sourceId, to: targetId)] =
            (startOffset, endOffset - startOffset)

        let label = try optionalLabel()

        let attributes = try parseOptionalAttributes()

        return .edge(
            fromId: sourceId, toId: targetId, type: type, label: label, attributes: attributes,
            comments: Comments(leading: leading, trailing: nil))
    }

    private func parseOptionalAttributes() throws(VParserError) -> [ASTNode] {
        guard check(.leftBracket) else {
            // No attributes - shorthand syntax
            return []
        }
        // Inline bracket syntax: [attr1: val1; attr2: val2]
        return try inlineAttributes()
    }

    private func inlineAttributes() throws(VParserError) -> [ASTNode] {
        try consume(.leftBracket, "Expected '['")

        var attributes: [ASTNode] = []
        while !check(.rightBracket) && !isAtEnd() {
            attributes.append(try attribute())
            // Both separators are in the grammar, and the exporter writes `, `.
            if check(.semicolon) || check(.comma) {
                _ = advance()
            }
        }

        try consume(.rightBracket, "Expected ']' after attributes")
        return attributes
    }

    private func attribute() throws(VParserError) -> ASTNode {
        let id = try identifier(.attrKey)
        try consume(.colon, "Expected ':' after attribute id")
        let value = try value()

        return .attribute(id: id, value: value)
    }

    /// The lexeme of a `.label` token still carries its quotes and its escape
    /// pairs — the lexer scans them but leaves them in place. Undoing both here
    /// is what makes `StringEscaping.escape` on the way out a round trip.
    private func text(of token: Token) -> String {
        let quoted = token.lexeme
        guard quoted.count >= 2, quoted.first == "\"", quoted.last == "\"" else {
            return quoted
        }
        let startIndex = quoted.index(after: quoted.startIndex)
        let endIndex = quoted.index(before: quoted.endIndex)
        return StringEscaping.unescape(String(quoted[startIndex..<endIndex]))
    }

    private func optionalLabel() throws(VParserError) -> String? {
        if check(.label) {
            return text(of: advance())
        }
        return nil
    }

    private func value() throws(VParserError) -> String {
        if check(.label) {
            return text(of: advance())
        }

        if check(.identifier) {
            let token = advance()
            semanticIdentifiers[token.start] = .attrValue
            return token.lexeme
        }

        if check(.number) {
            return advance().lexeme
        }

        throw VParserError.expectedValue
    }

    private func identifier(_ role: VGLTokenRole = .plain) throws(VParserError) -> String {
        if check(.identifier) {
            let token = advance()
            if role != .plain {
                semanticIdentifiers[token.start] = role
            }
            return token.lexeme
        }

        throw VParserError.expectedIdentifier
    }

    /// After `parse()` throws, the current token is the offending one — the
    /// throwing helpers (`identifier`/`consume`/`value`) don't advance past it.
    /// `nil` on `.eof`.
    var currentErrorRange: (start: Int, length: Int)? {
        let idx = min(current, tokens.count - 1)
        guard idx >= 0 else { return nil }
        let token = tokens[idx]
        guard token.type != .eof, token.end > token.start else { return nil }
        return (token.start, token.end - token.start)
    }

    /// Tag the just-consumed token (a soft keyword like `extends`/`from`/`to`).
    private func markPrevious(_ role: VGLTokenRole) {
        let token = previous()
        if token.type == .identifier {
            semanticIdentifiers[token.start] = role
        }
    }

    @discardableResult
    private func consume(_ type: TokenType, _ message: String) throws(VParserError) -> Token {
        if check(type) {
            return advance()
        }

        throw VParserError.unexpectedToken(message)
    }

    private func match(_ type: TokenType) -> Bool {
        if check(type) {
            _ = advance()
            return true
        }
        return false
    }

    private func check(_ type: TokenType) -> Bool {
        if isAtEnd() { return false }
        return peek().type == type
    }

    private func checkNext(_ type: TokenType) -> Bool {
        if current + 1 >= tokens.count { return false }
        return tokens[current + 1].type == type
    }

    private func advance() -> Token {
        if !isAtEnd() { current += 1 }
        return previous()
    }

    private func isAtEnd() -> Bool {
        return peek().type == .eof
    }

    private func peek() -> Token {
        return tokens[current]
    }

    private func previous() -> Token {
        return tokens[current - 1]
    }
}
