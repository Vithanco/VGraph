enum TokenType {
    case vgraph, vview, vnotation, metagraph, metadescription, group, folded, node, edge
    case identifier, type, label, value
    case number
    case colon, comma, semicolon, leftBrace, rightBrace, leftBracket, rightBracket, leftParen, rightParen, arrow
    case eof, unknown
}
