// MCP tool for creating Concept Map diagrams from VGL.

import Foundation
import MCP
import VGraph

public enum ConceptMapTool: VGraphTool {
    public static let name = "create_concept_map"
    public static let errorNoun = "concept map"
    public static let notationName = "ConceptMap"

    public static let purposeSentence = """
        A Concept Map defines the vocabulary of a domain \
        through falsifiable propositions. It helps people align on exact wordings and shared \
        understanding by stating facts as simple, readable sentences.
        """

    public static let vglParameterDescription = """
        Valid VGL code using the ConceptMap notation. \
        Must start with: vgraph <id>: ConceptMap "<title>" { ... }
        """

    private static let entry = Notations.ConceptMap.entry

    public static var descriptionBody: String {
        """
        ## How to Build a Concept Map

        1. Start with a Guiding Question (used as the graph title) — it determines what belongs on the map.
        2. List all relevant concepts.
        3. Connect every concept through relations. ALWAYS form readable propositions.
        4. NEVER leave a concept unconnected. Every concept MUST connect to at least one relation.
        5. Reuse relations when multiple concepts share the same relationship.

        ## VGL Syntax

        ```
        vgraph <id>: ConceptMap "<Guiding Question>" {
            <nodes and edges>
        }
        ```

        ### Node Types

        \(NotationMarkdown.nodeTypeBullets(entry.nodeTypeDefinitions))

        ```
        node <id>: Concept "<label>"
        node <id>: EmphasizedConcept "<label>"
        node <id>: Relation "<label>"
        ```

        ### Edges

        Valid connections:
        \(NotationMarkdown.edgeConnectionBullets(entry.edgeTypeDefinitions))

        ```
        edge <from_id> -> <to_id>
        ```

        ALWAYS form the pattern: Concept -> Relation -> Concept. This creates a readable proposition.

        ## Reusing Relations

        When multiple concepts share the same relationship, reuse a single Relation node. \
        No duplicate edges when reusing — create edges only where needed:

        **Multiple sources, one target:**
        ```
        vgraph animals: ConceptMap "What are common pets?" {
            node dog: Concept "Dog"
            node cat: Concept "Cat"
            node isa: Relation "is a"
            node mammal: Concept "Mammal"

            edge dog -> isa
            edge cat -> isa
            edge isa -> mammal  // Only ONE edge from relation to target
        }
        ```

        Both "Dog is a Mammal" and "Cat is a Mammal" share one Relation node — only 4 nodes total.

        **One source, multiple targets:**
        ```
        vgraph typography: ConceptMap "What defines a font?" {
            node font: Concept "Font"
            node has: Relation "has"
            node weight: Concept "Weight"
            node style: Concept "Style"

            edge font -> has  // Only ONE edge from source to relation
            edge has -> weight
            edge has -> style
        }
        ```

        Both "Font has Weight" and "Font has Style" share one Relation node — only 4 nodes total.

        **CRITICAL — Multiple inbound AND multiple outbound edges:**

        When a relation has BOTH multiple inbound edges (concepts pointing TO the relation) AND \
        multiple outbound edges (relation pointing TO concepts), ALL inbound concepts must make sense \
        as propositions with ALL outbound concepts. With n inbound and m outbound edges, you get n × m \
        propositions — all must be valid.

        **Invalid example:**
        ```
        vgraph learning: ConceptMap "What enables growth?" {
            node learning: Concept "Learning"
            node accountability: Concept "Accountability"
            node enables: Relation "enables"

            edge learning -> enables
            edge accountability -> enables
            edge enables -> learning
            edge enables -> accountability
        }
        ```

        This creates 4 propositions (2 × 2):
        - Learning enables Learning ❌ (circular)
        - Learning enables Accountability ✓
        - Accountability enables Learning ✓
        - Accountability enables Accountability ❌ (circular)

        **Fix — Use specific relations:**
        ```
        vgraph learning: ConceptMap "What enables growth?" {
            node learning: Concept "Learning"
            node accountability: Concept "Accountability"
            node facilitates: Relation "facilitates"
            node requires: Relation "requires"

            edge accountability -> facilitates
            edge facilitates -> learning

            edge learning -> requires
            edge requires -> accountability
        }
        ```

        Now: "Accountability facilitates Learning" ✓ and "Learning requires Accountability" ✓

        **Fix — Restructure:**
        ```
        vgraph learning: ConceptMap "What enables growth?" {
            node learning: Concept "Learning"
            node accountability: Concept "Accountability"
            node environment: Concept "Environment"
            node creates: Relation "creates"

            edge learning -> creates
            edge accountability -> creates
            edge creates -> environment
        }
        ```

        Now: "Learning creates Environment" ✓ and "Accountability creates Environment" ✓

        ## Complete Example

        ```
        vgraph learningCM: ConceptMap "What is Learning?" {
            node student: Concept "Student"
            node subject: Concept "Subject"
            node practice: EmphasizedConcept "Practice"
            node understanding: Concept "Understanding"
            node resources: Concept "Resources"

            node learns: Relation "learns"
            node requires: Relation "requires"
            node leads_to: Relation "leads to"
            node uses: Relation "uses"

            edge student -> learns
            edge learns -> subject
            edge subject -> requires
            edge requires -> practice
            edge practice -> leads_to
            edge leads_to -> understanding
            edge subject -> uses
            edge uses -> resources
        }
        ```

        Propositions: Student learns Subject, Subject requires Practice, \
        Practice leads to Understanding, Subject uses Resources.

        ## Rules

        1. ALWAYS form readable propositions — every Concept -> Relation -> Concept chain MUST read as a natural, falsifiable sentence
        2. NEVER leave a concept unconnected
        3. **Concept labels are nouns** — concept labels should be nouns or noun phrases (things, ideas, entities), not actions, sentences, or verb phrases. Use "Understanding" not "How we understand things"
        4. **Verb agreement** — Relation labels must match the subject's number: singular concepts (e.g., "Student", "Dog") use singular verbs ("requires", "is", "has"); plural concepts (e.g., "LLMs", "Dogs") use plural verbs ("require", "are", "have"). For mixed cases, use infinitive form without "(s)": "enable" not "enables", "prevent" not "prevents". The notation "Dog(s)" in concept labels can indicate the concept works in both forms, then use infinitive verb forms.
        5. **Guiding question as filter** — the guiding question determines what belongs on the map. Every concept MUST help answer it. If a concept does not contribute to answering the guiding question, it does not belong.
        6. **Relationship diversity** — use diverse relation types (not all "is a" or "has"). Avoid simple opposite pairs (e.g. "is parent of" / "is child of" are the same relationship stated twice in different directions). Use different verbs that reveal distinct aspects of how concepts relate.
        7. **Rich connectivity** — every concept should connect to at least 2 others via different relations. Aim for a network structure where multiple paths exist between concepts — not a chain (linear A→B→C) or a spoke (one central concept with everything hanging off it).
        8. Use meaningful IDs (student, practice — not n1, n2)
        9. Keep relation labels short (verbs or short phrases)
        10. Use EmphasizedConcept sparingly
        11. **Introduce abbreviations** — if a concept label uses an abbreviation, spell out the full term first: e.g. "Gross National Product (GNP)", not just "GNP"
        """
    }
}
