# 28. Loops are found over nodes, shortest first, and capped

Date: 2026-09-26

## Status

Accepted. Loop markers read the OriginGraph ([0027](./0027-judge-the-origin-graph-present-the-display-graph.md));
this decides how the loops are found. *Revised 2026-09-26* with the `loopMarkers`
choice below, after [the research](../research/cld-loop-selection.md).

## Context

Loop detection enumerated cycles of *edges*, breadth first (Liu & Wang, 2006, via
SwiftGraph). Two ways it could stop a render:

- **Parallel edges multiply.** A loop drawn with two links on each of *k* steps is
  2^*k* edge cycles that all visit the same nodes. A ring with fifty doubled steps
  is 2^50 of them.
- **Dead ends cost as much as loops.** Every path grows until it closes or runs
  out, so a single ring of 400 nodes took over half a second for its one loop.

And some diagrams simply have too many loops: counting a directed graph's simple
cycles is #P-hard, and a dense one has more than any renderer can list. Every tool
that marks loops has to choose which to show.

## Decision

- **A loop is a cycle of nodes.** Each step keeps every edge that realises it, so
  parallel edges yield one loop, not one per combination.
- **Johnson's algorithm** (1975) finds them: its work is proportional to the loops
  it reports, with no exploration of paths that never close.
- **Shortest first, under a cap.** Loops are returned shortest first. If the
  search exceeds its budget, it gives up on completeness and returns the shortest
  loops instead, found breadth first, and says the list is incomplete; a Causal
  Loop Diagram reports that as a warning. The tightest loops are the most readable
  ones, and a truncated list of them is an honest selection where the first few
  found by a depth-first search would be an accidental one.
- **A step whose links pull both ways makes the loop's polarity unknown.** The
  marker shows "?" and names the link, instead of guessing R or B — and the
  document already reports that link through `noParallelEdges`.
- **The author chooses what is marked**, with the graph attribute `loopMarkers`:
  `all` (the default, as above), `independent` or `none`. `independent` marks a set
  that together covers every feedback link, shortest where possible: from the loops
  found, shortest first, it keeps taking the one adding the *fewest* uncovered
  links, as Oliva's selection does, until every link on a loop is covered. It is
  offered, never switched to: it can leave unmarked a loop the author drew, and it
  is not "the important loops" — in Eberlein & Schoenberg's arms-race example an
  independent set drops the two loops that drive long-run behaviour. It claims to
  cover every link, not to reach E − V + 1 loops, which Oliva's own procedure
  misses on dense graphs (Huang et al. 2012). `none` marks nothing, as Kumu does
  until a loop is named.

## Considered options

- **Cap only, keeping edge cycles.** Stops the hang, and still spends the whole
  budget on the parallel-edge duplicates of one loop.
- **Show the Shortest Independent Loop Set** (Oliva, 2004) as the default, or as
  the fallback past the cap. Rejected for both: it changes what a marker *means*,
  a loop the author drew could go unmarked, and no tool or paper found uses it to
  decide what a diagram shows — Vensim and Kumu list shortest first and cap, and
  Stella's Loops that Matter rejects independent sets for picking loops. Kept as
  the opt-in `independent`.
- **Show nothing past the cap.** Predictable, and it takes every marker away from
  exactly the diagrams where loops matter most.

## Consequences

- **Which loops a truncated diagram marks depends on the budget**, which is a
  tuning constant, not a property of the diagram.
- **Parallel links no longer double the markers**, which changes what an existing
  diagram with parallel links shows: one marker per loop instead of one per
  combination.
