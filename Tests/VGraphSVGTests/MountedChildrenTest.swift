//
//  MountedChildrenTest.swift
//  VGraph
//
//  The keys the mounted preview tells siblings apart by (ADR-0015 F1). A key
//  that moves with its element is what makes a redraw a patch; one that does
//  not turns an insertion into a rewrite of everything after it.
//

import Testing
import VGraph
import VGraphSVG

struct MountedChildrenTest {
    private func g(_ id: String) -> VSVGNode { .element(.g, [VSVGAttribute("id", id)]) }
    private let path = VSVGNode.element(.path, [VSVGAttribute("d", "M0 0")])
    private let rect = VSVGNode.element(.rect)

    private func keys(_ children: [VSVGNode]) -> [String] {
        mountedChildren(of: children).map { $0.key }
    }

    @Test func anElementWithAnIdIsKeyedByIt() {
        #expect(keys([g("node-a"), g("node-b")]) == ["node-a", "node-b"])
    }

    /// An edge's id changes with every parse; the key the renderer gives it does not.
    @Test func aKeyAttributeWinsOverTheId() {
        let edge = VSVGNode.element(
            .g, [VSVGAttribute("id", "edge-100017"), VSVGAttribute(SVGElementId.keyAttribute, "a>b")])

        #expect(keys([edge]) == ["a>b"])
    }

    @Test func anIdKeepsItsKeyWhenASiblingArrivesBeforeIt() {
        #expect(keys([g("node-new"), g("node-a")]).last == keys([g("node-a")]).last)
    }

    /// Per tag, so a path does not change key because a rect joined in front.
    @Test func anElementWithoutAnIdIsKeyedByItsPlaceAmongItsOwnTag() {
        #expect(keys([path, rect, path]) == ["path:0", "rect:0", "path:1"])
        #expect(keys([rect, path, rect, path]) == ["rect:0", "path:0", "rect:1", "path:1"])
    }

    @Test func textIsKeyedByItsPlaceAmongText() {
        #expect(keys([.text("a"), rect, .text("b")]) == ["#text:0", "rect:0", "#text:1"])
    }

    @Test func aFragmentsChildrenBecomeSiblings() {
        let children: [VSVGNode] = [.fragment([g("a"), .fragment([g("b")])]), g("c")]

        #expect(keys(children) == ["a", "b", "c"])
    }

    /// `.raw` because the reconciler cannot diff opaque markup.
    @Test func whatDrawsNothingOrCannotBeMountedIsLeftOut() {
        #expect(keys([.empty, .raw("<g/>"), .text(""), .fragment([]), g("a")]) == ["a"])
    }

    /// A keyed list with two equal keys is undefined in the reconciler.
    @Test func aRepeatedIdStillGetsAKeyOfItsOwn() {
        let all = keys([g("dup"), g("dup"), g("dup")])

        #expect(all.first == "dup")
        #expect(Set(all).count == 3)
    }

    @Test func eachChildCarriesItsNode() {
        let children = mountedChildren(of: [.fragment([path]), g("a")])

        #expect(children.map { $0.node } == [path, g("a")])
    }
    // MARK: - The frame

    private func svg(_ viewBox: String) -> VSVGNode {
        .element(.svg, [VSVGAttribute("width", "10"), VSVGAttribute("viewBox", viewBox)])
    }

    @Test func aDrawingsFrameIsItsViewBox() {
        #expect(mountedFrame(of: svg("-50.0 -12.5 188.56 332.32")) == VRect(x: -50, y: -12.5, width: 188.56, height: 332.32))
    }

    @Test func whatHasNoReadableViewBoxHasNoFrame() {
        #expect(mountedFrame(of: svg("0 0 100")) == nil)
        #expect(mountedFrame(of: svg("0 0 wide 100")) == nil)
        #expect(mountedFrame(of: .element(.svg)) == nil)
        #expect(mountedFrame(of: .element(.g, [VSVGAttribute("viewBox", "0 0 1 1")])) == nil)
    }
}
