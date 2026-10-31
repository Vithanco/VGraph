////
////  ColorMath.swift
////  VGraph
////
////  HSL conversion + `darkOf` derivation, used by `SemanticColor` to compute
////  dark variants for tokens that don't have an explicit pair.
////
////  Implements §11 of the Vithanco Diagram Style Guide: each light fill /
////  border / text triple maps to a dark equivalent through three lightness
////  bands; hue is preserved so each notation stays identifiable across modes.
////
////  Reference algorithm (JS source in the style guide):
////      if (s < 8)        return hsl(h, s,           100 - l)        // neutral
////      if (l > 70)       return hsl(h, min(s, 32),  13)             // dark fill
////      if (l < 30)       return hsl(h, min(s, 60),  86)             // light text
////                        return hsl(h, min(s+8, 78), max(l, 62))    // mid accent
////

import MathUtils

public enum ColorMath {

    // MARK: - HSL conversion

    /// Convert an RGB color (0…1 components) to HSL where h∈[0,360), s,l∈[0,100].
    public static func rgbToHSL(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let l = (maxC + minC) / 2
        if maxC == minC {
            return (0, 0, l * 100)
        }
        let d = maxC - minC
        let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)
        let hRaw: Double
        switch maxC {
        case r: hRaw = (g - b) / d + (g < b ? 6 : 0)
        case g: hRaw = (b - r) / d + 2
        default: hRaw = (r - g) / d + 4
        }
        return (hRaw * 60, s * 100, l * 100)
    }

    /// Convert HSL (h∈[0,360), s,l∈[0,100]) back to RGB (0…1 components).
    public static func hslToRGB(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        let sN = s / 100
        let lN = l / 100
        let c = (1 - abs(2 * lN - 1)) * sN
        let hh = h / 60
        let x = c * (1 - abs(hh.truncatingRemainder(dividingBy: 2) - 1))
        let (r1, g1, b1): (Double, Double, Double)
        if hh < 1 {
            (r1, g1, b1) = (c, x, 0)
        } else if hh < 2 {
            (r1, g1, b1) = (x, c, 0)
        } else if hh < 3 {
            (r1, g1, b1) = (0, c, x)
        } else if hh < 4 {
            (r1, g1, b1) = (0, x, c)
        } else if hh < 5 {
            (r1, g1, b1) = (x, 0, c)
        } else {
            (r1, g1, b1) = (c, 0, x)
        }
        let m = lN - c / 2
        return (r1 + m, g1 + m, b1 + m)
    }

    // MARK: - darkOf transform

    public static func darkOf(_ color: VColor) -> VColor {
        let (h, s, l) = rgbToHSL(r: color.redComponent, g: color.greenComponent, b: color.blueComponent)
        let newH: Double
        let newS: Double
        let newL: Double
        if s < 8 {
            newH = h
            newS = s
            newL = min(100, max(0, 100 - l))
        } else if l > 70 {
            newH = h
            newS = min(s, 32)
            newL = 13
        } else if l < 30 {
            newH = h
            newS = min(s, 60)
            newL = 86
        } else {
            newH = h
            newS = min(s + 8, 78)
            newL = max(l, 62)
        }
        let (r, g, b) = hslToRGB(h: newH, s: newS, l: newL)
        return VColor(red: r, green: g, blue: b, alpha: color.alphaComponent)
    }

    /// Returns `lightHex` unchanged if it cannot be parsed (e.g. malformed input).
    public static func darkHex(of lightHex: String) -> String {
        guard let light = VColor(hexString: lightHex) else { return lightHex }
        return darkOf(light).hexString
    }
}
