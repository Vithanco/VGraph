# Domain Docs

How the engineering skills consume this repo's domain documentation.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root: the glossary. `grep -n "^### " CONTEXT.md` lists the terms; read the section before naming or placing a concept.
- **`docs/adr/`**: read the ADRs that touch the area you're about to work in.

This repo has one context. There is no `GLOSSARY.md` or `GLOSSARY-MAP.md`; where a skill says `GLOSSARY.md`, read `CONTEXT.md`.

## Use the glossary's vocabulary

When your output names a domain concept (an issue title, a refactor proposal, a hypothesis, a test name), use the term as `CONTEXT.md` defines it. Don't drift to synonyms it lists under *Avoid*.

If the concept you need isn't in the glossary yet, either you're inventing language the project doesn't use (reconsider), or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, say so explicitly rather than silently overriding it:

> _Contradicts ADR-0007 (…), but worth reopening because…_

## Keep ADRs current

An ADR's body states the decision as it stands, so one file is enough to act on. Git keeps the history.

- **A later ADR changes an earlier one:** edit the earlier body to say what holds now, and give its Status one line pointing at the later ADR. Don't pile amendments into Status as prose.
- **A later ADR mostly replaces an earlier one:** merge the earlier one in — what still holds, and its rejected alternatives — then delete it. First `git grep` its number: code comments cite ADRs for reasons that must survive the merge. Repoint every citation, and name the absorbed number in the survivor's Status ("Absorbs 0026, …") so a number met in an old commit or issue still leads somewhere.
- **Numbers are never reused or renumbered.** Gaps are fine.
