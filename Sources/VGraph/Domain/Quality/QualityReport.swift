public struct QualityReport {
    public let messages: [MessageWithSeverity]

    public init(messages: [MessageWithSeverity]) {
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
        let sections = [
            section("Quality metrics:", infos), section("Warnings:", warnings), section("Errors:", errors),
        ].compactMap { $0 }
        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }

    private func section(_ heading: String, _ messages: [MessageWithSeverity]) -> String? {
        guard !messages.isEmpty else { return nil }
        return ([heading] + messages.map { "- \($0.message)" }).joined(separator: "\n")
    }
}
