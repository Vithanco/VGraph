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

    /// `raw` as something safe to open, or nil when it is not a link at all.
    public static func safe(_ raw: String) -> String? {
        let trimmed = trim(raw)
        guard !trimmed.isEmpty, !trimmed.contains(where: { isWhitespace($0) }), !trimmed.hasPrefix("/") else {
            return nil
        }
        guard let scheme = scheme(of: trimmed) else { return completedWithHTTPS(trimmed) }
        return allowedSchemes.contains(scheme) && hasAddress(trimmed, after: scheme) ? trimmed : nil

        /// Completing is always safe — whatever follows, the result names
        /// `https` — but only do it for something that could be a host, or free
        /// text like "read this later" becomes a link.
        func completedWithHTTPS(_ host: String) -> String? {
            host.contains(".") && !host.hasPrefix(".") ? "https://\(host)" : nil
        }

        /// `mailto:` takes its address straight after the colon, `http://`
        /// after the slashes.
        func hasAddress(_ link: String, after scheme: String) -> Bool {
            let rest = link.dropFirst(scheme.count + 1)
            return !(rest.hasPrefix("//") ? rest.dropFirst(2) : rest).isEmpty
        }
    }

    /// True when `raw` holds nothing but whitespace — "no link", as opposed to
    /// text that fails to be one.
    public static func isBlank(_ raw: String) -> Bool {
        trim(raw).isEmpty
    }

    private static let allowedSchemes = ["http", "https", "mailto"]

    /// The lowercased scheme of `text`, or nil when it carries none: a colon
    /// before the first path separator introduces one, and a dot rules one out.
    private static func scheme(of text: String) -> String? {
        guard let end = text.firstIndex(where: { ":/?#.".contains($0) }), text[end] == ":" else { return nil }
        let prefix = text[..<end]
        return prefix.isEmpty ? nil : prefix.lowercased()
    }

    private static func trim(_ text: String) -> String {
        var result = Substring(text)
        while let first = result.first, isWhitespace(first) { result = result.dropFirst() }
        while let last = result.last, isWhitespace(last) { result = result.dropLast() }
        return String(result)
    }

    private static func isWhitespace(_ character: Character) -> Bool {
        character == " " || character == "\t" || character == "\n" || character == "\r"
    }
}
