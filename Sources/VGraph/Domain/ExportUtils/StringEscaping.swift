/// Both formats use the same escaping rules for quoted strings
public struct StringEscaping {

    /// The inverse of ``escape(_:)``. A backslash makes the next character
    /// literal, whatever it is, so `\"` yields `"` and `\\` yields `\`. A
    /// trailing lone backslash is kept: it cannot have come from
    /// ``escape(_:)``, and dropping it would lose a character.
    public static func unescape(_ string: String) -> String {
        var result = ""
        var escaped = false
        for char in string {
            if escaped {
                result.append(char)
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else {
                result.append(char)
            }
        }
        if escaped {
            result.append("\\")
        }
        return result
    }

    public static func escape(_ string: String) -> String {
        var result = ""
        for char in string {
            if char == "\"" {
                result += "\\\""
            } else if char == "\\" {
                result += "\\\\"
            } else {
                result.append(char)
            }
        }
        return result
    }
}
