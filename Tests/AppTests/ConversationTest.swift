//
//  ConversationTest.swift
//  VGraph
//
//  The multi-step command conversation (CONTEXT.md [[VCommand]]): which
//  question a command opens with, what each answer decides, and when there is
//  no question at all.
//
//  These rules lived in `VGraphWasm/VGraphEditor/Editor.swift`, where only a
//  browser test could reach them. The replay machinery is gone (ADR-0013)
//  but its shape survives: the adapter asks the domain what a command
//  would need, collects the answers, and makes one named call. Deciding *that*
//  is what is tested here.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct ConversationTest {
    /// Concept has exactly one outgoing edge type (`concept_to_relation`);
    /// Relation has two (to Concept and to EmphasizedConcept). One notation,
    /// both sides of "is there a question to ask".
    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)
    }

    /// Two Concepts and nothing declared between them: the pair a drop can only
    /// reach by declaring a relationship for it.
    private func twoConcepts() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                }
                """)
    }

    /// The only node type is Stock, and two edge types join it to itself — so
    /// creating a node has nothing to ask and reversing an edge does.
    private func causalLoopDiagram() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  edge s1 -> s2;
                }
                """)
    }

    // MARK: - Opening a conversation

    /// ADR-0016's rule, and the one duplicated across `addRelatedCommand`,
    /// `changeTypeCommand` and `splitCommand` in the editor: where the notation
    /// leaves exactly one candidate there is nothing to ask, so the command runs.
    @Test("A lone candidate is not a choice — the command runs unasked")
    func aLoneCandidateIsNotAChoice() throws {
        let session = try conceptMap()

        let (step, _) = EditorCore.begin(
            .addSuccessor, on: "a", forcingChoice: false, in: session)

        #expect(
            step
                == .perform(
                    .addRelated(
                        to: "a", outgoing: true,
                        using: EdgeType.Id(string: "concept_to_relation"))))
    }

    /// Two candidates is a real question. Asserted by candidate id — the edge
    /// types the notation declares leaving Relation — rather than by rebuilding
    /// the option list the way the code does.
    @Test("Two candidates are put on screen as a choice")
    func aRealChoiceIsAsked() throws {
        let session = try conceptMap()

        let (step, _) = EditorCore.begin(
            .addSuccessor, on: "r", forcingChoice: false, in: session)

        guard case .ask(let prompt, let options) = step else {
            Issue.record("expected a question, got \(step)")
            return
        }
        #expect(prompt == "Add successor")
        #expect(
            options.filter { !$0.isBreak }.map(\.id)
                == ["relation_to_concept", "relation_to_emphasized_concept"])
    }

    /// A notation declaring one node type is not asked which one to make
    /// (ADR-0016) — the same rule as a lone candidate, on a list that carries no
    /// escape hatch because a node joined to nothing breaks nothing.
    @Test("A notation with one node type is not asked which to add")
    func addingANodeWithNothingToChooseRunsUnasked() throws {
        let session = try causalLoopDiagram()
        let root = session.rootGroupId()

        let (step, _) = EditorCore.begin(
            .addNode, on: root, forcingChoice: false, in: session)

        #expect(step == .perform(.addNode(in: root, ofType: NodeType(string: "Stock"), notationBreak: .forbidden)))
    }

    /// Reversing is a question only where more than one edge type could carry
    /// the edge the other way. ConceptMap joins Relation to Concept exactly one
    /// way, so `a -> r` reverses without asking — and `to: nil` is how the named
    /// method is told to pick for itself.
    @Test("An edge with one reversal is reversed unasked")
    func reversingWithNoChoiceRunsUnasked() throws {
        let session = try conceptMap()
        let edgeId = session.origin.edges.first!.id.id

        let (step, _) = EditorCore.begin(
            .changeDirection, on: edgeId, forcingChoice: false, in: session)

        #expect(
            step
                == .perform(
                    .changeDirection(edge: edgeId, to: nil, notationBreak: .forbidden)))
    }

    /// Concept may only become EmphasizedConcept, and that leaves the edge it
    /// carries determined — one candidate and no ambiguity, so the whole
    /// conversation collapses to a single call with no answers in it.
    @Test("Retyping with one candidate and no ambiguity runs unasked")
    func retypingWithNothingToDecideRunsUnasked() throws {
        let session = try conceptMap()

        let (step, _) = EditorCore.begin(
            .changeType, on: "a", forcingChoice: false, in: session)

        #expect(
            step
                == .perform(
                    .changeType(
                        node: "a", to: NodeType(string: "EmphasizedConcept"),
                        edgeTypes: [], notationBreak: .forbidden)))
    }

    /// CLD's two edge types give four ways to insert a Stock into an edge, so
    /// splitting is a real question.
    @Test("An edge with several insertions asks which")
    func splittingWithAChoiceAsks() throws {
        let session = try causalLoopDiagram()
        let edgeId = session.origin.edges.first!.id.id

        let (step, _) = EditorCore.begin(
            .split, on: edgeId, forcingChoice: false, in: session)

        guard case .ask(let prompt, let options) = step else {
            Issue.record("expected a question, got \(step)")
            return
        }
        #expect(prompt == "Split")
        #expect(options.map(\.id) == ["same>same", "same>opposite", "opposite>same", "opposite>opposite"])
    }

    /// The answer is an insertion's id, and what the command needs is the
    /// insertion itself — the pair of edge types it puts either side of the new
    /// node. Resolving one back to the other is the decision here.
    @Test("A chosen insertion is resolved back to its pair of edge types")
    func splittingUsesTheInsertionPicked() throws {
        let session = try causalLoopDiagram()
        let edgeId = session.origin.edges.first!.id.id
        let expected = session.splitCandidates(for: edgeId).first { $0.id == "same>opposite" }!
        let (_, opened) = EditorCore.begin(
            .split, on: edgeId, forcingChoice: false, in: session)

        let (step, _) = EditorCore.next(
            after: VCommandOption(id: "same>opposite", title: "Stock"),
            in: opened, session: session)

        #expect(step == .perform(.split(edge: edgeId, with: expected)))
    }

    /// ConceptMap declares no way to insert a node between Concept and Relation,
    /// so there is neither a question nor a command — the menu just closes.
    @Test("An edge with no insertion at all is not a command")
    func splittingWithNothingOnOfferDismisses() throws {
        let session = try conceptMap()
        let edgeId = session.origin.edges.first!.id.id

        let (step, _) = EditorCore.begin(
            .split, on: edgeId, forcingChoice: false, in: session)

        #expect(step == .dismiss)
    }

    // MARK: - The one question that is typed rather than picked

    /// A node carrying a link the parser accepted but `VURL` will not follow.
    /// VGL can say what `setURL` would refuse, which is how a stored link and an
    /// openable one come apart.
    private func linked() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: IBIS "Demo" {
                  node q1: Question "Q" [url: "https://vithanco.com/q"];
                  node q2: Question "R" [url: "javascript:alert(1)"];
                }
                """)
    }

    /// Free text is typed where it belongs, so `setURL` is the one command whose
    /// question is a field rather than a list — and it opens holding what is
    /// already there.
    @Test("The URL field opens holding the link already stored")
    func theURLFieldSeedsFromWhatIsStored() throws {
        let session = try linked()

        let (step, _) = EditorCore.begin(.setURL, on: "q1", forcingChoice: false, in: session)

        #expect(step == .askText(prompt: "URL", initial: "https://vithanco.com/q"))
    }

    /// The rule the seeding turns on: a link too dangerous to follow is still a
    /// link the user typed. Seeding from `urlToOpen` would hand them an empty
    /// field and silently discard what was there.
    @Test("A link too dangerous to follow still seeds the field")
    func aRefusedLinkStillSeedsTheField() throws {
        let session = try linked()
        #expect(session.storedURL(of: "q2") == "javascript:alert(1)")
        #expect(session.urlToOpen(of: "q2") == nil)

        let (step, _) = EditorCore.begin(.setURL, on: "q2", forcingChoice: false, in: session)

        #expect(step == .askText(prompt: "URL", initial: "javascript:alert(1)"))
    }

    @Test("Submitting the field sets the link")
    func submittingTheFieldSetsTheLink() throws {
        let session = try linked()
        let (_, opened) = EditorCore.begin(.setURL, on: "q1", forcingChoice: false, in: session)

        let (step, _) = EditorCore.next(afterText: "https://example.org", in: opened)

        #expect(step == .perform(.setURL(element: "q1", to: "https://example.org")))
    }

    /// Neither blank nor a link `VURL` will take: the field re-opens holding
    /// what was typed, so the user can correct it rather than retype it.
    @Test("A link the domain refuses re-opens the field holding what was typed")
    func aRefusedLinkIsAskedAgain() throws {
        let session = try linked()
        let (_, opened) = EditorCore.begin(.setURL, on: "q1", forcingChoice: false, in: session)

        let step = EditorCore.next(
            afterRefusing: .urlRefused(target: "q1", url: "not a link"),
            typed: "not a link", in: opened)

        #expect(step == .askText(prompt: "URL", initial: "not a link"))
    }

    /// A refusal about the *target* rather than the text has nothing to re-ask
    /// about — re-opening the field would loop on it forever. Driven by the
    /// error the domain actually raises, not a hand-picked case.
    @Test("A refusal about the target abandons rather than looping")
    func aRefusalAboutTheTargetAbandons() throws {
        let session = try linked()
        let (_, opened) = EditorCore.begin(.setURL, on: "q1", forcingChoice: false, in: session)

        var refusal: VError? = nil
        do { try session.setURL(of: "gone", to: "https://example.org") } catch { refusal = error }

        let step = EditorCore.next(
            afterRefusing: try #require(refusal), typed: "https://example.org", in: opened)

        #expect(step == .dismiss)
    }

    // MARK: - Gestures, which have no menu target

    /// A [[Gesture]] names two elements, so it never arrives through the menu
    /// (CONTEXT.md [[VCommand]]). ConceptMap joins Concept to Relation exactly
    /// one way, so the drop settles itself and `using: nil` lets the named
    /// method pick.
    @Test("A drop with one possible edge type connects unasked")
    func connectingWithNoChoiceRunsUnasked() throws {
        let session = try conceptMap()

        let (step, _) = EditorCore.beginConnect(
            from: "a", to: "r", allowingBreak: false, in: session)

        #expect(
            step
                == .perform(
                    .connect(from: "a", to: "r", using: nil, notationBreak: .forbidden)))
    }

    /// Two edge types join Stock to Stock, so the drop cannot be decided from
    /// the two nodes alone. The question names the elements by label, which is
    /// the only prompt in the editor built from the graph rather than fixed.
    /// Against the fixture's one edge, since a CLD offers nothing for a pair
    /// already joined that way (`noParallelEdges`).
    @Test("A drop with two possible edge types asks, naming both elements")
    func connectingWithAChoiceAsks() throws {
        let session = try causalLoopDiagram()

        let (step, _) = EditorCore.beginConnect(
            from: "s2", to: "s1", allowingBreak: false, in: session)

        guard case .ask(let prompt, let options) = step else {
            Issue.record("expected a question, got \(step)")
            return
        }
        #expect(prompt == "Demand → Price")
        #expect(options.map(\.id) == ["same", "opposite"])
    }

    /// ⌥ mints an unknown type outright rather than offering a list, so a
    /// permitted break asks nothing at all (ADR-0012).
    @Test("A permitted break connects without asking")
    func connectingPastTheNotationAsksNothing() throws {
        let session = try causalLoopDiagram()

        let (step, _) = EditorCore.beginConnect(
            from: "s1", to: "s2", allowingBreak: true, in: session)

        #expect(
            step
                == .perform(
                    .connect(from: "s1", to: "s2", using: nil, notationBreak: .permitted)))
    }

    /// An edge left wearing a minted type: **Change type** is reachable even
    /// though the notation names no alternative, and the one entry is the way
    /// out of the break (ADR-0024).
    @Test("An unknown-typed edge offers a way out under Change type")
    func anUnknownTypedEdgeOffersDeclaring() throws {
        let session = try twoConcepts()
        try session.connect("a", to: "b", using: nil, notationBreak: .permitted)
        let edge = session.origin.edges.first!.id.id

        #expect(EditorCore.availability(of: .changeType, on: edge, in: session) == .available)
        let (step, _) = EditorCore.begin(.changeType, on: edge, forcingChoice: false, in: session)

        guard case .ask(_, let options) = step else {
            Issue.record("expected a question, got \(step)")
            return
        }
        #expect(options.map(\.id) == ["__declare__"])
        // Not a break: it widens the notation rather than going past it.
        #expect(!options.contains { $0.isBreak })
    }

    /// Picking it asks for a name, seeded with what the pair would
    /// conventionally be called, so Return accepts it.
    @Test("Declaring asks for a name, seeded from the edge's two node types")
    func declaringAsksForAName() throws {
        let session = try twoConcepts()
        try session.connect("a", to: "b", using: nil, notationBreak: .permitted)
        let edge = session.origin.edges.first!.id.id
        let (_, opened) = EditorCore.begin(
            .changeType, on: edge, forcingChoice: false, in: session)

        let (step, _) = EditorCore.next(
            after: EditorCore.declareOption, in: opened, session: session)

        #expect(step == .askText(prompt: "Name this relationship", initial: "concept_to_concept"))
    }

    @Test("The name typed settles the command")
    func theNameTypedDeclaresTheType() throws {
        let session = try twoConcepts()
        try session.connect("a", to: "b", using: nil, notationBreak: .permitted)
        let edge = session.origin.edges.first!.id.id
        let (_, opened) = EditorCore.begin(
            .changeType, on: edge, forcingChoice: false, in: session)
        let (_, asking) = EditorCore.next(
            after: EditorCore.declareOption, in: opened, session: session)

        let (step, _) = EditorCore.next(afterText: "leads_nowhere", in: asking)

        #expect(step == .perform(.declareEdgeType(edge: edge, named: "leads_nowhere")))
    }

    /// A refused name re-opens the field on what was typed, exactly as a refused
    /// URL does — the user can correct it, so closing the menu would be wrong.
    @Test("A refused name asks again")
    func aRefusedNameAsksAgain() throws {
        let session = try twoConcepts()
        try session.connect("a", to: "b", using: nil, notationBreak: .permitted)
        let edge = session.origin.edges.first!.id.id
        let (_, opened) = EditorCore.begin(
            .changeType, on: edge, forcingChoice: false, in: session)

        let step = EditorCore.next(
            afterRefusing: .edgeTypeNameRefused(name: "2fast"), typed: "2fast", in: opened)

        #expect(step == .askText(prompt: "Name this relationship", initial: "2fast"))
    }

    /// A [[Reattach]] names an [[Edge end]] rather than a node — a position on
    /// an edge, so the pair (edge, end) travels together and the conversation
    /// has to hold both alongside the node dropped on (ADR-0021).
    @Test("Reattaching to a node with two possible types asks")
    func reattachingWithAChoiceAsks() throws {
        let session = try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  node s3: Stock "Supply";
                  edge s1 -> s2;
                }
                """)
        let edgeId = session.origin.edges.first!.id.id

        let (step, _) = EditorCore.beginReattach(
            edge: edgeId, end: .to, to: "s3", allowingBreak: false, in: session)

        guard case .ask(let prompt, let options) = step else {
            Issue.record("expected a question, got \(step)")
            return
        }
        #expect(options.map(\.id) == ["same", "opposite"])
        // Source before destination, as `connect`'s prompt reads. Moving `.to`
        // puts the node dropped on last; the edge's own label never appears.
        #expect(prompt == "Price → Supply")
    }

    /// The mirror: moving the `.from` end puts the node dropped on first, so the
    /// prompt still reads in the edge's direction.
    @Test("Moving the from end names the dropped node first")
    func reattachingTheFromEndReadsForwards() throws {
        let session = try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  node s3: Stock "Supply";
                  edge s1 -> s2;
                }
                """)
        let edgeId = session.origin.edges.first!.id.id

        let (step, _) = EditorCore.beginReattach(
            edge: edgeId, end: .from, to: "s3", allowingBreak: false, in: session)

        guard case .ask(let prompt, _) = step else {
            Issue.record("expected a question, got \(step)")
            return
        }
        #expect(prompt == "Supply → Demand")
    }

    // MARK: - Answering one

    /// The escape hatch is not a candidate — picking it replaces the question
    /// rather than answering it, and what comes back is the full node-type list
    /// ([[Notation break]]). `breakChoice` is how the next answer is read as a
    /// node type and not an edge type.
    @Test("Choosing the escape hatch asks for a node type instead")
    func theEscapeHatchOpensTheTypeList() throws {
        let session = try conceptMap()
        let (_, conversation) = EditorCore.begin(
            .addSuccessor, on: "r", forcingChoice: false, in: session)

        let (step, answered) = EditorCore.next(
            after: EditorCore.breakOption, in: conversation, session: session)

        guard case .ask(let prompt, let options) = step else {
            Issue.record("expected a second question, got \(step)")
            return
        }
        #expect(prompt == "Node type (breaks notation)")
        #expect(answered.breakChoice)
        #expect(options.contains { $0.id == "Concept" })
    }

    /// End to end past the notation: ⌥ forces the list on a node whose single
    /// candidate would otherwise have skipped it, the escape hatch opens the
    /// type list, and the type picked there creates a Concept where the notation
    /// declares only Relation. A different named call from the candidate path —
    /// the node type is chosen directly, so no edge type carries it.
    @Test("A node type chosen past the notation creates that node")
    func theBreakAnswerCreatesTheChosenType() throws {
        let session = try conceptMap()
        let (_, opened) = EditorCore.begin(
            .addSuccessor, on: "a", forcingChoice: true, in: session)
        let (_, asking) = EditorCore.next(
            after: EditorCore.breakOption, in: opened, session: session)

        let (step, _) = EditorCore.next(
            after: VCommandOption(id: "Concept", title: "Concept"), in: asking, session: session)

        #expect(
            step
                == .perform(
                    .addRelatedBreaking(
                        to: "a", outgoing: true, ofType: NodeType(string: "Concept"))))
    }

    /// The node-type list from `addNode` carries no escape hatch, so its answer
    /// is always a plain type — `breakChoice` never enters into it.
    @Test("A node type answers the add-node question")
    func addingANodeUsesTheTypePicked() throws {
        let session = try conceptMap()
        let root = session.rootGroupId()
        let (_, opened) = EditorCore.begin(
            .addNode, on: root, forcingChoice: false, in: session)

        let (step, _) = EditorCore.next(
            after: VCommandOption(id: "Relation", title: "Relation"),
            in: opened, session: session)

        #expect(step == .perform(.addNode(in: root, ofType: NodeType(string: "Relation"), notationBreak: .forbidden)))
    }

    /// CLD joins Stock to Stock two ways, so reversing is a real question and
    /// the answer names the type the reversed edge takes.
    @Test("A chosen reversal type is what the edge becomes")
    func reversingUsesTheTypePicked() throws {
        let session = try causalLoopDiagram()
        let edgeId = session.origin.edges.first!.id.id
        let (_, opened) = EditorCore.begin(
            .changeDirection, on: edgeId, forcingChoice: false, in: session)

        let (step, _) = EditorCore.next(
            after: VCommandOption(id: "opposite", title: "opposite"),
            in: opened, session: session)

        #expect(
            step
                == .perform(
                    .changeDirection(
                        edge: edgeId, to: EdgeType.Id(string: "opposite"),
                        notationBreak: .forbidden)))
    }

    /// ⌥ has already permitted the break by the time the list is on screen, so
    /// there is no reversal for the escape hatch to name — unlike every other
    /// command, picking it here abandons rather than opening the type list.
    @Test("The escape hatch abandons a reversal rather than opening the type list")
    func reversingHasNothingBehindTheEscapeHatch() throws {
        let session = try causalLoopDiagram()
        let edgeId = session.origin.edges.first!.id.id
        let (_, opened) = EditorCore.begin(
            .changeDirection, on: edgeId, forcingChoice: true, in: session)

        let (step, _) = EditorCore.next(
            after: EditorCore.breakOption, in: opened, session: session)

        #expect(step == .dismiss)
    }

    /// The gesture's answer carries the pair the drag settled, not a menu
    /// target — which is why the conversation had to hold both ends.
    @Test("A chosen edge type joins the two dropped nodes")
    func connectingUsesTheTypePicked() throws {
        let session = try causalLoopDiagram()
        let (_, opened) = EditorCore.beginConnect(
            from: "s1", to: "s2", allowingBreak: false, in: session)

        let (step, _) = EditorCore.next(
            after: VCommandOption(id: "same", title: "same"), in: opened, session: session)

        #expect(
            step
                == .perform(
                    .connect(
                        from: "s1", to: "s2", using: EdgeType.Id(string: "same"),
                        notationBreak: .forbidden)))
    }

    /// "Change it to what it already is" is not an offer, so retyping is the one
    /// command whose break list drops a type — unlike creating a node, where
    /// every type is a real choice.
    @Test("The break list for a retype leaves out the element's own type")
    func retypingsBreakListExcludesTheCurrentType() throws {
        let session = try conceptMap()
        let (_, opened) = EditorCore.begin(
            .changeType, on: "a", forcingChoice: true, in: session)

        let (step, _) = EditorCore.next(
            after: EditorCore.breakOption, in: opened, session: session)

        guard case .ask(_, let options) = step else {
            Issue.record("expected the type list, got \(step)")
            return
        }
        #expect(!options.contains { $0.id == "Concept" })
        #expect(options.contains { $0.id == "Relation" })
    }

    /// `next` tests the escape hatch *once*, above the command switch. The
    /// original tested it per command and deliberately did not test it for
    /// `addNode`, `connect` or `reattach` — so hoisting it is equivalent only
    /// because those three lists never carry one.
    ///
    /// That equivalence lives in `Menu.swift`, a different file, and nothing
    /// else notices if it stops holding: adding a break entry to `connectOptions`
    /// would silently turn a dropped edge into a node-type picker.
    ///
    /// Each list is asserted non-empty first, so the check cannot pass by
    /// having nothing to look at.
    @Test("The lists hoisting the escape hatch relies on never carry one")
    func theHoistedEscapeHatchRestsOnListsThatCarryNone() throws {
        let cld = try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  node s3: Stock "Supply";
                  edge s1 -> s2;
                }
                """)
        let edgeId = cld.origin.edges.first!.id.id

        // ConceptMap declares three node types, so this list is a real one.
        let map = try conceptMap()
        let nodeTypes = EditorCore.addNodeOptions(on: map.rootGroupId(), in: map)
        #expect(!nodeTypes.isEmpty)
        #expect(!nodeTypes.contains { $0.isBreak })

        let connect = EditorCore.connectOptions(
            from: "s1", to: "s3", notationBreak: .forbidden, in: cld)
        #expect(!connect.isEmpty)
        #expect(!connect.contains { $0.isBreak })

        let reattach = EditorCore.reattachOptions(
            edge: edgeId, end: .to, to: "s3", notationBreak: .forbidden, in: cld)
        #expect(!reattach.isEmpty)
        #expect(!reattach.contains { $0.isBreak })
    }

    // MARK: - The retype loop, the only conversation that accumulates

    /// Two edges left ambiguous by the chosen type, asked one at a time. The
    /// state is built here rather than derived from a notation because no
    /// shipped notation produces an ambiguous retype today — the loop is the
    /// rule under test, not the notation that would trigger it.
    private func retyping(_ chosen: [EdgeType.Id]) -> Conversation {
        Conversation(
            command: .changeType, subject: .element("a"), forceChoice: false,
            retype: Retype(
                type: NodeType(string: "EmphasizedConcept"),
                ambiguous: [
                    VAmbiguousEdge(
                        edgeId: "e1", prompt: "A → R",
                        options: [
                            EdgeType(id: "concept_to_relation", from: NodeType(string: "Concept"), to: NodeType(string: "Relation"))
                        ]),
                    VAmbiguousEdge(
                        edgeId: "e2", prompt: "R → B",
                        options: [
                            EdgeType(id: "relation_to_concept", from: NodeType(string: "Relation"), to: NodeType(string: "Concept"))
                        ]),
                ],
                chosen: chosen))
    }

    @Test("An edge answer is kept and the next edge is asked")
    func eachEdgeAnswerAdvancesTheLoop() throws {
        let session = try conceptMap()

        let (step, advanced) = EditorCore.next(
            after: VCommandOption(id: "concept_to_relation", title: "carries"),
            in: retyping([]), session: session)

        guard case .ask(let prompt, _) = step else {
            Issue.record("expected the second edge's question, got \(step)")
            return
        }
        #expect(prompt == "R → B")
        #expect(advanced.retype?.chosen == [EdgeType.Id(string: "concept_to_relation")])
    }

    /// The answers reach the command positionally, in the order they were asked
    /// — which is what `ambiguousEdges(ifRetyping:to:)` promises.
    @Test("The last edge answer runs the retype carrying every answer in order")
    func theFinalEdgeAnswerRunsTheCommand() throws {
        let session = try conceptMap()

        let (step, _) = EditorCore.next(
            after: VCommandOption(id: "relation_to_concept", title: "carries"),
            in: retyping([EdgeType.Id(string: "concept_to_relation")]), session: session)

        #expect(
            step
                == .perform(
                    .changeType(
                        node: "a", to: NodeType(string: "EmphasizedConcept"),
                        edgeTypes: [
                            EdgeType.Id(string: "concept_to_relation"),
                            EdgeType.Id(string: "relation_to_concept"),
                        ],
                        notationBreak: .forbidden)))
    }

    /// The ordinary path: a candidate the notation offered is an edge type, and
    /// the new node's type follows from its far end (CONTEXT.md [[Candidate]]).
    @Test("A candidate chosen from the list creates that relationship")
    func aCandidateAnswerCreatesTheRelationship() throws {
        let session = try conceptMap()
        let (_, opened) = EditorCore.begin(
            .addSuccessor, on: "r", forcingChoice: false, in: session)

        let (step, _) = EditorCore.next(
            after: VCommandOption(id: "relation_to_concept", title: "Concept"),
            in: opened, session: session)

        #expect(
            step
                == .perform(
                    .addRelated(
                        to: "r", outgoing: true,
                        using: EdgeType.Id(string: "relation_to_concept"))))
    }
}
