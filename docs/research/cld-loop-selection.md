# Choosing which loops a CLD marks

Research for ADR-0028 (loops are found over nodes, shortest first, capped) and for
the proposed Shortest Independent Loop Set (SILS) fallback / user option.
Researched 2026-09-26. Oliva page numbers refer to the working paper's printed pages.

## Summary

**Evidence**

- **SILS is an analysis device, not a display rule.** Oliva built it to decompose a
  strongly connected block for calibration and loop-dominance analysis (Oliva 2003/2004 §5).
  Its steps: (1) split the model into cycle partitions (strongly connected blocks);
  (2) in each, compute the all-pairs distance matrix D; (3) for every vertex pair
  (u,v), in order of loop length L(u,v)=D(u,v)+D(v,u), shortest first, trace one
  *geodetic cycle* (shortest path u→v plus shortest path v→u), dropping pairs already
  on a traced loop and dropping circuits that repeat a node; (4) from that
  length-sorted list, repeatedly accept the loop that adds the **fewest new edges**
  (ties: the shortest, i.e. first in the list), discarding loops that add none, until
  none remain.
- **What it guarantees is weaker than Oliva claimed.** Oliva states it always yields
  E−V+1 loops per cycle partition. Huang, Howley & Duggan (2012) and Middleton &
  Motamed (2024) show it can fall short, because some complete independent sets need
  non-geodetic loops (e.g. every complete digraph with ≥3 nodes; the n-agent goal
  diffusion model misses Σ(j−2) loops). It *does* cover every edge of the partition
  (Oliva p.10). The set is not unique when equal-length shortest paths exist, but
  Oliva argues the count and lengths are.
- **ILS size:** a strongly connected ("fully connected" in Kampmann's term) system
  with N links and n variables has exactly N−n+1 independent loops; other systems
  decompose into such subsystems (Kampmann 1996, extended abstract p.1).
- **Johnson (1975):** all elementary circuits in O((n+e)(c+1)) time, O(n+e) space.
- **Loop count explodes in real models:** Forrester's Urban Dynamics has 43,722,744
  loops (Eberlein & Schoenberg 2020).
- **Stella's Loops that Matter explicitly rejects ILS/SILS for picking important
  loops:** an independent set can omit the loop that dominates behaviour (arms-race
  example: SILS keeps the 6 short loops and drops the two 3-party loops that drive
  long-run behaviour). LTM enumerates exhaustively when a model has < 1000 loops,
  otherwise uses a heuristic "strongest path" search ranked by simulated link scores,
  and truncates *display* to loops explaining ≥ 0.1% of behaviour (< 200 loops)
  (Eberlein & Schoenberg 2020).
- **Tool practice is "list shortest first, cap, let the user choose".** Vensim's Loops
  tool lists loops through one variable shortest first, skips loops with more than
  32 intermediate variables and asks before showing more than 50. Kumu ranks
  detected loops shortest first, warns that dense maps reach thousands, and marks
  nothing until the user names a loop. No tool found uses SILS to decide what to
  mark on a diagram.
- **Practitioner guidance (Sterman) is about diagram size, not loop algebra:**
  "Don't Put All the Loops into One Large Diagram"; give each loop a number and name
  (R1, B1); build a series of smaller diagrams.
- **No source evaluates SILS as a display choice for readability.** Every use found
  is for model analysis (calibration, eigenvalue elasticity).

**Inference (for VGraph)**

- A CLD in VGraph has no equations, so no loop *strength* exists; the only honest
  ranking available is structural. Shortest-first is the structural analogue of
  what LTM does with scores (rank, then truncate), and is defensible.
- SILS answers "the fewest loops that together touch every feedback link". That is a
  coherent user-facing option, but it is **not** "the important loops" and it can
  drop a loop the user drew on purpose (the long loop in the arms-race case).
  If offered, name it for what it is (e.g. "independent loops" / "shortest
  independent set") and keep "all loops" as the default.
- If implemented, implement it knowing it may return fewer than E−V+1 loops; either
  accept that (Oliva's algorithm as published) or add the CSILS second-shortest-path
  completion (Middleton & Motamed 2024).

## 1. Oliva (2004): partitions and SILS

Source read: Oliva, R. (2003) *Model structure analysis through graph theory:
partition heuristics and feedback structure decomposition*, HBS Working Paper 04-016,
https://www.hbs.edu/ris/Publication%20Files/04-016_1ef8720a-a749-4a7b-9db7-1527c9c9efc9.pdf
— the pre-publication version of Oliva (2004), *System Dynamics Review* 20(4):313–336,
doi:10.1002/sdr.298. **The journal version is paywalled and was not read**; page
numbers below are the working paper's printed page numbers. Middleton & Motamed
(2024, Function 2) reproduce the same pseudocode as "SILS from Oliva (2004)", which
suggests the algorithm was not changed in publication.

**Partition step** (§4, pp.6–8). A *level partition* groups vertices by the
reachability matrix; a level is further split into *cycle partitions* — blocks of
vertices with identical predecessor/successor sets, i.e. maximal cycle sets
(Warfield 1989). "Cycle partitions are strongly connected graphs … and … contain all
the feedback loops in a model" (p.7). All loop analysis is then done per cycle
partition (p.9).

**Geodetic cycles** (§5 "Identifying loops in a cycle partition", pp.9–10, Figs 7–8).

1. Distance matrix: B = C + I; D = C + Σ_{i=2}^{|C|−1} i·(Bⁱ − Bⁱ⁻¹) with Boolean
   powers (p.9). (Any all-pairs shortest-path method gives the same D.)
2. Length matrix L = D_Lᵀ + D_U: L(u,v) is the length of the shortest loop through
   both u and v (p.9).
3. `Loops(C)` (Fig. 8): for i = 2 … max(L): take all pairs with L(u,v)=i; for each
   pair, `loop_track(u,v,D)` builds the loop by walking a shortest path u→v then
   v→u, at each step taking the **first** qualifying successor (Fig. 7 — this is the
   tie-break among equal shortest paths: matrix order); remove from the pair list every
   other pair already contained in that loop; keep the loop only if it has no
   repeated node.
4. Output is ordered by length. Claims (p.10): it "only reports geodetic circuits and
   does not identify all the feedback loops"; it is unique if no two shortest paths
   of equal length exist; "it does guarantee that, if it exists, a shortest cycle
   linking every vertex-pair is included"; the list "contains every vertex and edge
   of the cycle partition". Example: 33-vertex partition → 48 geodetic cycles, vs 106
   loops found by Kampmann's exhaustive search at 86% more CPU time.

**Independence and selection** (pp.10–11, Fig. 9).

- Criterion (Kampmann's construction rule): "accept a loop in the ILS iff it
  contains at least one edge not included in the previously accepted loops" (p.11).
  "New" means a new **edge** (link), not a new node. Self-loops are ignored (fn 8).
- Order: "selecting the shortest loop that makes the smallest addition of new edges
  to the loop set" (p.11). Fig. 9: repeat — for every remaining loop count the new
  edges it would add; discard loops adding 0; among the rest pick those with the
  minimum non-zero count and take the first (the shortest, since the list is
  length-sorted); add its edges to the covered set. So ordering is **global**, by
  minimal new-edge contribution then length — not per link.
- Guarantee claimed: number of loops "always equal to the maximum identified by
  Kampmann", E−V+1 per cycle partition (p.11; Appendix Theorem 1). **Refuted** —
  see below.
- Uniqueness: "the SILS is not unique" when equal-length shortest paths exist, but
  "the number of loops in an SILS and their length is unique" (p.12; Appendix
  Theorems 2 and "2"). Example: 48 geodetic cycles → SILS of 25 loops (p.12).
- Variant noted by Oliva (fn 10): always picking the shortest loop regardless of
  new-edge contribution gives shortest loops but fewer than the maximum.
- **MSILS** (pp.15–16): re-applying the rule longest-to-shortest removes loops made
  redundant by later ones (e.g. {u,v} is redundant given {u,v,x} and {u,w,v}); ~20%
  fewer loops for partitions > 10 vertices; 25 → 18 in the example.
- Oliva's intended use: calibration sequencing and loop-dominance analysis; he
  *posits* (p.16) SILS gives "the most intuitive explanation" of behaviour — stated
  as a conjecture to be tested, not shown.
- Complexity: Oliva gives none. Middleton & Motamed (2024, p.5) note the Boolean
  matrix-power D costs O(n⁴) and could use an all-pairs shortest path method instead;
  they state SILS and CSILS both run in O(n²m) (p.19).

**Known failure.** Huang, Howley & Duggan (2012), "Observations on the shortest
independent loop set algorithm", *SDR* 28(3):276–280, doi:10.1002/sdr.1477 — abstract
(via Crossref; full text paywalled, **not read**): in an individual-based model "the
SILS cannot identify the maximal independent feedback loops, which further causes
the failure of the loop analysis method". Middleton & Motamed (2024), "A complete
shortest independent loop set algorithm for model structure analysis", *SDR* 40(3):
e1787, doi:10.1002/sdr.1787, open copy https://math.unm.edu/~motamed/Articles/CSILS.pdf:
SILS "can only capture geodetic cycles" (p.8); complete digraph on 3 nodes: 3 of 4
needed loops; on 4 nodes: 6 of 9 (p.8); i-agent goal diffusion model misses
Σ_{j=3}^{i}(j−2) loops (Table 1, p.18). They add a second-shortest-path completion
(CSILS) when SILS returns fewer than m−n+1 loops. They note most SD models are not
dense enough for this to matter (p.8).

## 2. Kampmann (1996/2012): the Independent Loop Set

- Source read: Kampmann, C.E. (1996) *Feedback loop gains and system behavior*,
  extended abstract, Proc. 1996 Int. System Dynamics Conference,
  https://proceedings.systemdynamics.org/1996/proceed/papers/kampm260.pdf (scanned, 4 pp).
  Full paper: *SDR* 28(4):370–395 (2012), doi:10.1002/sdr.1483 — **paywalled, not
  read**; the abstract was read via Crossref.
- Size: "a 'fully connected' feedback system with N links and n variables contains
  exactly N−n+1 independent loops. (A 'fully connected' system is one in which there
  is a feedback loop between any pair of variables …) Otherwise, the system may be
  decomposed into fully connected subsystems, where the theorem once again applies"
  (1996 abstract p.1). "Fully connected" here means strongly connected. So the bound
  is per strongly connected component, summed. The number of all loops "may grow more
  than factorially" (ibid.); N "typically grows linearly with n, and at most as n²"
  (ibid.; also 2012 abstract).
- Definition of ILS as "a maximal set of loops whose incidence vectors are linearly
  independent", and that it is not unique: as reported by Oliva (p.8), citing
  Kampmann. Kampmann 1996 p.1: "there is a large number of such sets to choose from",
  and he suggests augmenting the algorithm so loops with large eigenvalue
  elasticities are chosen.
- Construction (per Oliva p.10–11 and Middleton & Motamed p.4, **not checked against
  Kampmann's full text**): start from a loop, take an edge to a vertex outside the
  accepted set, follow the shortest path back, repeat until every edge is covered;
  accept a loop iff it adds an edge. Oliva's criticism: no defined start, no rule for
  the next edge, and loops are not necessarily short (p.11).
- Example: Sterman's long-wave model has 36 loops; its independent set has 16
  (1996 abstract p.2).
- Relation to SILS: SILS is Kampmann's acceptance rule applied to the geodetic-cycle
  list in minimal-new-edge order (Oliva p.11, Appendix Th.1).

## 3. Johnson (1975)

Johnson, D.B. (1975) "Finding all the elementary circuits of a directed graph",
*SIAM J. Comput.* 4(1):77–84, doi:10.1137/0204007. Abstract (via Crossref): time
O((n + e)(c + 1)), space O(n + e), n vertices, e edges, c elementary circuits; "faster
because it considers each edge at most twice between any one circuit and the next in
the output sequence". Body not read (paywalled); the abstract is the author's own
claim.

## 4. What tools and the SD community do

### Stella / isee systems: Loops that Matter

Eberlein, R. & Schoenberg, W. (2020) "Finding the Loops that Matter",
arXiv:2006.08425, https://arxiv.org/abs/2006.08425 (read in full):

- Independent-loop approaches (Kampmann 2012; Oliva 2004) "do not turn out to be
  appropriate for the purpose of finding the most explanatory loops" (p.1); they are
  static and "will not necessarily find the loops most important to understanding
  behavior", citing Güneralp (2006) and Huang et al. (2012) (p.2).
- Arms-race example (pp.3–5): SILS = 3 balancing + 3 pairwise reinforcing loops, which
  cover every link; the two 3-party reinforcing loops are excluded yet dominate after
  ~t=50.
- Practice: exhaustive enumeration if the model has < 1000 loops (p.8); otherwise the
  heuristic "strongest path" search, run per time step, ordering outbound links by
  link score, Dijkstra-like pruning (pp.8–10). Admittedly incomplete: e.g. 76 of 104
  loops found in the service-quality model, 261 of 494 in Mass's economic cycles model
  (pp.10–11).
- Urban Dynamics: 43,722,744 loops; the heuristic finds 20,172, "truncated to less
  than 200 for display, by only choosing those loops which describe at least 0.1% of
  the total behavior" (p.11).

Schoenberg, W., Davidsen, P. & Eberlein, R. (2020) "Understanding model behavior
using the Loops that Matter method", *SDR* 36(2):158–190, doi:10.1002/sdr.1658; read
via the authors' preprint arXiv:1908.11434 (https://arxiv.org/abs/1908.11434):

- Calls SILS "the de-facto standard for determining which loops to analyze in EEA"
  (preprint p.4).
- LTM "does not require that loops be independent … and therefore does not restrict
  analysis to the minimal independent loop set identified by Oliva (2004)"; citing
  Güneralp (2006) and Huang et al. (2012), "restricting loops under consideration can
  filter out important loops". Every example in the paper analyses all loops
  (preprint p.13).

Stella help (isee systems, first-party):

- Loop Discovery (https://www.iseesystems.com/resources/help/v2/Content/05b%20-LoopsThatMatter/LoopDiscovery.htm):
  above the Exhaustive Search Threshold "(1000 by default), the alternative discovery
  approach is used"; the panel then says not all loops were found and only a subset
  is shown.
- Loops Panel (https://iseesystems.com/resources/help/v3/Content/08-Reference/02-AnalysisWindows/LoopsPanel.htm):
  loops are ranked by contribution to behaviour; names carry polarity B / R (plus
  Bu, Ru, U, D); by default only the first (most important) loop is shown; "Select
  Loops" adds loops until a chosen % of behaviour is explained.
- CLD Generation (https://www.iseesystems.com/resources/help/v3/Content/05b%20-LoopsThatMatter/CLDGeneration.htm):
  generated CLDs are filtered by a user-set inclusion threshold (on contribution),
  not by structure.

### Vensim (Ventana Systems)

Loops tool, https://www.vensim.com/documentation/loops_tool.html (first-party help):
lists "all feedback loops passing through the Workbench Variable", ordered shortest
(fewest variables) first; "will not list loops involving more than 32 intermediate
variables"; "If more than 50 loops are found you will be asked if you want to see
more than the first 50"; can be slow on large models; no options. So Vensim scopes
by **one variable**, sorts shortest first, and caps length and count — it does not
compute an independent set, and it does not mark loops on the diagram (selecting a
loop highlights it). Loop identifiers in Vensim sketches are placed by the modeller.

### Kumu

Loops guide, https://docs.kumu.io/guides/what-are-loops (first-party):
"Loops are ranked from shortest (least amount of elements) to longest (most
elements)"; warns "the number of loops on a highly inter-connected system map can
quickly run into the thousands" and advises simplifying or filtering the map; loops
are not saved or labelled until the user names them ("Unnamed loops are not saved in
your dataset!"). R/B labels are the user's own addition to the loop label. So: detect
all, sort shortest first, **user picks** which to mark.

### Insight Maker, Loopy

Insight Maker "Identify Loops" (https://insightmaker.com/docs/identifyloops) says it
"automatically detects and displays all the feedback loops"; the page documents no
ordering, limit or polarity. Loopy (ncase.me/loopy) has no documented loop detection;
not investigated further.

### Sterman, *Business Dynamics* (2000)

The book was **not read** (not openly available; copies found online are
unauthorised and were not used). Relied instead on Sterman's own articles in *The
Systems Thinker* (Pegasus Communications), which set out the same CLD guidelines:

- "Fine-Tuning Your Causal Loop Diagrams — Part II", J. Sterman,
  https://thesystemsthinker.com/fine-tuning-your-causal-loop-diagrams-part-ii/ —
  guideline headings include "Don't Put All the Loops into One Large Diagram" and
  "Name Your Loops": "give each a number and a name" (R1, R2, B1 …); cites the 5–9
  chunk limit of short-term memory and recommends a series of smaller diagrams, then
  chunking detail into an aggregate overview.
- Part I (https://thesystemsthinker.com/fine-tuning-your-causal-loop-diagrams-part-i/):
  when a link's sign is ambiguous, there is usually more than one causal pathway, and
  these "should" be made explicit — relevant to VGraph's "?" polarity marker.
- Whether *Business Dynamics* ch.5 says to mark only "important" loops: **unverified**
  (a Wikipedia summary says so; not traced to the book).

Community practice, then: the practitioner guidance is about the *diagram author*
choosing and naming loops and keeping each diagram small; tools that detect loops
(Vensim, Kumu) list them **shortest first** and cap or leave selection to the user;
the one tool that auto-selects (Stella LTM) ranks by simulated behavioural
contribution, not by independence. No tool found uses SILS to decide what to mark on
a diagram.

## 5. Is SILS good practice for readability?

- **For:** Oliva (p.12) calls the SILS "the simplest and most granular description of
  the structure" and posits (p.16, untested) it gives the most intuitive dominance
  explanations. Kampmann (1996 p.2) found most loops in his independent set "have an
  intuitive interpretation". Schoenberg et al. (2020) call it the de-facto standard
  *for EEA*.
- **Against / caveats:**
  - Incomplete in dense graphs (Huang et al. 2012; Middleton & Motamed 2024, §1).
  - Can omit the behaviourally important loop (Eberlein & Schoenberg 2020 arms-race
    example; Güneralp 2006 and Huang et al. 2012 as cited there — those two not read).
  - Even within the set, loops are not independently adjustable (Oliva p.15), and
    SILS can contain redundant loops that MSILS removes (pp.15–16).
  - Not unique when equal shortest paths exist (Oliva p.12): which loop a diagram
    shows would depend on node order.
- **Readability specifically:** no source found evaluates SILS as a *display*
  choice for CLDs. All sources above use it for model analysis. Any claim that it
  improves diagram readability is inference.

## 6. Terminology

| Term | Meaning | Source |
|---|---|---|
| independent loop set (ILS) | maximal set of loops with linearly independent edge-incidence vectors; N−n+1 per strongly connected subsystem | Kampmann 1996; Oliva p.8 |
| geodetic cycle / geodetic circuit | loop made of a shortest path u→v and a shortest path v→u; "no shorter circuit in which these two vertices are involved" | Oliva p.9 (after Warfield 1989) |
| shortest independent loop set (SILS) | ILS built from geodetic cycles by minimal-new-edge selection | Oliva p.11 |
| minimal shortest ILS (MSILS) | SILS with redundant loops removed | Oliva p.16 |
| complete SILS (CSILS) | SILS completed with second-shortest cycles | Middleton & Motamed 2024 |
| cycle partition / maximal cycle set | strongly connected block holding all loops | Oliva p.7 |
| loop dominance | which loops drive behaviour over a period | Schoenberg et al. 2020; Kampmann 1996 |
| loops that matter / loop score | isee's behavioural ranking of loops | Schoenberg et al. 2020 |
| loop identifier / loop name (R1, B2) | the labelled marker in a CLD | Sterman, *Systems Thinker* Part II |

"Geometrically independent" was not found in any source read; avoid it. In general
graph theory the ILS size is the cyclomatic number (a cycle basis); that link is
standard but was not checked against a source here.

**Inference for naming a user option:** "Independent loops" is the community term
closest to what SILS delivers; "shortest independent loops" is Oliva's exact term.
Neither means "important loops", so a label like "Key loops" would misrepresent it.
