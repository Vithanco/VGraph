// Minimal valid VGL fixtures, one per built-in notation + one `vnotation extends` fixture.
// Each fixture exercises the parser + notation registration + DOT export pipeline.
// Used by smoke.test.js to verify the WASM module's wire surface (the 4 layout-free
// @JS functions: convertToDot, dotForLayout, debugGraph, exportToVGL).
//
// Node-type strings here are taken from each notation file's *Id constants
// (e.g. Sources/VGraph/Core/Domain/Notations/IBIS.swift -> questionId = "Question").

export const fixtures = {
  IBIS: `vgraph t: IBIS "Smoke" {
    node n1: Question "Q?";
    node n2: Answer "A";
  }`,
  BBS: `vgraph t: BBS "Smoke" {
    node n1: InvestmentObjective "Objective 1";
    node n2: InvestmentObjective "Objective 2";
  }`,
  ImpactMapping: `vgraph t: ImpactMapping "Smoke" {
    node n1: Goal "Goal 1";
    node n2: Goal "Goal 2";
  }`,
  ConceptMap: `vgraph t: ConceptMap "Smoke" {
    node n1: Concept "Concept 1";
    node n2: Concept "Concept 2";
  }`,
  CRT: `vgraph t: CRT "Smoke" {
    node n1: UndesirableEffect "UDE 1";
    node n2: UndesirableEffect "UDE 2";
  }`,
  EC: `vgraph t: EC "Smoke" {
    node n1: CommonObjective "Objective";
    node n2: CommonObjective "Objective 2";
  }`,
  FRT: `vgraph t: FRT "Smoke" {
    node n1: UndesirableEffect "UDE 1";
    node n2: UndesirableEffect "UDE 2";
  }`,
  PRT: `vgraph t: PRT "Smoke" {
    node n1: Objective "Objective 1";
    node n2: Objective "Objective 2";
  }`,
  TRT: `vgraph t: TRT "Smoke" {
    node n1: UndesirableEffect "UDE 1";
    node n2: UndesirableEffect "UDE 2";
  }`,
  ADTree: `vgraph t: ADTree "Smoke" {
    node n1: Attack "Attack 1";
    node n2: Attack "Attack 2";
  }`,
  GoalTree: `vgraph t: GoalTree "Smoke" {
    node n1: Goal "Goal 1";
    node n2: Goal "Goal 2";
  }`,
  CLD: `vgraph t: CLD "Smoke" {
    node n1: Stock "Stock 1";
    node n2: Stock "Stock 2";
  }`,
  DecisionTree: `vgraph t: DecisionTree "Smoke" {
    node n1: DecisionPoint "Decision 1";
    node n2: DecisionPoint "Decision 2";
  }`,
  Timeline: `vgraph t: Timeline "Smoke" {
    node n1: TimePoint "1900";
    node n2: TimePoint "2000";
  }`,
};

// vnotation extends: dynamic-notation path (guard for the closure-registry refactor).
// A user-defined notation that extends ConceptMap and adds a Hypothesis node type.
export const dynamicNotationFixture = `vnotation MyNotation extends ConceptMap {
    node type: Hypothesis [nodeStyle: iconWithText]
    edge type: supports from: Hypothesis to: Concept
}

vgraph t: MyNotation "Dynamic smoke" {
    node n1: Concept "C";
    node n2: Hypothesis "H";
}`;

// Two views over one model: the default view plus `first` and `second`.
export const viewsFixture = `vgraph t: ConceptMap "Views" {
    node n1: Concept "C1";
    node n2: Concept "C2";
    edge n1 -> n2;
}

vview first "First View" {
    node n1 [fontsize: 16];
}

vview second "Second View" {
    node n1 [fontsize: 20];
}`;
