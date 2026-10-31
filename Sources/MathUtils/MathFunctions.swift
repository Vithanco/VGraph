// Note: For WASM builds, we use @_extern(c) to access JavaScript Math functions
// No need to import JavaScriptKit - we're just using C-style extern declarations

#if WASM || os(WASI)
    @_extern(c, "sin")
    public func js_sin(_ x: Double) -> Double

    @_extern(c, "cos")
    public func js_cos(_ x: Double) -> Double

    @_extern(c, "atan2")
    public func js_atan2(_ y: Double, _ x: Double) -> Double

    @_extern(c, "pow")
    public func js_pow(_ base: Double, _ exp: Double) -> Double

    @_extern(c, "ceil")
    public func js_ceil(_ value: Double) -> Double

    @_extern(c, "floor")
    public func js_floor(_ value: Double) -> Double

    @_extern(c, "sqrt")
    public func js_sqrt(_ value: Double) -> Double

#elseif canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#else
    #error("Unsupported platform")
#endif

public enum Math {
    #if WASM
        public static func cos(_ x: Double) -> Double { js_cos(x) }
        public static func sin(_ radians: Double) -> Double { js_sin(radians) }
        public static func atan2(_ y: Double, _ x: Double) -> Double { js_atan2(y, x) }
        public static func ceil(_ value: Double) -> Int { Int(js_ceil(value)) }
        public static func floor(_ value: Double) -> Int { Int(js_floor(value)) }
        public static func pow(base: Double, exponent: Double) -> Double { js_pow(base, exponent) }
        public static func sqrt(_ value: Double) -> Double { js_sqrt(value) }
    #elseif canImport(Darwin)
        private static let cosImpl: @Sendable (Double) -> Double = Darwin.cos
        private static let sinImpl: @Sendable (Double) -> Double = Darwin.sin
        private static let atan2Impl: @Sendable (Double, Double) -> Double = Darwin.atan2
        private static let ceilImpl: @Sendable (Double) -> Double = Darwin.ceil
        private static let floorImpl: @Sendable (Double) -> Double = Darwin.floor
        private static let powImpl: @Sendable (Double, Double) -> Double = Darwin.pow
        private static let sqrtImpl: @Sendable (Double) -> Double = Darwin.sqrt

        public static func cos(_ x: Double) -> Double { cosImpl(x) }
        public static func sin(_ radians: Double) -> Double { sinImpl(radians) }
        public static func atan2(_ y: Double, _ x: Double) -> Double { atan2Impl(y, x) }
        public static func ceil(_ value: Double) -> Int { Int(ceilImpl(value)) }
        public static func floor(_ value: Double) -> Int { Int(floorImpl(value)) }
        public static func pow(base: Double, exponent: Double) -> Double { powImpl(base, exponent) }
        public static func sqrt(_ value: Double) -> Double { sqrtImpl(value) }
    #elseif canImport(Glibc)
        private static let cosImpl: @Sendable (Double) -> Double = Glibc.cos
        private static let sinImpl: @Sendable (Double) -> Double = Glibc.sin
        private static let atan2Impl: @Sendable (Double, Double) -> Double = Glibc.atan2
        private static let ceilImpl: @Sendable (Double) -> Double = Glibc.ceil
        private static let floorImpl: @Sendable (Double) -> Double = Glibc.floor
        private static let powImpl: @Sendable (Double, Double) -> Double = Glibc.pow
        private static let sqrtImpl: @Sendable (Double) -> Double = Glibc.sqrt

        public static func cos(_ x: Double) -> Double { cosImpl(x) }
        public static func sin(_ radians: Double) -> Double { sinImpl(radians) }
        public static func atan2(_ y: Double, _ x: Double) -> Double { atan2Impl(y, x) }
        public static func ceil(_ value: Double) -> Int { Int(ceilImpl(value)) }
        public static func floor(_ value: Double) -> Int { Int(floorImpl(value)) }
        public static func pow(base: Double, exponent: Double) -> Double { powImpl(base, exponent) }
        public static func sqrt(_ value: Double) -> Double { sqrtImpl(value) }
    #else
        #error("No math library available for this platform")
    #endif
}

extension Double {
    public var ceiled: Double {
        return Double(Math.ceil(self))
    }

    public var floored: Double {
        return Double(Math.floor(self))
    }

    public func isEqual(to: Double, precision: Double) -> Bool {
        return abs(self - to) <= precision
    }
}
