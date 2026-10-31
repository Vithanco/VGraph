# Contributing to VGraph

Pull requests are very welcome. For anything larger than a small fix, open an
issue first or comment on an existing one, so we can agree on the shape before
you spend the time. Issues marked `good first issue` are a good place to start.

## Set up

[README](README.md#building) lists what to install. `just doctor` checks it.

```bash
just build        # compile everything
swift test        # the quick loop for most changes
just test         # the full gate before you open a pull request
```

`just test` also runs the wasm smoke tests and the editor's browser tests, so it
needs the wasm toolchain and Node. If a change cannot affect those, say so in the
pull request and run what applies.

## How we work

**Tests come first.** Write the test, watch it fail for the reason you expect,
then make it pass. This applies to bug fixes as much as to features. The test
goes in the target that matches what it needs;
[where a test goes](docs/where-things-live.md#where-a-test-goes) has the table.

**Keep documentation small and about why.** Comments that repeat the code are
noise, and a test is better than a comment that describes behaviour. Decisions
worth keeping go in `docs/adr/`, vocabulary in `CONTEXT.md`, language changes in
`docs/VGL_GUIDE.md`.

**Follow the architecture.** `AGENTS.md` is the short version of the rules, for
people and for coding agents alike: the hexagonal layout, the way ports are
declared twice, typed errors, and the Embedded Swift restrictions that apply to
everything compiled into the wasm module (no key paths, no reflection, no generic
calls on `any` values). `ArchitectureTest` fails on the ones it can check.

**Some files get a closer look.** Anything that runs commands or steers a coding
agent (`AGENTS.md`, `.claude/`, `.agents/`, `.github/`, `justfile`, `scripts/`,
`Dockerfile` and the release scripts) needs the maintainer's approval, listed in
`.github/CODEOWNERS`. A pull request should not be able to plant instructions for
someone else's tools, so changes there are read line by line.

**Colours and looks follow the design guide.** If a change touches a colour, a
token, a notation's look or dark mode, read [docs/design](docs/design/README.md)
first. The renderer does not read the guide, so a value that changes must change
in both places in the same pull request.

## Format and commit messages

```bash
just format       # what to run when `just lint` goes red
```

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org):
`feat(editor): …`, `fix(parser): …`, `docs: …`, `test: …`, `chore: …`. Say what
changed and why in the body when it is not obvious. Keep each commit to one idea.

## Pull requests

- One topic per pull request, with the tests that cover it.
- Link the issue it closes, and say what you ran.
- Maintainers merge with a merge commit, so the branch history stays visible.

## Releases

Publishing needs the maintainer's own accounts, and the recipes that publish
refuse to start otherwise. You do not need them to contribute.

Before a repository goes public, `scripts/audit-public.sh <dir>` checks it, and
`scripts/export-public.sh <target>` makes VGraph's public tree as one commit. Both
read a list of strings that must never be public from a file outside every
repository, so no repository holds the strings it keeps out:
`~/.config/vithanco/forbidden-strings.txt`, or the path in `VITHANCO_FORBIDDEN`.
Write one string per line; matching is case-insensitive and exact (no patterns),
and a line starting with `#` is a comment. Both need `gitleaks`.

## Reporting a problem

Use the issue tracker. For a security problem, please do not open a public issue:
see [SECURITY.md](SECURITY.md).

## Licence

By contributing you agree that your work is licensed under the
[Apache License 2.0](LICENSE), as the rest of the project is. There is no
separate agreement to sign.
