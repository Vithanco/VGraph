# Vithanco Graph Language (VGL) Guide

VGL is a human-readable text format for creating and editing graphs — a
declarative syntax for nodes, edges, groups and their attributes.

- [Concepts](#concepts)
- [Notations](#notations)
- [Notation reference](#notation-reference)
- [User-defined notations (vnotation)](#user-defined-notations-vnotation)
- [Metagraph](#metagraph-visualising-a-notation)
- [Grammar](#grammar)
- [Best practices](#best-practices)

## Concepts

### The document

Every VGL document declares a notation, which fixes the node and edge types
available:

```
vgraph <graph_id>: <NOTATION> "<graph_label>" {
    ...
}
```

### Nodes

```
node <id>: <NodeType> "<label>" [<attributes>];
```

The id must be unique in the document; the label and attributes are optional.

```vgl
node q1: Question "What should we do?" [fontsize: 16; color: red];
```

### Edges

```
edge <from_id> -> <to_id>: <EdgeType> "<label>" [<attributes>];
```

Both endpoints must be declared. **Omit the edge type and VGL infers it** from
the node types, whenever that is unambiguous — which is most of the time, so
most documents never name an edge type at all.

```vgl
edge q1 -> a1: answered_by "Initial solution";
edge a1 -> pro1 [style: dashed];
edge q2 -> a2;                              // type inferred
```

### Groups

Groups organise nodes hierarchically, nest to any depth, and may carry
attributes. Edges may cross group boundaries freely.

```vgl
group research "Research Phase" {
    style: filled;
    color: lightblue;

    node q1: Question "What to research?";
    node a1: Answer "User interviews";

    group methodology "Methods" {
        node m1: Pro "Direct feedback";
    };
};
```

**Folded groups.** Prefix a group with `folded` to render it collapsed into a
single box. Folding auto-redirects any edges that crossed the boundary to the
collapsed box, and the editor can fold and unfold in place.

```vgl
folded group methodology "Methods" { … };
```

**Typed groups.** A group can carry a type after its id, mirroring node typing —
`group <id>: <GroupType> "<label>" { … }`. The type selects its appearance: a
C4 `Organisation` draws a dashed boundary when unfolded and a grey card when
folded. See [C4](#c4).

**Detailed nodes.** When the type is a *node* type rather than a group type, the
group is a detailed node: the node itself, with its details inside —
`group ibs: SoftwareSystem "Internet Banking System" { … }`. It takes the node's
attributes (`url`, `tooltip`, `backgroundcolor`, …) in its body and in views; a
key that a node and a group share means the node's. It starts folded;
`isfolded: false` in a view (or in its body) opens it, and the boundary it then
draws comes from its node type. See ADR-0032.

### Views

One file can show its model several ways. A `vview` after the `vgraph` block
changes only how things are *shown* — fold state, layout direction, colours —
never what is true, so quality checks read the same in every view.

```vgl
vview context "System Context" {
    folded node type: SoftwareSystem;
}

vview containers "Containers" [rankdir: LR] {
    node db [backgroundColor: "#ffd27f"];
    node customer, web [fontsize: 16];
}
```

A view sets presentation attributes on `node`/`group` ids or, spelled with a
colon, on a type (`node type: Container`). It cannot type, label or add members.
A value equal to what the model already gives is dropped on export, so a view
follows the model rather than pinning it. A view naming something the model
lacks is kept and affects nothing.

A view also chooses *what* it shows, with rules applied in order. `include` and
`exclude` take a selector — `node`/`group` ids, `node type:`/`group type:`
names, or `*` — optionally widened along edges by `+n` (n steps either way),
`downstream n` or `upstream n`; `expand n` widens the result so far. A view whose
first rule is `include` starts empty, any other starts with everything.
Selectors always read the model, never what earlier rules left. Edges are never
selected: one shows when both its ends do, and where a view hides the middle of
a chain it draws a dotted derived edge instead (`derivedEdges: false` turns them
off). A rule chooses elements and sets nothing.

```vgl
vview journey "Customer journey" {
    include node customer downstream 2;
    exclude node type: Database;
}
```

A node type also stands for its detailed nodes: `include node type:
SoftwareSystem` shows them with their details, and `folded node type:
SoftwareSystem` folds them. `group type:` picks plain groups only.

The model itself is the default view. Pick another by name:
`vgraph-cli svg --view context`.

### Attributes

Inline in brackets, `[a: 1; b: 2]`, or as bare statements inside a graph or
group body.

| Applies to | Attributes |
|---|---|
| Node | `color`, `fontColor`, `fontsize`, `shape`, `url`, `alignGroup` (nodes sharing a value are placed at the same rank) |
| Edge | `style` (`solid`/`dashed`/`dotted`), `color`, `weight`, `label`, `url` |
| Group | `style` (`filled`/`dashed`/`dotted`), `color`, `label`, `url` |
| Graph | `rankdir` (`LR`/`TB`), `fontcolor`, `labeljust` (`l`/`r`/`c`), `loopMarkers` (`all`/`independent`/`none`, Causal Loop Diagrams: which loops get an R/B marker), `watermark` (`true` by default; `false` leaves the Vithanco mark off the exported image) |

**Colouring one node.** `color` sets a node's fill, overriding whatever its type
says. `fontColor` sets the text on it; leave it out and the text is set to black
or white for contrast, but only where it would otherwise stop being legible.

```vgl
node epBackend: Container "Equipment Pooling Backend" [color: "#b6e6bd"];
node onApp: Container "ON App" [color: "#ffe08a"; fontColor: "#5c3d00"];
```

This is a per-node exception, not a second axis: the node keeps its type, so its
shape, its stereotype line and every quality check still apply. Use it to mark
what is new or changed in an otherwise ordinary diagram, and say what the colours
mean somewhere the reader can see.

Every colour in VGL — a node's, an edge's, a group's, a graph's `fontcolor` — is
a hex value or one of the 147 **SVG colour keywords** (`red`, `cornflowerblue`,
`whitesmoke`). Graphviz's larger X11 set is not accepted: `chartreuse3` is an
error, not a silent no-op. A name you write is kept as you
wrote it when the document is exported; it is never derived back from a colour,
since `grey` and `gray` are the same value.

### Links

Any node, edge or group may carry a `url` pointing at whatever the element
stands for — a ticket, a repository, a wiki page:

```vgl
node q1: Question "Which datastore?" [url: "https://issues.example.com/ARCH-14"];
```

A linked element wears a small badge, clipped to its corner or sitting on the
line for an edge. Clicking it follows the link in a new tab; hovering shows the
destination first. The right-click menu carries **Add URL…** / **Change URL…**,
**Open URL** and **Remove URL**.

Only `http`, `https` and `mailto` are accepted, and anything without a scheme is
read as `https://`. Other schemes — `javascript:` above all, which would
otherwise run as the page displaying the diagram — are refused. The check runs
again at render time, so hand-written VGL cannot smuggle one into a published
SVG either.

The badge is a real SVG link, so an exported SVG stays clickable wherever it is
embedded (inline or via `<object>`; an SVG inside an `<img>` is inert by browser
design).

### Comments

`//` to end of line, anywhere in the document. Comments are **not discarded**: a
comment belongs to the declaration it stands above, or follows on the same line,
and is written back on save or export.

An element's leading comments are the whole block above it, back to the previous
declaration — a blank line inside the block does not break it, so a section
banner keeps its place:

```vgl
// ==========================================
// TOP LEVEL - Undesirable Effects
// ==========================================

// Top row
node ude1: UndesirableEffect "Suppliers display a less uniform front";
```

A comment with nothing to belong to *is* dropped: before a closing brace, inside
a `vnotation` block, or after the final `}`.

`comment` is reserved as an attribute name. `[comment: "text"]` is an equivalent
way to attach one — useful when generating VGL programmatically — and it
re-exports as a `// text` line.

### Type inference and minimal syntax

Everything optional, omitted:

```vgl
vgraph minimal: IBIS "Minimal Example" {
    node q1: Question "Which database should we use?";
    node a1: Answer "PostgreSQL";
    node a2: Answer "MongoDB";
    node p1: Pro "ACID compliance";
    node c1: Con "More complex setup";

    edge q1 -> a1;      // inferred: answered_by
    edge q1 -> a2;
    edge a1 -> p1;      // inferred: supports
    edge a1 -> c1;      // inferred: objects_to
}
```

## Notations

These notations are built in. Each has its own section in the
[notation reference](#notation-reference), giving its node types, its edge types
and a complete worked example.

| Notation | For |
|---|---|
| [**IBIS**](#ibis) | decision-making and argumentation |
| [**BBS**](#bbs) | benefit breakdown and analysis |
| [**ImpactMapping**](#impact-mapping) | strategic planning and goal alignment |
| [**ConceptMap**](#concept-map) | domain vocabulary as falsifiable propositions |
| [**CRT**](#current-reality-tree-crt) | root cause analysis (Theory of Constraints) |
| [**FRT**](#future-reality-tree-frt) | solution validation (ToC) |
| [**TRT**](#transition-tree-trt) | step-by-step implementation planning (ToC) |
| [**PRT**](#prerequisite-tree-prt) | planning with necessary-condition thinking (ToC) |
| [**EC**](#evaporating-cloud-ec) | conflict resolution (ToC necessary-condition logic) |
| [**GoalTree**](#goal-tree) | strategic planning through Goal, CSFs and Necessary Conditions |
| [**ADTree**](#attack-defense-tree-adtree) | security modelling of attack and defense interactions |
| [**CLD**](#causal-loop-diagram-cld) | systems analysis: what reinforces or balances what over time |
| [**DecisionTree**](#decision-tree) | decision logic as questions, choices and outcomes |
| [**Timeline**](#timeline) | events across multiple tracks on a shared time axis |
| [**C4**](#c4) | software architecture across four levels of zoom |
| [**Arithmetic**](#arithmetic) | simple equations, checked as they are built |

You can also render a notation's own structure as a diagram with a `metagraph`
declaration — see [Metagraph](#metagraph-visualising-a-notation).

The rest of this section covers what applies across notations: how multiple
arrows into one node are read, what the quality checks report, and how
extensions add cross-cutting types.

### Diagram logic and junctors

Each notation has a **diagram logic** that decides how multiple arrows into one
node are read, and therefore which junctor has to be an explicit node.

| Diagram logic | Multiple unjoined arrows mean… | Explicit junctor | Implicit |
|---|---|---|---|
| `sufficientCause` | OR — any one arrow suffices | **AND** | OR |
| `necessaryCondition` | AND — all arrows required | **OR** | AND |
| `noLogic` | notation-defined | — | — |

**Add only the *exception* junctor for your logic.** In sufficient-cause
notations (CRT, FRT, TRT, ADTree) declare an `AndJunctor` only for "all of these
together"; in necessary-condition ones (EC, PRT, GoalTree) declare an
`OrJunctor` only for "any one of these alternatives". Adding the implicit
junctor raises a `redundantJunctor` warning, since direct edges already say the
same thing with less noise. The same applies to notations you declare with
`vnotation`.

### Quality checks

Separately from notation breaks, notations run **quality checks**: advisory
analyses of the *shape* of a graph rather than its syntax. Each result carries a
severity — **info**, **warning** or **error** — but none of them stops a document
opening, and an error here means "this cannot be read as the notation intends",
not "this failed to parse". Most are advice you can knowingly ignore; the
thresholds are fixed, so they are worth knowing before you argue with one.

**Shared by most notations:** `noParallelEdges` — *error* — two edges between
the same two nodes in the same direction. The editor does not offer to draw the
second one. C4 and Arithmetic do without it.

The notation-specific checks below were current when written; there may be more
by now.

**IBIS**
- *warning* — a `Question` with no `Answer`.
- *warning* — any node with two or more incoming edges. This is a tree-shape
  check across every node type, so a Question raised by two separate `Pro` nodes
  trips it even though the map is legitimate.

**ConceptMap** — the largest set, ten diagnostics in all.
- *info* — the concept and relation counts and their ratio, reported on every
  map. This one is a statistic, not a complaint.
- *warning* — fewer than 5 concepts ("consider adding more"), or more than 25
  ("consider splitting into sub-maps").
- *warning* — a concept label of 4 words or more; 1–3 is the preferred range.
- *warning* — a vague relation verb. This matches a fixed list of eleven exact
  phrases — "relates to", "is related to", "is connected to", "involves", "is
  involved in", "is associated with", "is linked to", "pertains to", "concerns",
  "has something to do with", "is about" — case-insensitively, and nothing else.
  It is a blocklist, not a judgement of your wording.
- *warning* — a concept connected to no relation.
- *warning* — more than one disconnected cluster (single stray nodes are left to
  the check above).
- *warning* — two concepts linked in both directions; keep the more meaningful one.
- *warning* — a relation with several concepts on both sides, which asserts every
  combination: *n* inbound × *m* outbound propositions, all of which must hold.
- *error* — the same, but where a concept appears on both sides, making a
  proposition circular.
- *error* — a relation missing a concept on either side, so it forms no
  proposition at all.

**GoalTree**
- *error* — no `Goal`, or more than one. Exactly one is required.
- *info* — a CSF count outside the recommended 3–5. A partial draft with none yet
  reports this too.

**C4**
- *warning* — an element with no relationships at all. This one applies to every
  node type, not just elements that look like they should collaborate.
- Where elements may sit is the containment check every notation with
  [detailings](#detailedby--a-hierarchical-notation) gets (below).

**CLD**
- *warning* — more loops than can be marked; only the shortest get a marker.

**Arithmetic**
- *warning* — a division by zero, which cannot be evaluated.
- *error* — an operator with more than one first operand, second operand or
  result.

More quality warnings come from elsewhere: a
[redundant junctor](#diagram-logic-and-junctors), an
[unknown node or edge type](#grammar), and a node placed where its notation's
[detailings](#detailedby--a-hierarchical-notation) do not allow.

### Extensions

Extensions add cross-cutting node types to any notation, listed after it and
comma-separated:

```vgl
vgraph myGraph: ConceptMap, Annotation "My Diagram" { ... }
```

**Annotation** is the available extension: it adds two node types, `Annotation`
for notes and clarifications and `Warning` for caveats, that can be connected
*from* any node in the notation. Edge types to them are inferred, so these
edges need no explicit type.

```vgl
vgraph productMap: ConceptMap, Annotation "Product Strategy" {
    node c1: Concept "Customer Need"
    node r1: Relation "drives"
    node c2: Concept "Feature"
    node a1: Annotation "Validated in user research"
    node w1: Warning "Depends on a vendor contract"
    edge c1 -> r1
    edge r1 -> c2
    edge c1 -> a1
    edge c2 -> w1
}
```

## Notation reference

One section per built-in notation: its node types, its edge types, and a
complete worked example. Edge types constrain which connections make sense in
the notation's domain, and most are inferred from the node types, so you rarely
name one explicitly.

The editor's **Examples…** picker loads ready-made graphs straight into the
text area, and most of the examples below are the same graph. Where the guide's
version is the simpler one, the note under the example says so — the editor
carries a fuller variant worth opening. Some of the editor's examples have no
counterpart here, such as further IBIS graphs and one showing folded groups. The
syntax examples in [Concepts](#type-inference-and-minimal-syntax) are
guide-only.

### IBIS

Decision-making and argumentation.

**Node types**
- `Question` — a question or issue to be resolved
- `Answer` — a proposed answer or solution
- `Pro` — an argument supporting an answer
- `Con` — an argument opposing an answer

**Edge types**
- `answered_by` — Question → Answer
- `supports` — Answer → Pro
- `objects_to` — Answer → Con
- `pro_questions_question` — Pro → Question
- `con_questions_question` — Con → Question

The example below also serves as the tour of groups, attributes and cross-group
edges; for the smallest possible IBIS document see
[Type inference and minimal syntax](#type-inference-and-minimal-syntax).

```vgl
vgraph comprehensive: IBIS "Comprehensive Example" {
    rankdir: LR;
    fontcolor: darkblue;
    labeljust: l;

    node root: Question "Main Question" [fontsize: 20; color: navy];
    node ans1: Answer "Primary Solution" [fontsize: 16];

    group analysis "Detailed Analysis" {
        style: filled;
        color: lightgray;

        node q_perf: Question "What about performance?";
        node a_fast: Answer "Optimize critical paths" [color: green];
        node pro_perf: Pro "40% faster response time";

        group tradeoffs "Trade-offs" {
            style: dashed;
            color: yellow;

            node con_complex: Con "Increased code complexity";
            node q_maint: Question "Can we maintain this?";
        };

        edge q_perf -> a_fast: answered_by;
        edge a_fast -> pro_perf: supports;
        edge a_fast -> con_complex: objects_to;
        edge con_complex -> q_maint: con_questions_question "Raises concern";
    };

    // Cross-group connections
    edge root -> ans1: answered_by "Main path";
    edge ans1 -> q_perf: answered_by [style: dashed; weight: 5];
}
```

### BBS

Benefit breakdown and analysis.

**Node types**
- `InvestmentObjective` — high-level business objective
- `Benefit` — expected benefit from the investment
- `BusinessChange` — organisational or process change required
- `Enabler` — technology or capability enabler

**Edge types**
- `requires_benefit` — Benefit → InvestmentObjective
- `requires_business_change` — BusinessChange → Benefit
- `requires_enabler` — Enabler → BusinessChange
- `change_requires_change` — BusinessChange → BusinessChange
- `enabler_requires_enabler` — Enabler → Enabler

A benefit breakdown graph showing what an investment objective requires, read
bottom-up: enablers make business changes possible, which deliver benefits,
which satisfy the objective.

```vgl
vgraph customerSatisfaction: BBS "Customer Satisfaction Initiative" {
    node obj1: InvestmentObjective "Increase Customer Satisfaction by 25%";
    node ben1: Benefit "Faster Response Times";
    node ben2: Benefit "Improved Service Quality";
    node ben3: Benefit "24/7 Support Availability";
    node chg1: BusinessChange "Automated Ticket Routing";
    node chg2: BusinessChange "Self-Service Portal";
    node chg3: BusinessChange "Staff Training Program";
    node chg4: BusinessChange "24/7 Shift Coverage";
    node enb1: Enabler "AI-Powered Ticketing System";
    node enb2: Enabler "Customer Portal Platform";
    node enb3: Enabler "Training Materials & LMS";
    node enb4: Enabler "Staffing & Scheduling System";

    edge ben1 -> obj1: requires_benefit;
    edge ben2 -> obj1: requires_benefit;
    edge ben3 -> obj1: requires_benefit;
    edge chg1 -> ben1: requires_business_change;
    edge chg2 -> ben2: requires_business_change;
    edge chg3 -> ben2: requires_business_change;
    edge chg4 -> ben3: requires_business_change;
    edge enb1 -> chg1: requires_enabler;
    edge enb2 -> chg2: requires_enabler;
    edge enb3 -> chg3: requires_enabler;
    edge enb4 -> chg4: requires_enabler;
    edge chg1 -> chg2: change_requires_change;
    edge enb1 -> enb2: enabler_requires_enabler;
}
```

### Impact Mapping

A strategic planning graph showing goals, actors, impacts, and deliverables.

**Node types**
- `Goal` — strategic goal or objective
- `Actor` — person or group who can produce impact
- `Impact` — behavioural change or outcome
- `Deliverable` — product feature or capability

**Edge types**
- `goal_to_actor` — Goal → Actor
- `actor_to_impact` — Actor → Impact
- `impact_to_deliverable` — Impact → Deliverable

```vgl
vgraph mobileApp: ImpactMapping "Mobile App Launch" {
    node g1: Goal "Increase Revenue by 30%";
    node a1: Actor "New Customers";
    node a2: Actor "Existing Customers";
    node i1: Impact "Make First Purchase";
    node i2: Impact "Increase Purchase Frequency";
    node i3: Impact "Upgrade to Premium";
    node d1: Deliverable "Mobile App with Easy Checkout";
    node d2: Deliverable "Push Notifications for Deals";
    node d3: Deliverable "Loyalty Rewards Program";
    node d4: Deliverable "Premium Features Bundle";

    edge g1 -> a1: goal_to_actor;
    edge g1 -> a2: goal_to_actor;
    edge a1 -> i1: actor_to_impact;
    edge a2 -> i2: actor_to_impact;
    edge a2 -> i3: actor_to_impact;
    edge i1 -> d1: impact_to_deliverable;
    edge i2 -> d2: impact_to_deliverable;
    edge i2 -> d3: impact_to_deliverable;
    edge i3 -> d4: impact_to_deliverable;
}
```

### Concept Map

Domain vocabulary as falsifiable propositions. The title is a **Guiding
Question** that decides what belongs on the map, and every
`Concept → Relation → Concept` chain must read as a falsifiable sentence.

**Node types**
- `Concept` — a concept or term
- `EmphasizedConcept` — an important concept to highlight
- `Relation` — a linking verb or phrase connecting concepts, forming
  propositions of the shape `Concept → Relation → Concept`

**Edge types**
- `concept_to_relation` — Concept → Relation (tail marker only)
- `relation_to_concept` — Relation → Concept (arrow head only)
- `emphasized_concept_to_relation` — EmphasizedConcept → Relation
- `relation_to_emphasized_concept` — Relation → EmphasizedConcept

`EmphasizedConcept` takes its own pair, so an emphasized concept in a chain
needs those rather than the plain ones. Both are inferred, so this only matters
when naming a type explicitly.

```vgl
vgraph learningCM: ConceptMap "What is Learning?" {
    node student: Concept "Student";
    node subject: Concept "Subject";
    node practice: EmphasizedConcept "Practice";
    node understanding: Concept "Understanding";

    node learns: Relation "learns";
    node requires: Relation "requires";
    node leads_to: Relation "leads to";

    edge student -> learns;
    edge learns -> subject;
    edge subject -> requires;
    edge requires -> practice;
    edge practice -> leads_to;
    edge leads_to -> understanding;
}
```

Relationships are nodes rather than edge labels, which is what makes the
propositions readable: "Student learns Subject", "Subject requires Practice".
Never leave a concept unconnected. Reuse a single `Relation` node when several
concepts share it ("Dog is a Mammal", "Cat is a Mammal") — but note that a
relation with **both** multiple inbound and multiple outbound edges asserts every
combination: all n × m propositions must be valid. If any is circular or
meaningless, split the relation.

The editor's *ConceptMap — How Learning Works* is a variant of this map that
names every edge type explicitly, including the `EmphasizedConcept` pair.

### Current Reality Tree (CRT)

Root cause analysis (Theory of Constraints), showing how causes lead to
undesirable effects. Sufficient-cause logic, so multiple unjoined causes feeding
one effect are implicitly OR; only AND is explicit.

**Node types**
- `UndesirableEffect` — an unwanted outcome requiring investigation
- `IntermediateEffect` — a neutral outcome in the causal chain
- `DesirableEffect` — a wanted outcome caused by other conditions
- `Given` — an unchangeable constant, such as a law or physics
- `Changeable` — a modifiable condition that can be addressed
- `AndJunctor` — multiple conditions required together to produce the downstream
  effect (icon: AND circle; usually unlabelled, since the icon says it)

**Edge types.** CRT, FRT and TRT share one family, flowing bottom-to-top (causes
and actions at the bottom, effects at the top). Names are mechanical,
`<source>_causes_<target>`:

*Between effects:* `undesirable_causes_undesirable`,
`undesirable_causes_intermediate`, `undesirable_causes_desirable`,
`intermediate_causes_undesirable`, `intermediate_causes_intermediate`,
`intermediate_causes_desirable`, `desirable_causes_undesirable`,
`desirable_causes_intermediate`, `desirable_causes_desirable`

*From Given and Changeable:* `given_causes_undesirable`,
`given_causes_intermediate`, `given_causes_desirable`,
`changeable_causes_undesirable`, `changeable_causes_intermediate`,
`changeable_causes_desirable`

*Junctors:* `*_to_and_junctor` connects any type to an AndJunctor;
`and_junctor_causes_*` connects it onward to an effect.

CRT typically starts from effects and traces down to causes; FRT and TRT
typically start from `changeable_causes_*` and build upward.

```vgl
vgraph salesDecline: CRT "Sales Decline Analysis" {
    // Undesirable Effects (problems at the top)
    node ude1: UndesirableEffect "Sales revenue declining";
    node ude2: UndesirableEffect "Customer complaints increasing";
    node ude3: UndesirableEffect "Market share decreasing";

    // Intermediate Effects (neutral outcomes in the causal chain)
    node ie1: IntermediateEffect "Customers switching to competitors";
    node ie2: IntermediateEffect "Product perceived as outdated";
    node ie3: IntermediateEffect "Support response time is slow";

    // Desirable Effects (things we want to keep)
    node de1: DesirableEffect "Brand reputation still strong";

    // Given (unchangeable facts at the bottom)
    node g1: Given "Market is highly competitive";
    node g2: Given "Customer expectations keep rising";

    // Changeable (root causes we can address)
    node c1: Changeable "Product development cycle is too long";
    node c2: Changeable "Support team is understaffed";
    node c3: Changeable "No customer feedback loop";

    // Junctor for combining conditions
    node and1: AndJunctor "";

    // Root causes leading to intermediate effects
    edge c1 -> ie2: changeable_causes_intermediate;
    edge c3 -> ie2: changeable_causes_intermediate;
    edge c2 -> ie3: changeable_causes_intermediate;

    // Given facts contributing to situation
    edge g1 -> ie1: given_causes_intermediate;
    edge g2 -> and1: given_to_and_junctor;
    edge ie2 -> and1: intermediate_to_and_junctor;

    // And junctor combining conditions
    edge and1 -> ie1: and_junctor_causes_intermediate;

    // Alternative causes (implicit OR — any single arrow into ude2 is sufficient)
    edge ie1 -> ude2: intermediate_causes_undesirable;
    edge ie3 -> ude2: intermediate_causes_undesirable;

    // Intermediate effects leading to undesirable effects
    edge ie1 -> ude1: intermediate_causes_undesirable;
    edge ie1 -> ude3: intermediate_causes_undesirable;

    // Brand reputation affected but still positive
    edge ie2 -> de1: intermediate_causes_desirable;
}
```

### Future Reality Tree (FRT)

Solution validation (ToC), showing how proposed solutions lead to desired
outcomes. The same node types as CRT, both being sufficient-cause Theory of
Constraints tools. The difference is use: FRT starts from solutions
(`Changeable` injections) and builds upward to desirable effects.

**Node types**
- `Changeable` — proposed solutions or injections to implement
- `Given` — unchangeable facts that still apply
- `IntermediateEffect` — expected intermediate outcomes
- `DesirableEffect` — goals we want to achieve
- `UndesirableEffect` — potential negative side effects to monitor
- `AndJunctor` — as in CRT

**Edge types** — the CRT family, shared by CRT, FRT and TRT; see
[Current Reality Tree](#current-reality-tree-crt).

```vgl
vgraph salesSolution: FRT "Sales Improvement Plan" {
    // Changeable nodes (injections/solutions we will implement)
    node c1: Changeable "Implement agile product development";
    node c2: Changeable "Hire additional support staff";
    node c3: Changeable "Create customer feedback system";

    // Given (unchangeable facts that still apply)
    node g1: Given "Market is highly competitive";
    node g2: Given "Customer expectations keep rising";

    // Intermediate Effects (expected outcomes from our solutions)
    node ie1: IntermediateEffect "Faster product iterations";
    node ie2: IntermediateEffect "Products match customer needs";
    node ie3: IntermediateEffect "Support response time improves";
    node ie4: IntermediateEffect "Customer feedback drives development";

    // Junctor for combining conditions
    node and1: AndJunctor "";

    // Desirable Effects (the goals we want to achieve)
    node de1: DesirableEffect "Sales revenue increasing";
    node de2: DesirableEffect "Customer satisfaction high";
    node de3: DesirableEffect "Market share growing";

    // Potential negative side effects (to monitor)
    node ude1: UndesirableEffect "Initial implementation costs";

    // Solutions leading to intermediate effects
    edge c1 -> ie1: changeable_causes_intermediate;
    edge c3 -> ie4: changeable_causes_intermediate;
    edge c2 -> ie3: changeable_causes_intermediate;

    // Given facts combining with solutions
    edge g2 -> and1: given_to_and_junctor;
    edge ie4 -> and1: intermediate_to_and_junctor;

    // And junctor combining conditions
    edge and1 -> ie2: and_junctor_causes_intermediate;

    // Multiple alternative paths to customer satisfaction (implicit OR)
    edge ie2 -> de2: intermediate_causes_desirable;
    edge ie3 -> de2: intermediate_causes_desirable;

    // Intermediate effects leading to desirable effects
    edge ie1 -> de3: intermediate_causes_desirable;
    edge ie2 -> de1: intermediate_causes_desirable;
    edge ie2 -> de3: intermediate_causes_desirable;

    // Acknowledging potential downsides
    edge c1 -> ude1: changeable_causes_undesirable;
    edge c2 -> ude1: changeable_causes_undesirable;

    // Given competitive market affects outcomes
    edge g1 -> ie2: given_causes_intermediate;
}
```

### Transition Tree (TRT)

Step-by-step implementation planning (ToC). Shares CRT/FRT's node types but
answers "how do we *cause* the change?", giving the step-by-step action
sequence.

**Node types**
- `UndesirableEffect` — current-state problems being addressed
- `IntermediateEffect` — stepping-stone outcomes from actions
- `DesirableEffect` — goal outcomes
- `Given` — unchangeable facts and constraints
- `Changeable` — actions we can take to cause change
- `AndJunctor` — as in CRT

**Edge types** — the CRT family, shared by CRT, FRT and TRT; see
[Current Reality Tree](#current-reality-tree-crt).

A step-by-step implementation planning graph showing how actions lead to desired
outcomes:

```vgl
vgraph agileTransition: TRT "Agile Transformation Implementation" {
    // Given conditions (the context we're working within)
    node g1: Given "Company has 5 development teams";
    node g2: Given "Current waterfall process causes delays";

    // Changeable causes (actions we will take)
    node c1: Changeable "Introduce daily standups";
    node c2: Changeable "Implement CI/CD pipeline";
    node c3: Changeable "Create cross-functional teams";
    node c4: Changeable "Train teams on Scrum practices";

    // Intermediate effects (stepping stones from actions)
    node ie1: IntermediateEffect "Teams communicate more frequently";
    node ie2: IntermediateEffect "Code integration happens daily";
    node ie3: IntermediateEffect "Teams have diverse skillsets";
    node ie4: IntermediateEffect "Teams follow iterative process";
    node ie5: IntermediateEffect "Silos are broken down";

    // And junctors for combined conditions
    node and1: AndJunctor "";
    node and2: AndJunctor "";

    // Desirable effects (the goals we achieve)
    node de1: DesirableEffect "Faster time to market";
    node de2: DesirableEffect "Higher quality releases";
    node de3: DesirableEffect "Better team collaboration";

    // Actions lead to intermediate effects
    edge c1 -> ie1: changeable_causes_intermediate;
    edge c2 -> ie2: changeable_causes_intermediate;
    edge c3 -> ie3: changeable_causes_intermediate;
    edge c4 -> ie4: changeable_causes_intermediate;

    // Given context combines with cross-functional teams
    edge g1 -> and1: given_to_and_junctor;
    edge ie3 -> and1: intermediate_to_and_junctor;
    edge and1 -> ie5: and_junctor_causes_intermediate;

    // Breaking silos leads to collaboration
    edge ie5 -> de3: intermediate_causes_desirable;

    // Communication helps collaboration too
    edge ie1 -> de3: intermediate_causes_desirable;

    // CI/CD + iterative process combine for quality
    edge ie2 -> and2: intermediate_to_and_junctor;
    edge ie4 -> and2: intermediate_to_and_junctor;
    edge and2 -> de2: and_junctor_causes_desirable;

    // Quality and collaboration lead to speed
    edge de2 -> de1: desirable_causes_desirable;
    edge de3 -> de1: desirable_causes_desirable;

    // Given waterfall context is addressed by iterative process
    edge g2 -> ie4: given_causes_intermediate;
}
```

### Prerequisite Tree (PRT)

Planning with necessary-condition thinking, starting from the objective and
working back to obstacles.

**Node types**
- `Objective` — the desired goal
- `Obstacle` — a barrier preventing achievement
- `IntermediateObjective` — a milestone overcoming a specific obstacle
- `OR` — allows optional conditions instead of requiring all predecessors (icon: OR circle)

**Edge types** — flowing bottom-to-top, intermediate objectives at the bottom.
- `obstacle_blocks_objective` — Obstacle → Objective
- `obstacle_blocks_intermediate_objective` — Obstacle → IntermediateObjective
- `intermediate_objective_overcomes_obstacle` — IntermediateObjective → Obstacle
- `intermediate_objective_to_objective` — the direct path
- To the OR junctor: `obstacle_to_or`, `intermediate_objective_to_or`
- From it: `or_to_objective`, `or_to_intermediate_objective`, `or_to_obstacle`

A planning graph showing obstacles blocking objectives and intermediate
objectives to overcome them:

```vgl
vgraph projectLaunch: PRT "New Product Launch Planning" {
    // The main objective we want to achieve
    node obj1: Objective "Successfully launch product by Q3";

    // Obstacles blocking the main objective
    node obs1: Obstacle "Development team lacks required skills";
    node obs2: Obstacle "Marketing budget not approved";
    node obs3: Obstacle "No distribution channel established";

    // Intermediate objectives to overcome obstacles
    node io1: IntermediateObjective "Train team on new technology";
    node io2: IntermediateObjective "Hire experienced developers";
    node io3: IntermediateObjective "Present ROI analysis to leadership";
    node io4: IntermediateObjective "Partner with existing retailer";
    node io5: IntermediateObjective "Build direct-to-consumer channel";

    // OR junctor for alternative paths
    node or1: OR;
    node or2: OR;

    // Further obstacles blocking intermediate objectives
    node obs4: Obstacle "Training budget limited";
    node obs5: Obstacle "Talent pool is competitive";

    // Obstacles block the main objective
    edge obs1 -> obj1: obstacle_blocks_objective;
    edge obs2 -> obj1: obstacle_blocks_objective;
    edge obs3 -> obj1: obstacle_blocks_objective;

    // Alternative ways to overcome skill obstacle (via OR)
    edge io1 -> or1: intermediate_objective_to_or;
    edge io2 -> or1: intermediate_objective_to_or;
    edge or1 -> obs1: or_to_obstacle;

    // ROI analysis overcomes budget obstacle
    edge io3 -> obs2: intermediate_objective_overcomes_obstacle;

    // Alternative distribution solutions
    edge io4 -> or2: intermediate_objective_to_or;
    edge io5 -> or2: intermediate_objective_to_or;
    edge or2 -> obs3: or_to_obstacle;

    // Recursive obstacles blocking intermediate objectives
    edge obs4 -> io1: obstacle_blocks_intermediate_objective;
    edge obs5 -> io2: obstacle_blocks_intermediate_objective;
}
```

### Evaporating Cloud (EC)

A conflict-resolution tool using necessary-condition logic — "in order to
[Common Objective], we must [Need]" — flowing left-to-right from Common
Objective to Conflict. Multiple necessary inputs are implicitly AND; OR is
explicit.

**Node types**
- `CommonObjective` — the shared objective valid for both sides
- `Need` — a perceived need that must be met
- `Want` — a perceived want derived from a need
- `Conflict` — the conflict as mutually exclusive wants (lightning-bolt icon, no text)
- `OrJunctor` — alternative necessary inputs, any one of which suffices (icon: OR circle)
- `Assumption` — an underlying assumption behind the conflict
- `Solution` — the solution that breaks the conflict

**Edge types** — necessary-condition relationships flowing left-to-right from the
shared objective through needs and wants to the conflict.
- From the objective: `objective_to_need`, `objective_to_or`
- From a need: `need_to_want`, `need_to_or`, `need_to_assumption`, `need_to_solution`
- From a want: `want_to_conflict`, `want_to_or`, `want_to_assumption`
- From the conflict: `conflict_to_or`, `conflict_to_assumption`
- From an OrJunctor: `or_to_want`, `or_to_conflict`, `or_to_or`

A conflict resolution graph showing how assumptions behind a conflict can be
surfaced and resolved:

```vgl
vgraph projectConflict: EC "Project Delivery vs Quality" {
    // The shared objective both sides agree on
    node obj: CommonObjective "Deliver a successful software product";

    // The two competing needs
    node needA: Need "Meet the market window deadline";
    node needB: Need "Ensure product quality and reliability";

    // The specific wants derived from each need
    node wantA: Want "Release with current feature set now";
    node wantB: Want "Extend timeline for thorough testing";

    // The conflict between the two wants
    node conf: Conflict;

    // Assumptions underlying the conflict
    node assA: Assumption "Testing always requires calendar time";
    node assB: Assumption "Features cannot be descoped";
    node assC: Assumption "Quality requires full manual testing";

    // Solution that breaks the conflict
    node sol: Solution "Implement automated testing pipeline";

    // Objective requires both needs (necessary condition)
    edge obj -> needA: objective_to_need;
    edge obj -> needB: objective_to_need;

    // Needs lead to wants
    edge needA -> wantA: need_to_want;
    edge needB -> wantB: need_to_want;

    // Wants create the conflict
    edge wantA -> conf: want_to_conflict;
    edge wantB -> conf: want_to_conflict;

    // Assumptions exposed
    edge needA -> assA: need_to_assumption;
    edge needB -> assC: need_to_assumption;
    edge conf -> assB: conflict_to_assumption;

    // Solution resolves by breaking assumption
    edge needB -> sol: need_to_solution;
}
```

### Goal Tree

Strategic planning with Theory of Constraints necessity logic (H. William
Dettmer's Logical Thinking Process). The Goal Tree defines what an organization
must achieve through a hierarchy of a single Goal, Critical Success Factors
(CSFs), and Necessary Conditions (NCs). Height says nothing about importance:
if the lowest NC fails, nothing above it happens. NCs may cross-connect between
branches.

**Node types**
- `Goal` — the single top-level objective the system exists for
- `CriticalSuccessFactor` — high-level terminal outcomes, 3–5 maximum, without
  which the Goal cannot be achieved
- `NecessaryCondition` — indispensable prerequisite tasks supporting CSFs, which
  can cascade into more specific sub-conditions

**Edge types** — flowing top-to-bottom, each edge reading "in order to achieve
[upper], we must have [lower]".
- `csf_to_goal` — CriticalSuccessFactor → Goal
- `nc_to_csf` — NecessaryCondition → CriticalSuccessFactor
- `nc_to_nc` — a sub-condition supporting its parent

```vgl
vgraph companyStrategy: GoalTree "Increase Profitability" {
    // The single system goal
    node goal: Goal "Make more money, now and in the future";

    // Critical Success Factors (3-5 high-level terminal outcomes)
    node csf1: CriticalSuccessFactor "Maximize Throughput";
    node csf2: CriticalSuccessFactor "Control Operating Expense";
    node csf3: CriticalSuccessFactor "Minimize Inventory and Investment";

    // Necessary Conditions supporting CSF1
    node nc1: NecessaryCondition "Maximize sales volume";
    node nc2: NecessaryCondition "Minimize variable costs";
    node nc3: NecessaryCondition "Highly appealing products";

    // Necessary Conditions supporting CSF2
    node nc4: NecessaryCondition "Minimize scrap and rework";
    node nc5: NecessaryCondition "Optimize overhead";

    // Necessary Conditions supporting CSF3
    node nc6: NecessaryCondition "Optimize outgoing supply chain";
    node nc7: NecessaryCondition "Optimize incoming supply chain";

    // Sub-NCs becoming more specific
    node nc8: NecessaryCondition "Effective market research";
    node nc9: NecessaryCondition "High-quality products";

    // CSFs support the Goal (necessity logic: "In order to achieve Goal, we must achieve CSFs")
    edge csf1 -> goal: csf_to_goal;
    edge csf2 -> goal: csf_to_goal;
    edge csf3 -> goal: csf_to_goal;

    // NCs support CSFs
    edge nc1 -> csf1: nc_to_csf;
    edge nc2 -> csf1: nc_to_csf;
    edge nc3 -> csf1: nc_to_csf;
    edge nc4 -> csf2: nc_to_csf;
    edge nc5 -> csf2: nc_to_csf;
    edge nc6 -> csf3: nc_to_csf;
    edge nc7 -> csf3: nc_to_csf;

    // Sub-NCs support higher NCs
    edge nc8 -> nc1: nc_to_nc;
    edge nc9 -> nc3: nc_to_nc;
}
```

### Attack-Defense Tree (ADTree)

Security modelling after Kordy et al. (2014), extending classical attack trees
with defense nodes at any level. Sufficient-cause logic: unjoined children are
implicitly OR. The root can be an Attack or a Defense, which decides whether the
proponent is the attacker or the defender.

**Node types**
- `Attack` — an attacker's goal or sub-goal
- `Defense` — a defender's countermeasure
- `AndJunctor` — conjunctive refinement: all children required together

**Edge types** — the tree reads top to bottom from the root goal. Refinement
edges (same type) are drawn solid, countermeasure edges (opposite type) dotted.
- `attack_refines_attack` — decompose an attack into sub-attacks
- `defense_refines_defense` — decompose a defense into sub-defenses
- `defense_counters_attack` — a defense mitigating an attack
- `attack_counters_defense` — an attack circumventing a defense
- Junctors: `attack_to_and_junctor`, `defense_to_and_junctor`,
  `and_junctor_to_attack`, `and_junctor_to_defense`

A security modelling graph showing how defenses protect a system and how attacks
can circumvent them. Based on the data confidentiality scenario from Kordy et
al. (2014):

```vgl
vgraph dataConfidentiality: ADTree "Data Confidentiality" {
    // Defense nodes (defender's goals)
    node dataConf: Defense "Data Confidentiality";
    node networkSec: Defense "Network Security";
    node physicalSec: Defense "Physical Security";
    node accessControl: Defense "Access Control";
    node passwords: Defense "Passwords";
    node strongPasswords: Defense "Strong Passwords";
    node lock1: Defense "Lock";
    node screening: Defense "Screening";
    node securityGuard: Defense "Security Guard";
    node videoCameras: Defense "Video Cameras";

    // Attack nodes (attacker's goals)
    node employeeAttack: Attack "Employee Attack";
    node breakIn: Attack "Break In";
    node corruption: Attack "Corruption";
    node socialEngineering: Attack "Social Engineering";
    node dictionaryAttack: Attack "Dictionary Attack";
    node backDoor: Attack "Back Door";
    node defeatLock: Attack "Defeat Lock";
    node forceOpen: Attack "Force Open";
    node acquireKeys: Attack "Acquire Keys";
    node defeatGuard: Attack "Defeat Guard";
    node bribe: Attack "Bribe";
    node overpower: Attack "Overpower";
    node stealKeys: Attack "Steal Keys";
    node outnumber: Attack "Outnumber";
    node useWeapons: Attack "Use Weapons";

    // AND junctors for conjunctive refinement
    node andDataConf: AndJunctor;
    node andOverpower: AndJunctor;

    // Defense refines into sub-defenses via AND junctor (both required)
    edge networkSec -> andDataConf: defense_to_and_junctor;
    edge physicalSec -> andDataConf: defense_to_and_junctor;
    edge andDataConf -> dataConf: and_junctor_to_defense;
    edge accessControl -> networkSec: defense_refines_defense;
    edge passwords -> accessControl: defense_refines_defense;

    // Attack refines into sub-attacks (solid edges)
    edge corruption -> employeeAttack: attack_refines_attack;
    edge socialEngineering -> employeeAttack: attack_refines_attack;
    edge backDoor -> breakIn: attack_refines_attack;
    edge forceOpen -> defeatLock: attack_refines_attack;
    edge acquireKeys -> defeatLock: attack_refines_attack;
    edge bribe -> defeatGuard: attack_refines_attack;
    edge overpower -> defeatGuard: attack_refines_attack;
    edge stealKeys -> defeatGuard: attack_refines_attack;

    // Countermeasure: defense counters attack (dotted edges)
    edge strongPasswords -> dictionaryAttack: defense_counters_attack;
    edge lock1 -> backDoor: defense_counters_attack;
    edge screening -> corruption: defense_counters_attack;
    edge securityGuard -> breakIn: defense_counters_attack;
    edge videoCameras -> defeatGuard: defense_counters_attack;

    // Countermeasure: attack counters defense (dotted edges)
    edge employeeAttack -> dataConf: attack_counters_defense;
    edge breakIn -> physicalSec: attack_counters_defense;
    edge dictionaryAttack -> passwords: attack_counters_defense;
    edge defeatLock -> lock1: attack_counters_defense;
    edge defeatGuard -> securityGuard: attack_counters_defense;

    // AND junctor: conjunctive refinement
    edge outnumber -> andOverpower: attack_to_and_junctor;
    edge useWeapons -> andOverpower: attack_to_and_junctor;
    edge andOverpower -> overpower: and_junctor_to_attack;
}
```

The editor's *ADTree — Data Confidentiality* is the full Kordy tree, with
firewalls, sensitivity training, a fire-escape break-in route and a
strong-password attack subtree — and it leaves every edge type to inference.

### Causal Loop Diagram (CLD)

Systems analysis: what reinforces or balances what over time. Every element is a
Stock whose amount changes according to its incoming connections.

**Node types**
- `Stock` — a variable whose value changes over time

**Edge types** — a loop with an even number of `opposite` links (including zero)
is reinforcing (growth or decline); an odd number makes it balancing (towards
equilibrium).
- `same` — Stock → Stock, a positive causal link: both change in the same
  direction (solid, marked "+")
- `opposite` — Stock → Stock, a negative causal link: they change in opposite
  directions (dashed, marked "−")

A systems analysis diagram modelling population dynamics with reinforcing and
balancing feedback loops:

```vgl
vgraph populationCLD: CLD "Population Dynamics" {
    node births: Stock "Births";
    node population: Stock "Population";
    node deaths: Stock "Deaths";
    node foodSupply: Stock "Food Supply";
    node crowding: Stock "Crowding";

    // Reinforcing loop: more births increase population, larger population increases births
    edge births -> population: same;
    edge population -> births: same;

    // Balancing loop: population increases deaths, deaths decrease population
    edge population -> deaths: same;
    edge deaths -> population: opposite;

    // Balancing loop: population reduces food supply, less food reduces births
    edge population -> foodSupply: opposite;
    edge foodSupply -> births: same;

    // Crowding effects
    edge population -> crowding: same;
    edge crowding -> deaths: same;
}
```

### Decision Tree

Decision logic as questions, choices and outcomes, read top to bottom.

**Node types**
- `DecisionPoint` — a question determining which path to follow
- `Choice` — a potential answer branching from a question
- `Outcome` — a terminal result

**Edge types**
- `decision_to_choice` — DecisionPoint → Choice (the question branches)
- `choice_to_decision` — Choice → DecisionPoint (the option leads to a further question)
- `choice_to_outcome` — Choice → Outcome (the option terminates)

A decision logic graph for a hiring process showing how a series of questions
leads to distinct outcomes:

```vgl
vgraph hiringDecision: DecisionTree "Should We Hire This Candidate?" {
    // Opening decision point
    node q1: DecisionPoint "Is the candidate technically qualified?";
    node c1: Choice "Yes";
    node c2: Choice "No";

    // Follow-up question for qualified candidates
    node q2: DecisionPoint "Does the candidate fit the team culture?";
    node c3: Choice "Yes";
    node c4: Choice "No";

    // Terminal outcomes
    node o1: Outcome "Extend offer";
    node o2: Outcome "Reject — technical skills insufficient";
    node o3: Outcome "Reject — poor cultural fit";

    // Branch from first question
    edge q1 -> c1: decision_to_choice;
    edge q1 -> c2: decision_to_choice;

    // Path for unqualified candidate leads directly to outcome
    edge c2 -> o2: choice_to_outcome;

    // Qualified candidates proceed to culture question
    edge c1 -> q2: choice_to_decision;
    edge q2 -> c3: decision_to_choice;
    edge q2 -> c4: decision_to_choice;

    // Final outcomes
    edge c3 -> o1: choice_to_outcome;
    edge c4 -> o3: choice_to_outcome;
}
```

### Timeline

Events across multiple tracks on a shared time axis, aligned by column.

**Node types**
- `TimePoint` — a coordinate on the time axis, rendered as an anchor dot on a
  horizontal baseline with the year centred below it, and a dashed vertical guide
  descending through the diagram to anchor Events sharing its `alignGroup`.
  TimePoints are **not** drawn as boxed nodes.
- `Event` — a thing that happened at a point in time (boxed). Use `alignGroup` to pin it to a TimePoint's column.

**Edge types**
- `sequence` — TimePoint → TimePoint. Used by Graphviz for rank ordering but
  **not drawn**: the overlay's horizontal baseline replaces the arrows visually.
- `influence` — Event → Event, a cross-track or within-track dependency (dashed,
  `constraint=false`). Drawn normally.

```vgl
vgraph myTimeline: Timeline "19th Century Europe" {
    // Time axis
    node t1800: TimePoint "1800" [alignGroup: "1800"]
    node t1850: TimePoint "1850" [alignGroup: "1850"]
    node t1871: TimePoint "1871" [alignGroup: "1871"]
    edge t1800 -> t1850: sequence
    edge t1850 -> t1871: sequence

    group germany "Germany" {
        node g1: Event "Napoleon defeats Prussia" [alignGroup: "1800"]
        node g2: Event "German Unification" [alignGroup: "1871"]
    }

    group england "England" {
        node e1: Event "Industrial Revolution peaks" [alignGroup: "1850"]
        node e2: Event "Franco-Prussian War impact" [alignGroup: "1871"]
    }

    edge g1 -> g2: influence "led to"
    edge e1 -> g2: influence "industrialization enabled"
}
```

Timelines flow left to right, and groups become visual tracks. `alignGroup` is
what puts nodes in the same column — TimePoints are optional, and `alignGroup`
alone suffices for alignment.

Each TimePoint renders as a filled dot on a horizontal baseline with its label
centred below, and a dashed vertical guide descends through the diagram so a
reader can trace from a year down to every Event in that column. The `sequence`
arrows are suppressed, because the baseline already conveys order. A
`vnotation … extends Timeline` inherits this rendering.

### C4

Software-architecture diagrams in Simon Brown's C4 model: people, software
systems, containers, components and code, across four levels of zoom.

**Node types.** `Person`, `SoftwareSystem`, `Container`, `Database` (a container
drawn as a cylinder), `Component` and `CodeElement`. A C4 "container" is a
separately deployable unit — an app, service or datastore — **not** the box
drawn around things.

**Zoom is detailing.** A Software System is detailed by Containers and
Databases, a Container by Components, a Component by Code Elements. Write the
element as a group of its node type, `group ibs: SoftwareSystem "…" { … }`: folded
it is the element's card, unfolded the dashed boundary around its details.
Being external is not a type; colour such a system per node with
`backgroundColor`.

**Relationships** are labelled with how the elements collaborate. There is one
type per level — `interacts_with` (Person → Person), `uses` (Person → Software
System), `delivers_to` (Software System → Person), `depends_on` (Software System
→ Software System), `communicates_with` (Container → Container),
`reads_and_writes` (Container → Database), `calls` (Component → Component) and
`references` (Code Element → Code Element) — and each also holds with one end
replaced by a detail at any depth, so a Person may use a Container and a
Component may depend on a Software System. No pair is ambiguous, so a file never
names a C4 edge type.

Edges join elements, never boundaries: a detailed element's relationships start
at its details, and folding it gathers them onto its card (`×3` when three
meet). A label written for the system as a whole has no place to go, and neither
do C4's descriptions and technologies yet.

**Organisations** are plain groups, `group bank: Organisation "Big Bank" { … }`.

```vgl
vgraph banking: C4 "Internet Banking System" {
    node customer: Person "Personal Banking Customer";
    node cbs: SoftwareSystem "Core Banking System" [backgroundColor: "#e8710a"];

    group ibs: SoftwareSystem "Internet Banking System" {
        isfolded: false;
        node ui: Container "UI";
        node backend: Container "Backend";
        node database: Database "Database";
    };

    edge customer -> ui "Views account balances and makes payments using";
    edge ui -> backend "Makes API requests to";
    edge backend -> database "Reads from and writes to";
    edge backend -> cbs "Makes API requests to";
}

vview context "System Context View: Internet Banking System" {
    folded node type: SoftwareSystem;
}
```

The editor's *C4 — Internet Banking System* is c4model.com's current example,
modelled down to the code, with one view per diagram there: System Landscape,
System Context, Container, Component (Backend) and Code (Core Banking System
Adapter). The same file is
[`docs/examples/c4-internet-banking-views.vgl`](examples/c4-internet-banking-views.vgl);
[`docs/examples/c4-internet-banking.vgl`](examples/c4-internet-banking.vgl) is its
Container View on its own.

### Arithmetic

Simple equations as diagrams, built for a kids' maths game: numbers, the four
operators, and an `Equals` node that checks them. Deliberately small — no
chaining of operators and no variables.

**Node types**
- `Number` — a value, given or filled in as a candidate answer
- `Plus`, `Minus`, `Times`, `Divide` — takes two operands and produces a result
- `Equals` — asserts that everything connected to it, plus its own label if it
  has one, shares one value. Green and showing the value when they agree, red
  and showing what is wrong when they don't, neutral while incomplete.

**Edge types** — for each operator, a first operand, a second operand and a
result: `plus_first_operand`, `plus_second_operand` (Number → Plus) and
`plus_result` (Plus → Equals), and likewise `minus_…`, `times_…` and
`divide_…`. Both operand edges join the same pair of types, so these are always
named. More than one of each on an operator is an error.

```vgl
vgraph arithmeticRightAndWrong: Arithmetic "Right and Wrong" {
    node two: Number "2";
    node five: Number "5";
    node three: Number "3";
    node four: Number "4";

    node plusOp: Plus;
    node timesOp: Times;

    // Each Equals carries the expected answer as its label.
    node eqPlus: Equals "7";
    node eqTimes: Equals "11";

    // 2 + 5 = 7 — correct, shows "= 7" in green
    edge two -> plusOp: plus_first_operand;
    edge five -> plusOp: plus_second_operand;
    edge plusOp -> eqPlus: plus_result;

    // 3 × 4 is 12, but 11 was expected — shows "12 ≠ 11" in red
    edge three -> timesOp: times_first_operand;
    edge four -> timesOp: times_second_operand;
    edge timesOp -> eqTimes: times_result;
}
```

The editor's *Arithmetic — Right and Wrong* adds subtraction and division.

## User-defined notations (`vnotation`)

`vnotation` defines a notation schema inline in a VGL file, with no Swift
changes. Everything a built-in notation provides — node types, edge types,
layout direction — can be expressed this way.

```
vnotation <Name> [extends <BuiltinNotation>] {
    layout: <topToBottom | leftToRight | rightToLeft | bottomToTop>

    icon      <IconName>   [viewBox: "<minX minY width height>", path: "<svg path data>"]
    node type: <TypeName>  [nodeStyle: <name>, backgroundColor: "#hex", icon: "<IconName>", ...]
    edge type: <edge_id>   from: <TypeName>  to: <TypeName>  [color: "#hex"]
    group type: <GroupTypeName> [boundaryDash: "8,4", boundaryColor: "#hex", ...]
}
```

`group type:` names a kind of plain group, so `group g: <GroupTypeName> { … }`
is accepted and `group type:` view rules can select it.

**Boundary look.** `node type:` and `group type:` both take four keys for the
boundary an unfolded group draws: `boundaryDash` (an SVG dash pattern, `""` for
a solid line), `boundaryColor`, `boundaryFill` (hex, `#rrggbbaa` for
transparency) and `boundaryRadius`. On a node type it is the boundary of its
detailed nodes; on a group type, of its groups. A key left out keeps the look
the type already had, so `group type: Organisation [boundaryColor: "#00aa00"]`
in a block extending C4 recolours the boundary and keeps its dashes. A type with
no boundary of its own, from the block or the notation it extends, draws the
generic cluster. These are the only keys `group type:` takes; a group type
declared in a `vnotation` folds into the generic folded box.

A `vgraph` then references it by name exactly like a built-in notation.
**`vnotation` blocks must appear before any `vgraph` or `metagraph` that
references them**, which allows single-pass parsing.

`backgroundColor:` is the fill. `color:` is accepted as an older spelling of it
on input, but `backgroundColor` is what a document exports — the same name a node
instance stores it under, so the two surfaces agree.

`qualityCheck: <name>` adds a [quality check](#quality-checks) by name — a graph
criterion such as `noParallelEdges`; an unknown name is refused with the list of
available ones. `transform: <name>` adds a step that rewrites the graph before
layout — `mergeRelations`, say, which merges Concept Map relations — refused the
same way when unknown.

### `nodeStyle:` — required on every node type

The parser treats the value as an opaque string; the semantic layer validates it
against this table.

| `nodeStyle:` | Additional parameters | Description |
|---|---|---|
| `iconWithText` | `backgroundColor:` (required), `icon:`, `iconColor:` (default white), `iconSize:` (default 24) | Icon above text, coloured background |
| `simpleRoundedText` | `backgroundColor:` | Text in a rounded rectangle |
| `simpleRoundedBox` | `backgroundColor:` | Plain rounded box (`roundedBox` is accepted as an older spelling) |
| `withCategory` | `backgroundColor:`, `category:` (short header label) | Box with a coloured category bar on top |
| `withCategoryAndIcon` | `backgroundColor:`, `category:`, `icon:`, `iconColor:`, `iconSize:` | Category bar plus icon |
| `iconOnly` | `icon:`, `iconColor:` (default black), `iconSize:` | Icon without text |
| `circle` | `backgroundColor:` | Circular node |
| `bareText` | — | Plain text, no decoration |
| `hidden` | — | Not rendered |
| `custom` | — | Falls back to `bareText`; reserved for future style expressions |

### `icon` — artwork of your own

`icon:` on a node type names an icon. A set of names is built into VGraph; a
`vnotation` can add its own, so a notation is not limited to the icons that
happened to ship.

```vgl
vnotation RiskMap {
    icon shield [viewBox: "0 0 24 24", path: "M12 1 3 5v6c0 5.5 3.8 10.7 9 12 5.2-1.3 9-6.5 9-12V5z"]

    node type: Control [nodeStyle: iconWithText, backgroundColor: "#339933", icon: "shield"]
}
```

The artwork travels **inside the document**, so it draws wherever VGL draws —
website, both plugins, the CLI — with nothing to fetch and no cooperation from
the host.

- **`viewBox:` and `path:` are both required.** The viewBox is four numbers, as
  in an SVG file; there is no default, because artwork drawn at a guessed scale
  is worse than a document that says what is wrong.
- **One shape, not a picture.** One path, no colours of its own: `iconColor:` fills
  it at the point of use, which is what makes the same icon work in white on a
  dark node and in black on a light one.
- **`path:` takes SVG path data and only that** — the path commands, digits,
  `.,+-eE` and spaces, up to 4096 characters. Anything else is refused where it
  is written.
- **Your name wins.** A name resolves against the notation's own artwork first
  and the built-in set second, so declaring `and` yourself replaces it
  for that document — and an icon added to VGraph in some later release can never
  change how your document looks.
- **A name nobody has is not fatal.** It draws a placeholder and is reported in
  the quality report, naming the node type and the icon. The rest of the diagram
  is untouched.

Forty-eight icon names are built in, all drawn for VGraph; the design system's
Icons section holds the masters. A name says what the icon means, and several
names share one drawing, so `need`, `answer` and `undesirable-effect` look alike.

| Used for | Names |
|---|---|
| Whole node, with its own circle | `and`, `or` (the junctors), `conflict`, `default` (drawn when an icon style names no icon) |
| Reality trees | `undesirable-effect`, `intermediate-effect`, `desirable-effect`, `given`, `changeable` |
| Questions and decisions | `question`, `answer`, `pro`, `con`, `decision-point`, `choice`, `outcome`, `assumption` |
| Goals and obstacles | `goal`, `objective`, `intermediate-objective`, `common-objective`, `investment-objective`, `critical-success-factor`, `necessary-condition`, `obstacle`, `need`, `want`, `solution` |
| Change and delivery | `benefit`, `business-change`, `enabler`, `impact`, `actor`, `deliverable`, `event` |
| Attack and defence | `attack`, `defense` |
| General | `concept`, `variable`, `annotation`, `warning` |
| Arithmetic | `plus`, `minus`, `times`, `divide`, `equals`, `not-equal` |
| Brand | `vithanco` (the logo) |

Anything else a document draws, it declares. The SF Symbols-style names and the
desktop app's icons that earlier versions shipped draw the placeholder until a
`vnotation` declares them.

### `extends`

Adds every node and edge type from a built-in notation, on top of which yours
adds more:

```vgl
vnotation RichIBIS extends IBIS {
    node type: Stakeholder [nodeStyle: withCategory, backgroundColor: "#884499", category: "S"]

    edge type: stakeholder_raises  from: Stakeholder to: Question
    edge type: stakeholder_answers from: Stakeholder to: Answer
}
```

Only **built-in** notations can be extended — `vnotation A extends B` where B is
itself a vnotation is not supported.

### `detailedBy:` — a hierarchical notation

A node type can name the types its nodes are detailed by, the way a software
system is made of containers and databases:

```vgl
vnotation Architecture {
    node type: System    [nodeStyle: withCategory, backgroundColor: "#1168bd", detailedBy: (Container, Database)]
    node type: Container [nodeStyle: withCategory, backgroundColor: "#438dd5"]
    node type: Database  [nodeStyle: withCategory, backgroundColor: "#438dd5"]
}
```

- Every name in the list must be a node type of the notation.
- One type may be a detail type of several types.
- A type may be detailed by itself, for sub-processes or work packages. Any
  longer cycle is an error: no type could then stand at the top level.
- With `extends`, the list **adds** to what the built-in notation already says
  for that type. Detailings cannot be removed, so no document that relied on one
  becomes invalid. A saved file writes back only the ones the `vnotation` added.
- A name cannot be both a node type and a group type, since `group x: Name`
  would not say which it is.

The quality report then warns, for any notation with detailings, about a node
inside a detailed node that its type is not detailed by, and about a detail type
at the top level unless it details itself. Plain groups in between do not count.

### A complete example

```vgl
vnotation RiskMap {
    layout: topToBottom

    icon risk   [viewBox: "0 0 24 24", path: "M12 2 22.5 21h-21zM11 9v6h2V9zm0 8v2h2v-2z"]
    icon shield [viewBox: "0 0 24 24", path: "M12 1 3 5v6c0 5.5 3.8 10.7 9 12 5.2-1.3 9-6.5 9-12V5z"]

    node type: Risk    [nodeStyle: iconWithText, backgroundColor: "#cc3333", icon: "risk"]
    node type: Control [nodeStyle: iconWithText, backgroundColor: "#339933", icon: "shield"]
    node type: Owner   [nodeStyle: circle,       backgroundColor: "#3366cc"]

    edge type: risk_has_control  from: Risk    to: Control
    edge type: control_owned_by  from: Control to: Owner
}

vgraph rm1: RiskMap "Project Risk Map" {
    node r1: Risk    "Schedule overrun"
    node c1: Control "Weekly reviews"
    node o1: Owner   "PM"
    edge r1 -> c1
    edge c1 -> o1
}
```

A vnotation can take extensions like any other notation:
`vgraph sm1: SimpleMap, Annotation "Annotated Map" { … }`.

## Metagraph (visualising a notation)

A notation *is* a graph — its node types are vertices and its edge types are
edges — so it can be drawn directly. That is useful for documentation, for
teaching, and for seeing how a `vnotation` you just wrote will actually look.

```
metagraph <NotationName> ["<optional_label>"]
```

No id and no body. The label defaults to `"<NotationName> Meta Model"`. A file
contains either one `vgraph` or one `metagraph`, never both, and `vnotation`
blocks may precede a `metagraph` — so you can declare and visualise a custom
notation in one file. `metadescription <NotationName>` takes the same form and
adds the notation's self-description in Markdown alongside the diagram.

Each node is styled **exactly** as it would appear in a real diagram, which is
what makes the metagraph self-documenting. A [detailing](#detailedby--a-hierarchical-notation)
is drawn as a dashed `detailed by` edge from the type to each of its detail types.

```vgl
metagraph Timeline
```

```vgl
vnotation MyNotation extends ConceptMap {
    node type: Hypothesis [nodeStyle: iconWithText]
    edge type: supports from: Hypothesis to: Concept
}
metagraph MyNotation
```

## Grammar

Simplified BNF:

```
file         ::= vnotation* (document | metagraph) view*

view         ::= "vview" identifier label? attributes? "{" (view_rule | view_statement)* "}"

view_rule    ::= ("include" | "exclude") selector ";"?
               | "expand" number ";"?

selector     ::= ("*" | ("node" | "group") ("type" ":")? identifier ("," identifier)*) reach?

reach        ::= "+" number | "downstream" number | "upstream" number

view_statement ::= "folded"? ("node" | "group") ("type" ":")? identifier ("," identifier)*
                   attributes? ";"?

document     ::= "vgraph" identifier ":" notation ("," extension)* label? "{" statement* "}"

metagraph    ::= ("metagraph" | "metadescription") notation label? ";"?

notation     ::= identifier
                 // a built-in notation, or a vnotation declared earlier in the file

vnotation    ::= "vnotation" identifier ("extends" identifier)? "{" vnotation_body* "}"

vnotation_body ::= ("layout" ":" layout_dir ";"?)
                 | ("icon" identifier "[" "viewBox" ":" quoted_string ","?
                                          "path" ":" quoted_string "]" ";"?)
                 | ("node" "type" ":" identifier type_attributes? ";"?)
                 | ("edge" "type" ":" identifier "from" ":" identifier "to" ":" identifier attributes? ";"?)
                 | ("group" "type" ":" identifier attributes? ";"?)
                 | ("qualityCheck" ":" identifier ("(" value ("," value)* ")")? ";"?)
                 | ("transform" ":" identifier ";"?)
                 | attribute

type_attributes ::= "[" ((attribute | detailed_by) (";" | ",")?)* "]"

detailed_by  ::= "detailedBy" ":" "(" identifier ("," identifier)* ")"

layout_dir   ::= "topToBottom" | "leftToRight" | "bottomToTop" | "rightToLeft"

extension    ::= identifier            // available: Annotation

statement    ::= group | node | edge | attribute

group        ::= "folded"? "group" identifier (":" identifier)? label? "{" statement* "}" ";"?
                 // the type is a group type, or a node type for a detailed node

node         ::= "node" identifier ":" identifier label? attributes? ";"?

edge         ::= "edge" identifier "->" identifier (":" identifier)? label? attributes? ";"?

attribute    ::= identifier ":" value ";"?

attributes   ::= "[" (attribute (";" | ",")?)* "]"

label        ::= quoted_string

value        ::= quoted_string | number | identifier

identifier   ::= [a-zA-Z_][a-zA-Z0-9_.\-]*

number       ::= [-]?[0-9]+(\.[0-9]+)?

quoted_string::= "\"" ([^\"\\] | "\\" .)* "\""

comment      ::= "//" [^\n]*
```

Rules worth stating separately:

- Node ids must be unique throughout the document, and an edge may only
  reference nodes already declared.
- Semicolons are optional after nodes, edges, groups and standalone attributes.
- A node or edge type that is not valid for the notation is not an error: it
  becomes an **unknown** type, rendered bold red and reported as a quality
  warning, so a document always opens. Check the spelling.

## Best practices

Choose descriptive ids (`security_question`, not `n1`) and name them
consistently. Let edge types be inferred. Use groups to reflect the domain's
real hierarchy, and comments to explain the relationships that are not obvious.
Start minimal and add attributes only where they earn their place.
