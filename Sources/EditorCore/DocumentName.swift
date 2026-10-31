//
//  DocumentName.swift
//  EditorCore
//
//  The name an opened file leaves behind. There is no file handle behind the
//  [[File menu]] — the browser gives none a page may write back through — so
//  the name is the whole of what an open carries forward, and both saves
//  rebuild their filename from it.
//

public let defaultDocumentName = "vgraph-diagram"

public func documentName(fromFile fileName: String) -> String {
    guard !fileName.isEmpty else { return defaultDocumentName }
    let (stem, suffix) = splitCollisionSuffix(dropExtension(fileName))
    guard stem.hasSuffix(".vithanco") else { return stem + suffix }
    return dropExtension(stem) + suffix
}

/// The browser owns its `" (1)"` — `download` proposes a name and no more — and
/// it reads `.svg` alone as the extension, so the suffix lands in the *middle*
/// of `.vithanco.svg`. Lifting it back out is the only say we get.
///
/// The space is what makes it the browser's suffix and not the user's text:
/// stripping `notes(draft)` would rename their document behind their back.
private func splitCollisionSuffix(_ stem: String) -> (stem: String, suffix: String) {
    guard stem.hasSuffix(")"), let open = stem.lastIndex(of: "("),
        open > stem.startIndex
    else { return (stem, "") }
    let space = stem.index(before: open)
    guard stem[space] == " " else { return (stem, "") }
    return (String(stem[stem.startIndex..<space]), String(stem[space...]))
}

private func dropExtension(_ fileName: String) -> String {
    // The leading-dot guard is belt-and-braces: no browser test can reach it,
    // because Chromium strips the dot off a `.vgl` file's `name` first.
    guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else {
        return fileName
    }
    return String(fileName[fileName.startIndex..<dot])
}

/// The [[Diagram as document]] rule means an SVG *may* be a document — every
/// render carries its VGL inside `<metadata>`. One we did not write is not, and
/// saying so beats loading its markup into the editor and leaving the parser to
/// complain about it.
public enum OpenedFile: Sendable, Equatable {
    case vgl(String)
    /// The payload is what to tell the user.
    case refused(String)
}

/// Decide what an opened file is. `embeddedVGL` is what the renderer recovered
/// from the text, which the caller extracts — the SVG envelope is the render
/// adapter's format, not something this target knows.
public func opened(_ text: String, named name: String, embeddedVGL: String?) -> OpenedFile {
    if let embeddedVGL { return .vgl(embeddedVGL) }
    guard !looksLikeSVG(text) else {
        return .refused("\(name) carries no VGL — only diagrams saved by VGraph do")
    }
    return .vgl(text)
}

private func looksLikeSVG(_ text: String) -> Bool {
    let start = text.drop(while: { $0 == " " || $0 == "\n" || $0 == "\r" || $0 == "\t" })
    return start.hasPrefix("<svg") || start.hasPrefix("<?xml")
}
