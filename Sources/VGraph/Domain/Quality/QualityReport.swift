public struct QualityReport {
    public let messages: [MessageWithSeverity]

    public let notationName: String

    public init(notationName: String, messages: [MessageWithSeverity]) {
        self.notationName = notationName
        self.messages = messages
    }

    public var errors: [MessageWithSeverity] {
        messages.filter { $0.severity == .error }
    }

    public var warnings: [MessageWithSeverity] {
        messages.filter { $0.severity == .warning }
    }

    public var infos: [MessageWithSeverity] {
        messages.filter { $0.severity == .info }
    }

    public var isClean: Bool {
        errors.isEmpty && warnings.isEmpty
    }

    /// Human-readable formatted output. Returns nil if no messages.
    public func formatted() -> String? {
        guard !messages.isEmpty else { return nil }

        var lines: [String] = []

        let infoMessages = infos
        if !infoMessages.isEmpty {
            lines.append("Quality metrics:")
            for msg in infoMessages {
                lines.append("- \(msg.message)")
            }
        }

        let warningMessages = warnings
        if !warningMessages.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("Warnings:")
            for msg in warningMessages {
                lines.append("- \(msg.message)")
            }
        }

        let errorMessages = errors
        if !errorMessages.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("Errors:")
            for msg in errorMessages {
                lines.append("- \(msg.message)")
            }
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
