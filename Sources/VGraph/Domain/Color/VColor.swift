import MathUtils

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
    public static let lightGray = VColor(white: 0.75, alpha: 1)
    public static let gray = VColor(white: 0.5, alpha: 1)

    public static let red = VColor(red: 1, green: 0, blue: 0, alpha: 1)
    public static let green = VColor(red: 0, green: 1, blue: 0, alpha: 1)
    public static let blue = VColor(red: 0, green: 0, blue: 1, alpha: 1)
    public static let yellow = VColor(red: 254, green: 224, blue: 96, alpha: 1)
    public static let cyan = VColor(red: 0, green: 1, blue: 1, alpha: 1)

    public static let clrHooverAqua = VColor(redInt: 135, green: 135, blue: 230)
    public static let clrHooverDarkAqua = VColor(white: 0.3, alpha: 1)
    public static let clrConnectedToHooverAqua = VColor(redInt: 135, green: 135, blue: 195).brighten()
    public static let clrConnectedToHooverDarkAqua = VColor(white: 0.5, alpha: 1)
    public static let clrSelectionAqua = VColor(redInt: 200, green: 100, blue: 100).brighten()
    public static let clrSelectionDarkAqua = VColor(redInt: 50, green: 50, blue: 170)
    public static let clrNonConform = VColor.red.brighten()

    public static let clear = VColor(white: 0, alpha: 0)

    public static let labelColor = gray

    public func setFill() {}

    public func setStroke() {}
}

/// based on: https://gist.github.com/pvroosendaal/5aca45dff84590ab4d92d7b151b21839
extension VColor {

    public init?(hexString: String) {
        let hexString = hexString.trimmingCharacters(in: " \t\n\r")
        guard !hexString.isEmpty else {
            return nil
        }

        var hex = hexString
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        guard let color = VColor.parseHex(hex) else {
            return nil
        }

        let mask: UInt64 = 0x0000_00FF
        let r: Int
        let g: Int
        let b: Int
        let a: Int

        if hex.count == 6 {  // "RRGGBB"
            r = Int((color >> 16) & mask)
            g = Int((color >> 8) & mask)
            b = Int(color & mask)
            a = 255  // full opacity
        } else if hex.count == 8 {  // "RRGGBBAA"
            r = Int((color >> 24) & mask)
            g = Int((color >> 16) & mask)
            b = Int((color >> 8) & mask)
            a = Int(color & mask)
        } else {
            return nil
        }

        self.init(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            alpha: Double(a) / 255.0)
    }

    private static func parseHex(_ hexString: String) -> UInt64? {
        var result: UInt64 = 0
        for char in hexString {
            guard let value = char.hexValue else {
                return nil
            }
            result = result * 16 + UInt64(value)
        }
        return result
    }

    public var hexString: String {
        hexString(withAlpha: false)
    }

    public var hexStringWithAlpha: String {
        hexString(withAlpha: true)
    }

    private func hexString(withAlpha: Bool) -> String {
        let hexDigits = "0123456789abcdef"
        var components = [
            Int(redComponent * 255),
            Int(greenComponent * 255),
            Int(blueComponent * 255),
        ]

        if withAlpha {
            components.append(Int(alphaComponent * 255))
        }

        let bitShifts = withAlpha ? [24, 16, 8, 0] : [16, 8, 0]
        let colorValue = zip(components, bitShifts)
            .reduce(UInt64(0)) { $0 | (UInt64($1.0) << $1.1) }

        var hexString = "#"
        let digitCount = withAlpha ? 8 : 6

        for i in (0..<digitCount).reversed() {
            let digit = Int((colorValue >> (i * 4)) & 0xF)
            hexString.append(hexDigits[hexDigits.index(hexDigits.startIndex, offsetBy: digit)])
        }

        return hexString
    }
}

extension Character {
    var hexValue: Int? {
        switch self {
        case "0"..."9":
            return Int(self.unicodeScalars.first!.value - Unicode.Scalar("0").value)
        case "a"..."f":
            return Int(self.unicodeScalars.first!.value - Unicode.Scalar("a").value + 10)
        case "A"..."F":
            return Int(self.unicodeScalars.first!.value - Unicode.Scalar("A").value + 10)
        default:
            return nil
        }
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

public func rgb(_ r: Int, _ g: Int, _ b: Int, alpha: Int = 255) -> VColor {
    return VColor(redInt: r, green: g, blue: b, alpha: alpha)
}

extension VColor {
    /// calculate grayScale, based on NTSC algorithm
    public func grayScale() -> Double {
        let r = 0.299 * redComponent
        let g = 0.587 * greenComponent
        let b = 0.114 * blueComponent
        return r + g + b
    }

    public var userFriendlyRGBString: String {
        let r = Int(redComponent * 255.0)
        let g = Int(greenComponent * 255.0)
        let b = Int(blueComponent * 255.0)
        let a = Int(alphaComponent * 255.0)
        return "R:\(r),G:\(g),B:\(b) A:\(a)"
    }

    public var debugDescription: String {
        return userFriendlyRGBString
    }

    public func grayScaled() -> VColor {
        return VColor(white: grayScale())
    }

    public var bwContrastColor: VColor {
        guard grayScale() < 0.5 else {
            return VColor.black
        }
        return VColor.white
    }

    public init(redInt: Int, green: Int, blue: Int, alpha: Int = 255) {
        assert(redInt <= 255, "red bigger than 255: \(redInt)")
        assert(redInt >= 0, "red negative: \(redInt)")
        assert(green <= 255, "green bigger than 255: \(green)")
        assert(green >= 0, "green negative: \(green)")
        assert(blue <= 255, "blue bigger than 255: \(blue)")
        assert(blue >= 0, "blue negative: \(blue)")
        assert(alpha <= 255, "alpha bigger than 255: \(alpha)")
        assert(alpha >= 0, "alpha negative: \(alpha)")
        self.redComponent = Double(redInt) / 255.0
        self.greenComponent = Double(green) / 255.0
        self.blueComponent = Double(blue) / 255.0
        self.alphaComponent = Double(alpha) / 255.0
    }

    public func avgWhite() -> Double {
        return (redComponent + blueComponent + greenComponent) / 3.0
    }

    public func brighten() -> VColor {
        func newValue(_ old: Double) -> Double {
            return old < 0.1 ? 0.1 : old.squareRoot()
        }

        return VColor(
            red: newValue(redComponent), green: newValue(greenComponent), blue: newValue(blueComponent),
            alpha: alphaComponent)
    }

    public func brighten(to: Double) -> VColor {
        assert(to >= 0.1, "\(to)")
        assert(to < 1, "\(to)")
        let avgW = avgWhite()
        if avgW < to {
            let brighter = brighten()
            let brighterAvgW = brighter.avgWhite()
            if brighterAvgW <= avgW {
                return self
            }
            return brighter.brighten(to: to)
        }
        return self
    }

    public func darken() -> VColor {
        func newValue(_ old: Double) -> Double {
            return old > 0.9 ? 0.9 : old.squared
        }
        return VColor(
            red: newValue(redComponent), green: newValue(greenComponent), blue: newValue(blueComponent),
            alpha: alphaComponent)
    }

    public func darken(to: Double) -> VColor {
        assert(to >= 0.05, "\(to)")
        assert(to < 0.9, "\(to)")
        let avgW = avgWhite()
        if avgW > to {
            let darker = darken()
            let darkerAvgW = darker.avgWhite()
            if darkerAvgW >= avgW {
                return self
            }
            return darker.darken(to: to)
        }
        return self
    }

    public func setAlpha(to: Double) -> VColor {
        let clampedAlpha = max(0.0, min(1.0, to))
        return VColor(red: redComponent, green: greenComponent, blue: blueComponent, alpha: clampedAlpha)
    }

    public func combine(_ other: VColor) -> VColor {
        let mixer = 2.squareRoot().squareRoot()
        let r = (redComponent + other.redComponent) / mixer
        let g = (greenComponent + other.greenComponent) / mixer
        let b = (blueComponent + other.blueComponent) / mixer
        let a = (alphaComponent + other.alphaComponent) / mixer
        return VColor(red: r, green: g, blue: b, alpha: a)
    }

    public func provideContrastColor(with other: VColor) -> VColor {
        if VColor.haveEnoughContrast(between: self, and: other) {
            return other.bwContrastColor
        }
        return self
    }

    // based on https://stackoverflow.com/questions/42355778/how-to-compute-color-contrast-ratio-between-two-uicolor-instances
    public static func contrastRatio(between color: VColor, and color2: VColor) -> Double {
        // https://www.w3.org/TR/WCAG20-TECHS/G18.html#G18-tests

        let luminance1 = color.luminance()
        let luminance2 = color2.luminance()

        let luminanceDarker = min(luminance1, luminance2)
        let luminanceLighter = max(luminance1, luminance2)

        return (luminanceLighter + 0.05) / (luminanceDarker + 0.05)
    }

    public static func haveEnoughContrast(between color: VColor, and color2: VColor) -> Bool {
        return contrastRatio(between: color, and: color2) >= 4.5
    }

    public func contrastRatio(with color: VColor) -> Double {
        return VColor.contrastRatio(between: self, and: color)
    }

    public func hasEnoughContrastTo(with color: VColor) -> Bool {
        return VColor.haveEnoughContrast(between: self, and: color)
    }

    // based on https://stackoverflow.com/questions/42355778/how-to-compute-color-contrast-ratio-between-two-uicolor-instances
    public var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        (redComponent, greenComponent, blueComponent, alphaComponent)
    }

    public func contrastRatio(against color: VColor) -> Double {
        let luminance1 = luminance()
        let luminance2 = color.luminance()

        let luminanceDarker = min(luminance1, luminance2)
        let luminanceLighter = max(luminance1, luminance2)

        return (luminanceLighter + 0.05) / (luminanceDarker + 0.05)
    }

    public func luminance() -> Double {
        func adjust(colorComponent: Double) -> Double {
            return (colorComponent < 0.04045)
                ? (colorComponent / 12.92) : Math.pow(base: (colorComponent + 0.055) / 1.055, exponent: 2.4)
        }

        return 0.2126 * adjust(colorComponent: components.red) + 0.7152 * adjust(colorComponent: components.green)
            + 0.0722 * adjust(colorComponent: components.blue)
    }

    // based on https://stackoverflow.com/questions/15032562/ios-find-color-at-point-between-two-colors
    public func toColor(_ color: VColor, percentage: Double) -> VColor {
        let percentage = max(min(percentage, 1), 0)
        func newValue(_ old: Double, _ otherOld: Double) -> Double {
            return Double(old + (otherOld - old) * percentage)
        }
        switch percentage {
        case 0: return self
        case 1: return color
        default:
            return VColor(
                red: newValue(redComponent, color.redComponent),
                green: newValue(greenComponent, color.greenComponent),
                blue: newValue(blueComponent, color.blueComponent),
                alpha: newValue(alphaComponent, color.alphaComponent))
        }
    }

    public func isSimilar(to: VColor, delta: Double = 0.025) -> Bool {
        return isDoubleEqual(redComponent, to.redComponent, delta: delta)
            && isDoubleEqual(blueComponent, to.blueComponent, delta: delta)
            && isDoubleEqual(greenComponent, to.greenComponent, delta: delta)
            && isDoubleEqual(alphaComponent, to.alphaComponent, delta: delta)
    }
}

// based on https://gist.githubusercontent.com/FredrikSjoberg/cdea97af68c6bdb0a89e3aba57a966ce/raw/6237f02fa42b538a236e575e0202f92547ba34cd/RGBtoHSV.swift
public struct HSVColor {
    let h: Double  // Angle in degrees [0,360] or -1 as Undefined
    let s: Double  // Percent [0,1]
    let v: Double  // Percent [0,1]
    let alpha: Double

    var asVColor: VColor {
        if s == 0 { return VColor(red: v, green: v, blue: v, alpha: alpha) }  // Achromatic grey

        let angle = (h >= 360 ? 0 : h)
        let sector = angle / 60  // Sector
        let i = sector.floored
        let f = sector - i  // Factorial part of h

        let p = v * (1 - s)
        let q = v * (1 - (s * f))
        let t = v * (1 - (s * (1 - f)))

        switch i {
        case 0:
            return VColor(red: v, green: t, blue: p, alpha: alpha)
        case 1:
            return VColor(red: q, green: v, blue: p, alpha: alpha)
        case 2:
            return VColor(red: p, green: v, blue: t, alpha: alpha)
        case 3:
            return VColor(red: p, green: q, blue: v, alpha: alpha)
        case 4:
            return VColor(red: t, green: p, blue: v, alpha: alpha)
        default:
            return VColor(red: v, green: p, blue: q, alpha: alpha)
        }
    }

    func getNextOliverEmbertonColor(ticks: Int = 1, saturation: Double?, brightness: Double?) -> HSVColor {
        var hue = h
        hue -= (30.0 / 360.0) * Double(ticks)
        if hue < 0 {
            hue += 1
        }
        return HSVColor(h: hue, s: saturation ?? s, v: brightness ?? v, alpha: alpha)
    }
}

extension VColor {
    // https://www.cs.rit.edu/~ncs/color/t_convert.html
    var asHSVColor: HSVColor {
        let min =
            redComponent < greenComponent
            ? (redComponent < blueComponent ? redComponent : blueComponent)
            : (greenComponent < blueComponent ? greenComponent : blueComponent)
        let max =
            redComponent > greenComponent
            ? (redComponent > blueComponent ? redComponent : blueComponent)
            : (greenComponent > blueComponent ? greenComponent : blueComponent)

        let v = max
        let delta = max - min

        guard delta > 0.00001 else { return HSVColor(h: 0, s: 0, v: max, alpha: alphaComponent) }
        guard max > 0 else { return HSVColor(h: -1, s: 0, v: v, alpha: alphaComponent) }  // Undefined, achromatic grey
        let s = delta / max

        let hue: (Double, Double) -> Double = { max, delta -> Double in
            if redComponent == max {
                return (greenComponent - blueComponent) / delta
            }  // between yellow & magenta
            else if greenComponent == max {
                return 2 + (blueComponent - redComponent) / delta
            }  // between cyan & yellow
            else {
                return 4 + (redComponent - greenComponent) / delta
            }  // between magenta & cyan
        }

        let h = hue(max, delta) * 60  // In degrees

        return HSVColor(h: h < 0 ? h + 360 : h, s: s, v: v, alpha: alphaComponent)
    }

    func getNextOliverEmbertonColor(ticks: Int = 1, saturation: Double?, brightness: Double?) -> VColor {
        let hsv = asHSVColor
        let new = hsv.getNextOliverEmbertonColor(ticks: ticks, saturation: saturation, brightness: brightness)
        return new.asVColor
    }
}

extension VColor: AttributeType {
    public static var typeName: String {
        return "Color"
    }

    public static func toString(_ value: VColor) -> String {
        return value.asString
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
