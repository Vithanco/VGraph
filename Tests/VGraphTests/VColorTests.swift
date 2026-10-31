import Testing

@testable import VGraph

@Suite("VColor Tests")
struct VColorTests {

    @Test
    func hexStrings() throws(VError) {
        #expect(VColor(hexString: "#33333333").asString == "#33333333")
        let hex = VColor(hexString: "#333333").asString
        #expect(hex == "#333333ff")

        #expect(VColor(hexString: "#33333300").asString == "#33333300")

        #expect(VColor(hexString: "#3ZZ0003") == nil)

    }

    @Test
    func namedColorResolvesToItsValue() throws(VError) {
        #expect(try VColor.fromString("deeppink") == VColor(hexString: "#ff1493"))
    }

}
