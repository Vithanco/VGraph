extension Double {
    public var squared: Double {
        return self * self
    }
    public func asString(decimals: Int = 2) -> String {
        var decimalFactor = 1.0
        for _ in 0..<decimals {
            decimalFactor *= 10.0
        }
        let multiplied = self * decimalFactor
        let rounded = Double(Int(multiplied + (multiplied < 0 ? -0.5 : 0.5)))
        return "\(rounded / decimalFactor)"
    }

    /// Stdlib-only, for Embedded Swift: `[-]digits[.digits][e[±]digits]`, the
    /// exponent because that is how Swift writes very small and very large numbers
    /// back. Without a digit there is no number, so `""`, `"-"` and `"."` are nil
    /// rather than 0.
    public init?(_ text: String) {
        var rest = Substring(text)
        let isNegative = rest.first == "-"
        if isNegative { rest = rest.dropFirst() }
        let whole = rest.prefix { $0.isASCIIDigit }
        rest = rest.dropFirst(whole.count)
        var fraction: Substring = ""
        if rest.first == "." {
            fraction = rest.dropFirst().prefix { $0.isASCIIDigit }
            rest = rest.dropFirst(fraction.count + 1)
        }
        guard !whole.isEmpty || !fraction.isEmpty, let exponent = Self.exponent(rest) else { return nil }
        let digits = (whole + fraction).reduce(0.0) { value, digit in value * 10 + Double(digit.wholeNumberValue ?? 0) }
        let magnitude = Self.scaled(digits, byPowerOfTen: exponent - fraction.count)
        self = isNegative ? -magnitude : magnitude
    }

    /// The exponent `rest` spells, 0 when it is empty, nil when it is anything
    /// else. Three digits reach past every `Double`.
    private static func exponent(_ rest: Substring) -> Int? {
        guard let marker = rest.first else { return 0 }
        guard marker == "e" || marker == "E" else { return nil }
        let signed = rest.dropFirst()
        let isNegative = signed.first == "-"
        let digits = signed.first == "-" || signed.first == "+" ? signed.dropFirst() : signed
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCIIDigit }), digits.count <= 3, let value = Int(String(digits))
        else { return nil }
        return isNegative ? -value : value
    }

    /// Divides by an exact power rather than multiplying by an inexact one, so
    /// `1e-05` reads back as the `Double` it was written from.
    private static func scaled(_ value: Double, byPowerOfTen exponent: Int) -> Double {
        let power = (0..<Swift.abs(exponent)).reduce(1.0) { result, _ in result * 10 }
        return exponent < 0 ? value / power : value * power
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
