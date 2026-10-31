// Tests for Math functions across platforms (Darwin, Glibc, WASM)

import Testing

@testable import MathUtils

@Suite
struct MathFunctionsTests {

    @Test
    func testCos() {
        #expect(Math.cos(0).isEqual(to: 1.0, precision: 0.0001))
        #expect(Math.cos(Double.pi).isEqual(to: -1.0, precision: 0.0001))
        #expect(Math.cos(Double.pi / 2).isEqual(to: 0.0, precision: 0.0001))
    }

    @Test
    func testSin() {
        #expect(Math.sin(0).isEqual(to: 0.0, precision: 0.0001))
        #expect(Math.sin(Double.pi / 2).isEqual(to: 1.0, precision: 0.0001))
        #expect(Math.sin(-Double.pi / 2).isEqual(to: -1.0, precision: 0.0001))
    }

    @Test
    func testAtan2() {
        #expect(Math.atan2(0, 1).isEqual(to: 0.0, precision: 0.0001))
        #expect(Math.atan2(1, 0).isEqual(to: Double.pi / 2, precision: 0.0001))
        #expect(Math.atan2(1, 1).isEqual(to: Double.pi / 4, precision: 0.0001))
    }

    @Test
    func testCeil() {
        #expect(Math.ceil(3.2) == 4)
        #expect(Math.ceil(-4.7) == -4)
        #expect(Math.ceil(5.0) == 5)
    }

    @Test
    func testFloor() {
        #expect(Math.floor(3.7) == 3)
        #expect(Math.floor(-3.7) == -4)
        #expect(Math.floor(3.0) == 3)
    }

    @Test
    func testPow() {
        #expect(Math.pow(base: 2.0, exponent: 3.0).isEqual(to: 8.0, precision: 0.0001))
        #expect(Math.pow(base: 2.0, exponent: -3.0).isEqual(to: 0.125, precision: 0.0001))
        #expect(Math.pow(base: -2.0, exponent: 3.0).isEqual(to: -8.0, precision: 0.0001))
        #expect(Math.pow(base: 2.0, exponent: 0.5).isEqual(to: 1.414213562, precision: 0.0001))
    }

    @Test
    func testDoubleExtensionCeiled() {
        let value = 3.2
        #expect(value.ceiled == 4.0)
    }

    @Test
    func testDoubleExtensionFloored() {
        let value = 3.7
        #expect(value.floored == 3.0)
    }

    @Test
    func testDoubleExtensionIsEqual() {
        #expect(3.14159.isEqual(to: 3.14160, precision: 0.0001))
        #expect(!3.14159.isEqual(to: 3.15, precision: 0.0001))
    }
}
