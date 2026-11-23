public struct VColor: Hashable, Equatable, Sendable {
    public let redComponent: Double
    public let greenComponent: Double
    public let blueComponent: Double
    public let alphaComponent: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.redComponent = red
        self.greenComponent = green
        self.blueComponent = blue
        self.alphaComponent = alpha
    }

    public init(white: Double, alpha: Double = 1.0) {
        self.redComponent = white
        self.greenComponent = white
        self.blueComponent = white
        self.alphaComponent = alpha
    }

    public static let white = VColor(white: 1)
    public static let black = VColor(white: 0)
    public static let gray = VColor(white: 0.5, alpha: 1)

    public static let red = VColor(red: 1, green: 0, blue: 0, alpha: 1)
    public static let green = VColor(red: 0, green: 1, blue: 0, alpha: 1)
    public static let blue = VColor(red: 0, green: 0, blue: 1, alpha: 1)
    public static let yellow = VColor(red: 254 / 255, green: 224 / 255, blue: 96 / 255, alpha: 1)

    public static let clear = VColor(white: 0, alpha: 0)

}

/// based on: https://gist.github.com/pvroosendaal/5aca45dff84590ab4d92d7b151b21839
extension VColor {

    /// `#RRGGBB` or `#RRGGBBAA`, the `#` optional.
    public init?(hexString: String) {
        let trimmed = hexString.trimmingCharacters(in: " \t\n\r")
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard hex.count == 6 || hex.count == 8, let value = VColor.parseHex(hex) else { return nil }
        let opaque = hex.count == 6
        let packed = opaque ? value << 8 | 0xFF : value
        func channel(_ shift: UInt64) -> Double { Double((packed >> shift) & 0xFF) / 255.0 }
        self.init(red: channel(24), green: channel(16), blue: channel(8), alpha: channel(0))
    }

    /// One character at a time, so a sign `UInt64(_:radix:)` would accept is refused.
    private static func parseHex(_ hexString: String) -> UInt64? {
        var result: UInt64 = 0
        for char in hexString {
            guard let digit = UInt64(String(char), radix: 16) else {
                return nil
            }
            result = result * 16 + digit
        }
        return result
    }

    public var hexString: String {
        Self.hex([redComponent, greenComponent, blueComponent])
    }

    public var hexStringWithAlpha: String {
        Self.hex([redComponent, greenComponent, blueComponent, alphaComponent])
    }

    private static func hex(_ components: [Double]) -> String {
        let digits = Array("0123456789abcdef")
        return "#"
            + components.map { component in
                let byte = Int(component * 255)
                return String([digits[(byte >> 4) & 0xF], digits[byte & 0xF]])
            }.joined()
    }
}

extension VColor: Identifiable {
    public var id: String {
        return hexStringWithAlpha
    }
}

extension VColor: CustomStringConvertible {
    public var description: String {
        return hexStringWithAlpha
    }
}

extension VColor {
    public var bwContrastColor: VColor {
        guard ntscLuma < 0.5 else {
            return VColor.black
        }
        return VColor.white
    }

    private var ntscLuma: Double {
        0.299 * redComponent + 0.587 * greenComponent + 0.114 * blueComponent
    }

    public func darken(to targetAverage: Double) -> VColor {
        assert(targetAverage >= 0.05, "\(targetAverage)")
        assert(targetAverage < 0.9, "\(targetAverage)")
        guard averageComponent > targetAverage else { return self }
        let darker = darkenedOneStep()
        // A step that darkens nothing would recurse forever.
        guard darker.averageComponent < averageComponent else { return self }
        return darker.darken(to: targetAverage)
    }

    private func darkenedOneStep() -> VColor {
        func darkened(_ component: Double) -> Double {
            component > 0.9 ? 0.9 : component.squared
        }
        return VColor(
            red: darkened(redComponent), green: darkened(greenComponent), blue: darkened(blueComponent),
            alpha: alphaComponent)
    }

    private var averageComponent: Double {
        (redComponent + blueComponent + greenComponent) / 3.0
    }
}

extension VColor: AttributeType {
    public static var typeName: String {
        return "Color"
    }

    public static func fromString(_ string: String) throws(VError) -> Self {
        if let result = VColor(hexString: string) {
            return result
        }
        if let named = VColor(named: string) {
            return named
        }
        throw VError.invalidHexString(string)
    }

    public var asString: String {
        return hexStringWithAlpha
    }
}
