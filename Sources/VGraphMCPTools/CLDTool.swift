// MCP tool for creating Causal Loop Diagrams (CLD) from VGL.

import Foundation
import MCP
import VGraph

public enum CLDTool: VGraphTool {
    public static let name = "create_cld"
    public static let errorNoun = "causal loop diagram"
    public static let notationName = "CLD"

    public static let purposeSentence = """
        A Causal Loop Diagram (CLD) is a Systems Thinking tool that maps feedback loops \
        between variables, showing how a change in one variable causes changes in others. \
        It reveals reinforcing dynamics (exponential growth or decline) and balancing dynamics \
        (stabilisation toward equilibrium).
        """

    public static let vglParameterDescription = """
        Valid VGL code using the CLD notation. \
        Must start with: vgraph <id>: CLD "<title>" { ... }
        """

    private static let entry = Notations.CausalLoopDiagram.entry

    public static var descriptionBody: String {
        """
        ## Core Concepts

        A CLD consists of **variables** (called Stocks) connected by **causal links** with polarity:

        - **same** (`s`): when A increases, B increases; when A decreases, B decreases. Drawn as a solid arrow.
        - **opposite** (`o`): when A increases, B decreases; when A decreases, B increases. Drawn as a dashed arrow.

        A **feedback loop** is a closed chain of causal links returning to the starting variable:

        - **Reinforcing loop (R)**: even number of `opposite` edges (including zero). Drives exponential \
        growth or decline — a snowball effect.
        - **Balancing loop (B)**: odd number of `opposite` edges. Drives the system toward equilibrium — \
        a thermostat effect.

        ## How to Build a CLD

        1. Identify the key variables (stocks) in the system — things whose value can increase or decrease.
        2. For each pair of causally related variables, determine the polarity: does an increase in A cause \
        B to increase (same) or decrease (opposite)?
        3. Trace closed loops and classify them as reinforcing or balancing using the counting rule.
        4. Give the diagram a title that frames the system boundary.

        ## VGL Syntax

        ```
        vgraph <id>: CLD "<title>" {
            <nodes and edges>
        }
        ```

        ### Node Types

        \(NotationMarkdown.nodeTypeBullets(entry.nodeTypeDefinitions))

        ```
        node <id>: Stock "<label>"
        ```

        ### Edges

        \(NotationMarkdown.edgeTypeBullets(entry.edgeTypeDefinitions))

        CRITICAL: You MUST specify the edge type (`: same` or `: opposite`) on every edge. \
        Both edge types connect Stock to Stock, so the type CANNOT be inferred — omitting it will cause an error.

        ```
        edge <from_id> -> <to_id>: same
        edge <from_id> -> <to_id>: opposite
        ```

        ## Identifying Feedback Loops

        To classify a loop, trace a closed path back to the starting variable and count the `opposite` edges:

        - **0 opposite edges** → Reinforcing (R): Population → Birth Rate → Population \
        (more people → more births → even more people)
        - **1 opposite edge** → Balancing (B): Population → Death Rate → Population \
        (more people → more deaths → fewer people)

        Rule: even count = reinforcing, odd count = balancing.

        ## Complete Example

        ```
        vgraph populationCLD: CLD "Population Dynamics" {
            node population: Stock "Population"
            node births: Stock "Birth Rate"
            node deaths: Stock "Death Rate"
            node resources: Stock "Available Resources"

            edge population -> births: same
            edge births -> population: same
            edge population -> deaths: same
            edge deaths -> population: opposite
            edge population -> resources: opposite
            edge resources -> births: same
        }
        ```

        **Loop analysis:**
        - **R1 (Reinforcing):** Population → Birth Rate → Population — \
        0 opposite edges. More people produce more births, which increases population. Growth spiral.
        - **B1 (Balancing):** Population → Death Rate → Population — \
        1 opposite edge. More people means more deaths, which reduces population. Death regulation.
        - **B2 (Balancing):** Population → Available Resources → Birth Rate → Population — \
        1 opposite edge (population → resources). More people deplete resources, reducing birth rate. \
        Resource constraint.

        ## Rules

        1. ALWAYS specify the edge type (`: same` or `: opposite`) — it cannot be inferred
        2. Stock labels should be nouns or noun phrases representing measurable quantities that can \
        increase or decrease (e.g. "Population", "Revenue", "Stress Level" — not "People are born" \
        or "Increasing")
        3. Every Stock MUST connect to at least one other Stock — no isolated variables
        4. Think in terms of "if A increases, what happens to B?" to determine same vs opposite polarity
        5. Use meaningful IDs (population, revenue, stress — not n1, n2, n3)
        6. Keep the diagram focused on one system — the title should frame the boundary
        7. Aim for closed loops — a CLD without any feedback loop is just a causal chain and misses \
        the point of systems thinking
        8. Prefer 3–6 variables per loop for clarity — larger loops are hard to trace and verify
        """
    }
}
