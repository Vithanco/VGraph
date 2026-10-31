// MCP tool for creating IBIS (Issue-Based Information System) diagrams from VGL.

import Foundation
import MCP
import VGraph

public enum IBISTool: VGraphTool {
    public static let name = "create_ibis"
    public static let errorNoun = "IBIS diagram"
    public static let notationName = "IBIS"

    public static let purposeSentence = """
        IBIS (Issue-Based Information System) maps out any decision, discussion, or thought \
        process using just four node types: Questions, Answers (Ideas), Pros, and Cons. \
        Attaching Questions to any node lets you drill into any aspect at any depth.
        """

    public static let vglParameterDescription = """
        Valid VGL code using the IBIS notation. \
        Must start with: vgraph <id>: IBIS "<title>" { ... }
        """

    private static let entry = Notations.Ibis.entry

    public static var descriptionBody: String {
        """
        ## How to Build an IBIS Diagram

        1. Start with a root Question (used as the graph title).
        2. Add Answers (Ideas) that respond to the question.
        3. Add Pro and Con arguments for each answer.
        4. Attach further Questions to any node to drill deeper.
        5. Keep going until the topic is explored to the depth you need.

        ## VGL Syntax

        ```
        vgraph <id>: IBIS "<title>" {
            <nodes and edges>
        }
        ```

        ### Node Types

        \(NotationMarkdown.nodeTypeBullets(entry.nodeTypeDefinitions))

        ```
        node <id>: Question "<label>"
        node <id>: Answer "<label>"
        node <id>: Pro "<label>"
        node <id>: Con "<label>"
        ```

        ### Edges

        Edge types are inferred from node types — just write `edge <from> -> <to>`.

        Valid connections:
        \(NotationMarkdown.edgeConnectionBullets(entry.edgeTypeDefinitions))

        ```
        edge <from_id> -> <to_id>
        ```

        ## The Drill-Down Mechanism

        The power of IBIS is that you can attach a Question to **any** node type:
        - Question a Question: "Shouldn't we rather discuss X?"
        - Question an Answer: "What would we need to implement this?"
        - Question a Pro: "Is this advantage really significant?"
        - Question a Con: "Can we mitigate this disadvantage?"

        Each sub-question starts its own Answer/Pro/Con branch, allowing unlimited depth.

        ## Complete Example

        ```
        vgraph techChoice: IBIS "Which database should we use?" {
            node q1: Question "Which database should we use?"

            node a1: Answer "PostgreSQL"
            node a2: Answer "MongoDB"

            edge q1 -> a1
            edge q1 -> a2

            node pro1: Pro "ACID compliance"
            node pro2: Pro "Mature ecosystem"
            node con1: Con "Schema migrations can be complex"

            edge a1 -> pro1
            edge a1 -> pro2
            edge a1 -> con1

            node pro3: Pro "Flexible schema"
            node con2: Con "Weaker transaction support"

            edge a2 -> pro3
            edge a2 -> con2

            node q2: Question "How to handle schema migrations?"
            edge con1 -> q2

            node a3: Answer "Use Flyway or Liquibase"
            edge q2 -> a3

            node pro4: Pro "Industry-standard tooling"
            edge a3 -> pro4
        }
        ```

        ## Rules

        1. ALWAYS start with a root Question — it frames the entire diagram
        2. Follow the structure: Question -> Answer -> Pro/Con
        3. Use Questions to drill down — attach them to any node that needs exploration
        4. Keep labels concise — Questions as questions, Answers as noun phrases, Pros/Cons as short statements
        5. Use meaningful IDs (q1, mainIdea, costCon — not n1, n2, n3)
        6. Each Answer should have at least one Pro or Con to be useful
        7. Avoid orphan nodes — every node must connect to the tree
        """
    }
}
