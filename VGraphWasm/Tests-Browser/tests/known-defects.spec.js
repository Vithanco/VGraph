// Bugs this harness found, marked `test.fail()`: the suite stays green while
// they are open, and the marker itself fails the moment one is fixed, so the test
// gets promoted rather than forgotten. Fix the behaviour, drop the `test.fail()`,
// move the test into the suite it belongs to.
//
// Currently empty. The last two entries — a folded group ignoring double-click
// rename and the move drop-target wash — were fixed by stamping its box as the
// group (ADR-0027); they now live in commands.spec.js and
// move-between-groups.spec.js.
