import TestSupport
import Testing

@testable import App
@testable import VGraph

/// An unfolded detailed node is a cluster: it keeps its title, and its node
/// values stay off the cluster.
struct DetailedNodeClusterTests {

    private static let source = """
        vgraph arch: C4 "Architecture" {
            group ibs: SoftwareSystem "Internet Banking System" {
                isfolded: false
                tooltip: "Lets customers bank online"
                fontsize: 18
                node web: Container "Web App";
            }
        }
        """

    /// The cluster's own lines, up to its first member.
    private func cluster() throws -> String {
        let dot = try VGraphTestApp().vithancoGraphToDot(Self.source)
        let start = try #require(dot.range(of: "subgraph cluster_ibs {"))
        let end = try #require(dot[start.upperBound...].range(of: "web"))
        return String(dot[start.lowerBound..<end.lowerBound])
    }

    @Test func theClusterIsTitledWithTheNodeLabel() throws {
        #expect(try cluster().contains("label=\"Internet Banking System\""))
    }

    @Test func theClusterTakesNoNodeValues() throws {
        let cluster = try cluster()

        #expect(!cluster.contains("tooltip"))
        #expect(!cluster.contains("fontsize"))
    }
}
