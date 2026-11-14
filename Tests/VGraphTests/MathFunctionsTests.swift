// Tests for Math functions across platforms (Darwin, Glibc, WASM)

import Testing

@testable import MathUtils

@Suite
struct MathFunctionsTests {

    @Test
    func testCos() {
        #expect(isClose(Math.cos(0), 1.0))
        #expect(isClose(Math.cos(Double.pi), -1.0))
        #expect(isClose(Math.cos(Double.pi / 2), 0.0))
    }

    @Test
    func testSin() {
        #expect(isClose(Math.sin(0), 0.0))
        #expect(isClose(Math.sin(Double.pi / 2), 1.0))
        #expect(isClose(Math.sin(-Double.pi / 2), -1.0))
    }

    @Test
    func testAtan2() {
        #expect(isClose(Math.atan2(0, 1), 0.0))
        #expect(isClose(Math.atan2(1, 0), Double.pi / 2))
        #expect(isClose(Math.atan2(1, 1), Double.pi / 4))
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
        #expect(isClose(Math.pow(base: 2.0, exponent: 3.0), 8.0))
        #expect(isClose(Math.pow(base: 2.0, exponent: -3.0), 0.125))
        #expect(isClose(Math.pow(base: -2.0, exponent: 3.0), -8.0))
        #expect(isClose(Math.pow(base: 2.0, exponent: 0.5), 1.414213562))
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
}

private func isClose(_ a: Double, _ b: Double) -> Bool {
    abs(a - b) <= 0.0001
}
