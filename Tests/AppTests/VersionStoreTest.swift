// Contract coverage for InMemoryVersionStore, the default
// ForStoreDocumentVersions adapter. See docs/adr/0007.

import Testing
import VGraph

@testable import App

struct VersionStoreTest {
    @Test func freshStoreIsAnEmptyDocumentRatherThanATrap() {
        let store = InMemoryVersionStore()
        #expect(store.vgl(of: store.current) == "")
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
    }

    @Test func resetSeedsARootVersion() throws {
        var store = InMemoryVersionStore()
        try store.reset(vgl: "root")
        #expect(store.vgl(of: store.current) == "root")
        #expect(store.parent(of: store.current) == nil)
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
    }

    @Test func recordAdvancesCurrentAndLinksParentChild() throws {
        var store = InMemoryVersionStore()
        try store.reset(vgl: "v1")
        let root = store.current
        let child = try store.record(vgl: "v2")

        #expect(store.current == child)
        #expect(store.vgl(of: child) == "v2")
        #expect(store.parent(of: child) == root)
        #expect(store.children(of: root) == [child])
        #expect(store.canUndo == true)
        #expect(store.canRedo == false)
    }

    @Test func amendReplacesCurrentContentWithoutMovingParent() throws {
        var store = InMemoryVersionStore()
        try store.reset(vgl: "v1")
        let root = store.current
        let child = try store.record(vgl: "v2")
        try store.amend(vgl: "v2-amended")

        #expect(store.current == child)  // no new version
        #expect(store.vgl(of: child) == "v2-amended")
        #expect(store.parent(of: child) == root)
    }

    @Test func undoRedoRoundTrip() throws {
        var store = InMemoryVersionStore()
        try store.reset(vgl: "v1")
        let root = store.current
        let child = try store.record(vgl: "v2")

        #expect(try store.undo() == root)
        #expect(store.current == root)
        #expect(store.canRedo == true)

        #expect(try store.redo() == child)
        #expect(store.current == child)
        #expect(store.canRedo == false)
    }

    @Test func undoAtRootReturnsNilAndStaysPut() throws {
        var store = InMemoryVersionStore()
        try store.reset(vgl: "v1")
        let root = store.current
        #expect(try store.undo() == nil)
        #expect(store.current == root)
    }

    @Test func redoAtTipReturnsNilAndStaysPut() throws {
        var store = InMemoryVersionStore()
        try store.reset(vgl: "v1")
        _ = try store.record(vgl: "v2")
        let tip = store.current
        #expect(try store.redo() == nil)
        #expect(store.current == tip)
    }

    @Test func parentAndChildrenAreMirrorImages() throws {
        var store = InMemoryVersionStore()
        try store.reset(vgl: "v1")
        let a = store.current
        let b = try store.record(vgl: "v2")
        let c = try store.record(vgl: "v3")

        #expect(store.parent(of: c) == b)
        #expect(store.children(of: b) == [c])
        #expect(store.parent(of: b) == a)
        #expect(store.children(of: a) == [b])
        #expect(store.children(of: c) == [])  // tip has no children
    }

    @Test func recordingAfterUndoDivergesAndDropsTheOldTail() throws {
        var store = InMemoryVersionStore()
        try store.reset(vgl: "v1")
        let root = store.current
        _ = try store.record(vgl: "v2")  // abandoned branch
        _ = try store.undo()
        let diverged = try store.record(vgl: "v2-alt")

        #expect(store.current == diverged)
        #expect(store.parent(of: diverged) == root)
        #expect(store.canRedo == false)
        // The abandoned "v2" version number is never reassigned.
        #expect(diverged.number == 3)
    }

    @Test func versionNumbersAreMonotonicAndWholeAndNeverReused() throws {
        var store = InMemoryVersionStore()
        try store.reset(vgl: "v1")  // number 1
        let v2 = try store.record(vgl: "v2")  // number 2
        #expect(v2.number == 2)
        _ = try store.undo()
        let v3 = try store.record(vgl: "v2-alt")  // number 3, not reusing 2
        #expect(v3.number == 3)
        #expect(v3.number != v2.number)
    }

    @Test func capBoundsDepthAndDropsOldestByDefault() throws {
        var store = InMemoryVersionStore(maxHistory: 3)
        try store.reset(vgl: "v1")
        _ = try store.record(vgl: "v2")
        _ = try store.record(vgl: "v3")
        _ = try store.record(vgl: "v4")  // pushes "v1" out past the cap

        var steps = 0
        while store.canUndo {
            _ = try store.undo()
            steps += 1
        }
        #expect(steps == 2)  // only 3 entries retained: 2 undo steps to the oldest
        #expect(store.vgl(of: store.current) == "v2")
    }

    @Test func versionDroppedPastTheCapNoLongerResolves() throws {
        var store = InMemoryVersionStore(maxHistory: 2)
        try store.reset(vgl: "v1")
        let root = store.current
        #expect(store.vgl(of: root) == "v1")

        _ = try store.record(vgl: "v2")
        _ = try store.record(vgl: "v3")  // pushes the root out past the cap

        #expect(store.vgl(of: root) == nil)
    }

    @Test func resetStartsAFreshRootUnrelatedToPriorHistory() throws {
        var store = InMemoryVersionStore()
        try store.reset(vgl: "v1")
        let old = store.current
        _ = try store.record(vgl: "v2")

        try store.reset(vgl: "fresh")
        #expect(store.vgl(of: store.current) == "fresh")
        #expect(store.parent(of: store.current) == nil)
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
        // The prior document's versions are gone from this store.
        #expect(store.vgl(of: old) == nil)
    }
}
