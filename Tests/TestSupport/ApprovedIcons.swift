// The approved icon set, written out independently of the code under test.

public enum ApprovedIcons {

    /// Each artwork with every icon name that shares it: 30 artworks, 43 names.
    public static let artworks: [String: [String]] = [
        "bang": ["undesirable-effect", "need", "answer"],
        "question": ["question", "decision-point", "assumption"],
        "star": ["desirable-effect", "benefit", "critical-success-factor"],
        "flag": ["goal", "objective", "common-objective"],
        "target": ["investment-objective"],
        "check": ["outcome", "solution"],
        "plus": ["pro", "plus"],
        "minus": ["con", "minus"],
        "cross": ["obstacle", "times"],
        "divide": ["divide"],
        "equals": ["equals"],
        "not-equal": ["not-equal"],
        "cycle": ["changeable"],
        "zigzag": ["impact"],
        "swap": ["business-change"],
        "dot": ["event", "concept"],
        "half": ["intermediate-objective"],
        "heart": ["want"],
        "fork": ["choice"],
        "vee": ["variable"],
        "pencil": ["annotation"],
        "warning": ["warning"],
        "person": ["actor"],
        "box": ["deliverable"],
        "flow": ["intermediate-effect"],
        "anchor": ["given"],
        "key": ["necessary-condition"],
        "gear": ["enabler"],
        "sword": ["attack"],
        "shield": ["defense"],
    ]

    public static var names: Set<String> { Set(artworks.values.flatMap { $0 }) }

    /// Approved and still shipped, but drawn by no built-in notation: CLD's only type,
    /// Stock, has no badge (Style Guide §01). Kept so an author's VGL naming it still resolves.
    public static let unusedByBuiltins: Set<String> = ["variable"]

    /// What was already built in before the approved set.
    public static let existing: Set<String> = ["and", "or", "conflict", "default", "vithanco"]

    /// The icon a built-in notation's node type draws, keyed "Notation.NodeType".
    public static let nodeTypes: [String: String] = [
        "ADTree.Attack": "attack", "ADTree.Defense": "defense",
        "Arithmetic.Plus": "plus", "Arithmetic.Minus": "minus", "Arithmetic.Times": "times",
        "Arithmetic.Divide": "divide", "Arithmetic.Equals": "equals",
        "BBS.Benefit": "benefit", "BBS.BusinessChange": "business-change", "BBS.Enabler": "enabler",
        "BBS.InvestmentObjective": "investment-objective",
        "ConceptMap.Concept": "concept",
        "DecisionTree.Choice": "choice", "DecisionTree.DecisionPoint": "decision-point",
        "DecisionTree.Outcome": "outcome",
        "EC.Assumption": "assumption", "EC.CommonObjective": "common-objective", "EC.Need": "need",
        "EC.Solution": "solution", "EC.Want": "want",
        "GoalTree.CriticalSuccessFactor": "critical-success-factor", "GoalTree.Goal": "goal",
        "GoalTree.NecessaryCondition": "necessary-condition",
        "IBIS.Answer": "answer", "IBIS.Con": "con", "IBIS.Pro": "pro", "IBIS.Question": "question",
        "ImpactMapping.Actor": "actor", "ImpactMapping.Deliverable": "deliverable",
        "ImpactMapping.Goal": "goal", "ImpactMapping.Impact": "impact",
        "PRT.IntermediateObjective": "intermediate-objective", "PRT.Objective": "objective",
        "PRT.Obstacle": "obstacle",
        "Timeline.Event": "event",
    ]
    // Changeable, Given, Intermediate/Desirable/Undesirable Effect are the same in CRT, FRT and TRT.
    public static let reality: [String: String] = [
        "Changeable": "changeable", "Given": "given", "IntermediateEffect": "intermediate-effect",
        "DesirableEffect": "desirable-effect", "UndesirableEffect": "undesirable-effect",
    ]
}
