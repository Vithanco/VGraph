/// The source a highlighter reconstructs: tags dropped, entities unescaped.
func stripTags(_ html: String) -> String {
    var out = ""
    var inTag = false
    for c in html {
        if c == "<" {
            inTag = true
        } else if c == ">" {
            inTag = false
        } else if !inTag {
            out.append(c)
        }
    }
    return out.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&amp;", with: "&")
}
