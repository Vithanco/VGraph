//
//  VURL.swift
//  VGraph
//
//  What may be stored as a link — and therefore what an adapter may hand to the
//  host browser.
//

/// The gate between user-typed text and `window.open`.
///
/// Domain code, deliberately: the check has to hold for *every* adapter, and one
/// that forgets it turns a stored `javascript:` link into script running as the
/// page. Hand-rolled rather than `URL`-based, to compile under Embedded Swift,
/// which has no Foundation.
public enum VURL {

    private static let allowedSchemes = ["http", "https", "mailto"]

    /// `raw` as something safe to open, or nil when it is not a link at all.
    public static func safe(_ raw: String) -> String? {
        let trimmed = trim(raw)
        guard !trimmed.isEmpty, !containsWhitespace(trimmed), !trimmed.hasPrefix("/") else {
            return nil
        }

        guard let scheme = scheme(of: trimmed) else {
            // Completing is always safe — whatever follows, the result names
            // `https` — but only do it for something that could be a host, or free
            // text like "read this later" becomes a link.
            guard trimmed.contains("."), !trimmed.hasPrefix(".") else { return nil }
            return "https://\(trimmed)"
        }

        var allowed = false
        for candidate in allowedSchemes where candidate == scheme { allowed = true }
        guard allowed else { return nil }

        let rest = String(trimmed.dropFirst(scheme.count + 1))
        let target = rest.hasPrefix("//") ? String(rest.dropFirst(2)) : rest
        guard !target.isEmpty else { return nil }
        return trimmed
    }

    /// True when `raw` holds nothing but whitespace — "no link", as opposed to
    /// text that fails to be one.
    public static func isBlank(_ raw: String) -> Bool {
        return trim(raw).isEmpty
    }

    /// The lowercased scheme of `text`, or nil when it carries none: a colon
    /// before the first path separator introduces one, and a dot rules one out.
    private static func scheme(of text: String) -> String? {
        var scheme = ""
        for char in text {
            if char == ":" { return scheme.isEmpty ? nil : scheme.lowercased() }
            if char == "/" || char == "?" || char == "#" || char == "." { return nil }
            scheme.append(char)
        }
        return nil
    }

    private static func trim(_ text: String) -> String {
        var result = Substring(text)
        while let first = result.first, isWhitespace(first) { result = result.dropFirst() }
        while let last = result.last, isWhitespace(last) { result = result.dropLast() }
        return String(result)
    }

    private static func containsWhitespace(_ text: String) -> Bool {
        for char in text where isWhitespace(char) { return true }
        return false
    }

    private static func isWhitespace(_ char: Character) -> Bool {
        return char == " " || char == "\t" || char == "\n" || char == "\r"
    }
}
