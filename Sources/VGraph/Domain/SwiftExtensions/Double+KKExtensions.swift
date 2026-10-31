func isDoubleEqual(_ left: Double, _ right: Double, delta: Double = 0.01) -> Bool {
    return abs(left - right) <= delta
}

extension Double {
    public var squared: Double {
        return self * self
    }
    public var asDouble: Double {
        return Double(self)
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

    public init?(_ string: String) {
        var result: Double = 0
        var decimalPlace: Double = 0.1
        var isNegative = false
        var hasDecimal = false

        for char in string {
            if char == "-" && result == 0 && !hasDecimal {
                isNegative = true
            } else if char == "." && !hasDecimal {
                hasDecimal = true
            } else if char >= "0" && char <= "9" {
                let digit = Double(Int(char.asciiValue! - 48))  // Convert ASCII to numeric value

                if hasDecimal {
                    result += digit * decimalPlace
                    decimalPlace *= 0.1
                } else {
                    result = result * 10 + digit
                }
            } else {
                return nil  // Invalid character
            }
        }

        self = isNegative ? -result : result
    }

}

public typealias Percent = Double
