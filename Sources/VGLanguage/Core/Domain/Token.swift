struct Token {
    let type: TokenType
    let lexeme: String
    let line: Int
    /// Half-open **character** indices into `Array(source)` (not byte/UTF-16),
    /// matching the Lexer's indexing. Drives syntax-highlight span mapping.
    let start: Int
    let end: Int

    init(type: TokenType, lexeme: String, line: Int, start: Int = 0, end: Int = 0) {
        self.type = type
        self.lexeme = lexeme
        self.line = line
        self.start = start
        self.end = end
    }
}
