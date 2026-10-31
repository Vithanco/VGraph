// Embedded Swift has issues with automatic Codable synthesis for complex generic types
// Since Codable isn't actually used in the codebase (only commented out tests),
// we exclude it for Embedded Swift builds

public protocol VProtocol: Equatable, Sendable, Hashable {}
