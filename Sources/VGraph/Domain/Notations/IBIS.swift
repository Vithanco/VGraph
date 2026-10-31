import MathUtils

extension Notations {

    public struct Ibis: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }
        public static let id: Identifier<Notation> = .init(rawValue: "Ibis")
        public static let description =
            "Models arguments and decisions as Questions, Answers, Pros, and Cons, enabling structured exploration of any problem."

        // MARK: - Self-description
        // These properties power the `metadescription IBIS` VGL statement and feed the
        // Markdown self-description document. Factual content is lifted from the
        // Vithanco website notation page; editorial/narrative parts remain on the web.

        public static let purpose: String = """
            Issue-Based Information Systems (IBIS) can display any conversation or thought \
            process with just four node types — Questions, Answers/Ideas, Pros, and Cons. \
            Adding questions to any other node lets you explore each part of the diagram \
            in any depth needed, which makes IBIS well suited to "wicked" problems where \
            the structure of the problem itself is under debate.
            """

        public static let whenToUse: [String] = [
            "Mapping an open-ended question or wicked problem where several answers are worth comparing.",
            "Capturing a dialogue or group discussion so the branching arguments stay legible.",
            "Structuring a self-coaching or decision session: question → ideas → pros/cons → choice.",
            "Probing the assumptions behind an answer, a pro, or a con by attaching a follow-up question to it.",
        ]

        public static let history: String = """
            Werner Kunz and Horst Rittel invented the Issue-Based Information System (IBIS) \
            notation in 1970 as an argumentation-based approach to support the analysis of \
            so-called "wicked" problems. Jeff Conklin later popularised the technique as \
            Dialogue Mapping, using IBIS to capture group conversations in real time.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "Issues as Elements of Information Systems (Kunz & Rittel, 1970)",
                url: "https://www.researchgate.net/publication/246907404_Issues_as_Elements_of_Information_Systems"
            ),
            NotationReference(
                title: "Issue-based information system (Wikipedia)",
                url: "https://en.wikipedia.org/wiki/Issue-based_information_system"
            ),
            NotationReference(
                title: "Dialogue Mapping — Jeff Conklin",
                url: "https://www.goodreads.com/book/show/19093260-dialogue-mapping"
            ),
        ]

        // Color palette — from Vithanco Diagram Style Guide.
        // Dark variants derived via `ColorMath.darkOf`.
        public static let questionFill = SemanticColor(id: "ibis.question.fill", lightHex: "#f0ebff")
        public static let questionBorder = SemanticColor(id: "ibis.question.border", lightHex: "#6038d0")
        public static let questionText = SemanticColor(id: "ibis.question.text", lightHex: "#301878")
        public static let answerFill = SemanticColor(id: "ibis.answer.fill", lightHex: "#fff8e8")
        public static let answerBorder = SemanticColor(id: "ibis.answer.border", lightHex: "#c08820")
        public static let answerText = SemanticColor(id: "ibis.answer.text", lightHex: "#784808")
        public static let proFill = SemanticColor(id: "ibis.pro.fill", lightHex: "#ebfff2")
        public static let proBorder = SemanticColor(id: "ibis.pro.border", lightHex: "#20a048")
        public static let proText = SemanticColor(id: "ibis.pro.text", lightHex: "#085828")
        public static let conFill = SemanticColor(id: "ibis.con.fill", lightHex: "#ffebeb")
        public static let conBorder = SemanticColor(id: "ibis.con.border", lightHex: "#d03048")
        public static let conText = SemanticColor(id: "ibis.con.text", lightHex: "#881028")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [Self.question, Self.answer, Self.pro, Self.con]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        question,
                        description: "Questions are the key driver of IBIS. They are the starting point and can be connected to all other node types."
                    ),
                    NodeTypeDefinition(
                        answer,
                        description: "An idea or answer for a question. Answers are evaluated through pro and con arguments."),
                    NodeTypeDefinition(
                        pro,
                        description: "An argument in favour of an answer. Pros help evaluate and decide between competing answers."),
                    NodeTypeDefinition(
                        con,
                        description: "An argument against an answer. Cons help evaluate and decide between competing answers."),
                ]
            }

            private static let questionId = "Question"
            private static let answerId = "Answer"
            private static let proId = "Pro"
            private static let conId = "Con"

            public static let question: NodeType = NodeType(string: questionId)
            public static let answer: NodeType = NodeType(string: answerId)
            public static let pro: NodeType = NodeType(string: proId)
            public static let con: NodeType = NodeType(string: conId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.questionToQuestion,
                    Self.answerToQuestion,
                    Self.proToQuestion,
                    Self.conToQuestion,
                    Self.questionToAnswer,
                    Self.answerToPro,
                    Self.answerToCon,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        questionToQuestion,
                        description: "A question can raise a further question, enabling infinite depth of inquiry."),
                    EdgeTypeDefinition(
                        answerToQuestion,
                        description: "An answer can raise a further question — e.g., to probe its assumptions."),
                    EdgeTypeDefinition(
                        proToQuestion,
                        description: "A pro argument can raise a further question — e.g., to test its validity."),
                    EdgeTypeDefinition(
                        conToQuestion,
                        description: "A con argument can raise a further question — e.g., to explore how to overcome it."),
                    EdgeTypeDefinition(
                        questionToAnswer,
                        description: "A question is answered by this idea or answer."),
                    EdgeTypeDefinition(
                        answerToPro,
                        description: "This answer is supported by a pro argument."),
                    EdgeTypeDefinition(
                        answerToCon,
                        description: "This answer is objected to by a con argument."),
                ]
            }

            public static let questionToQuestion: EdgeType = EdgeType(
                id: "question_questions_question", from: Notations.Ibis.NodeTypes.question,
                to: Notations.Ibis.NodeTypes.question)
            public static let answerToQuestion: EdgeType = EdgeType(
                id: "answer_questions_question", from: Notations.Ibis.NodeTypes.answer,
                to: Notations.Ibis.NodeTypes.question)
            public static let proToQuestion: EdgeType = EdgeType(
                id: "pro_questions_question", from: Notations.Ibis.NodeTypes.pro,
                to: Notations.Ibis.NodeTypes.question)
            public static let conToQuestion: EdgeType = EdgeType(
                id: "con_questions_question", from: Notations.Ibis.NodeTypes.con,
                to: Notations.Ibis.NodeTypes.question)

            public static let questionToAnswer: EdgeType = EdgeType(
                id: "answered_by", from: Notations.Ibis.NodeTypes.question,
                to: Notations.Ibis.NodeTypes.answer)

            public static let answerToPro: EdgeType = EdgeType(
                id: "supports", from: Notations.Ibis.NodeTypes.answer,
                to: Notations.Ibis.NodeTypes.pro)
            public static let answerToCon: EdgeType = EdgeType(
                id: "objects_to", from: Notations.Ibis.NodeTypes.answer,
                to: Notations.Ibis.NodeTypes.con)
        }

        public static var values: [TypeValues] {
            [
                .badge(NodeTypes.question, "Question", icon: "question", fill: questionFill, border: questionBorder, text: questionText),
                .badge(NodeTypes.answer, "Answer", icon: "answer", fill: answerFill, border: answerBorder, text: answerText),
                .badge(NodeTypes.pro, "Pro", icon: "pro", fill: proFill, border: proBorder, text: proText),
                .badge(NodeTypes.con, "Con", icon: "con", fill: conFill, border: conBorder, text: conText),
            ]
        }

        // MARK: - Quality Checks

        public static var qualityChecks: [QualityCheck] {
            [QualityCheckRegistry.treeStructureCheck, unansweredQuestions]
        }

        /// Every Question should have at least one Answer.
        static func unansweredQuestions(_ graph: VGraph) -> [MessageWithSeverity] {
            let topology = GraphTopology(edges: graph.edges)
            var messages: [MessageWithSeverity] = []
            for node in graph.nodes {
                guard let nt = try? graph.nodeType(for: node), nt == NodeTypes.question else { continue }
                let hasAnswer = topology.outgoingEdges(of: node).contains {
                    (try? graph.nodeType(for: $0.to)) == NodeTypes.answer
                }
                if !hasAnswer {
                    let label =
                        (try? graph.get(node: node, attribute: Attributes.Node.label))
                        ?? node.description
                    messages.append(
                        MessageWithSeverity(
                            message:
                                "Question \"\(label)\" has no Answer — every Question should have at least one Answer",
                            severity: .warning,
                            target: .node(node.description)
                        ))
                }
            }
            return messages
        }
    }

}
