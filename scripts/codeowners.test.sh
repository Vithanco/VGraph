#!/usr/bin/env bash
# .github/CODEOWNERS names the maintainer for every file that runs commands or
# steers a coding agent: whoever can change one can run code, or give
# instructions, on another person's machine. Two ways it can quietly protect
# nothing: a pattern with a typo, and a file nobody listed.
set -uo pipefail

FILE=${CODEOWNERS_FILE:-.github/CODEOWNERS}
FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }

[ -f "$FILE" ] || { echo "FAIL: $FILE is missing" >&2; exit 1; }

# Patterns for things that hold nothing today: listed so that adding them needs approval.
RESERVED="/.claude/ /.agents/"

# Every file in a group below has to be covered. Groups that name a path that is not
# tracked today (a hypothetical addition) are checked as strings.
MUST_COVER="
AGENTS.md
justfile
Dockerfile
.dockerignore
.gcloudignore
plugins.json
Package.swift
Package.resolved
package.json
package-lock.json
VGraphWasm/Package.swift
VGraphWasm/Package.resolved
vgraph-mcp-node/package.json
vgraph-mcp-node/release.sh
website/dist/package.json
build-wasm.sh
deploy.sh
release-plugins.sh
setup-plugins.sh
scripts/check-plugin-api.sh
scripts/anything-new.txt
.githooks/pre-commit
.github/CODEOWNERS
.github/dependabot.yml
.github/workflows/ci.yml
.claude/skills/x/SKILL.md
.agents/skills/x/SKILL.md
"

patterns=$(grep -vE '^\s*(#|$)' "$FILE" | awk '{print $1}')
[ -n "$patterns" ] || fail "no patterns"

# Every line has a pattern and at least one owner written @name.
while read -r line; do
    [ -z "$line" ] && continue
    owners=$(echo "$line" | cut -d' ' -f2-)
    echo "$owners" | grep -qE '(^| )@[A-Za-z0-9_-]+' || fail "no owner on: $line"
done < <(grep -vE '^\s*(#|$)' "$FILE" | tr -s ' \t' ' ')

# CODEOWNERS patterns follow .gitignore rules, so let git do the matching.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git init -q "$TMP"

matches() { # pattern path... -> prints the paths the pattern matches
    printf '%s\n' "$1" > "$TMP/.git/info/exclude"
    shift
    printf '%s\n' "$@" | git -C "$TMP" check-ignore --no-index --stdin 2>/dev/null
}

tracked=$(git ls-files)
while read -r pat; do
    case " $RESERVED " in *" $pat "*) continue ;; esac
    # shellcheck disable=SC2086
    [ -n "$(matches "$pat" $tracked)" ] || fail "pattern matches no tracked file: $pat"
done <<< "$patterns"

printf '%s\n' "$patterns" > "$TMP/.git/info/exclude"
for path in $MUST_COVER; do
    echo "$path" | git -C "$TMP" check-ignore --no-index -q --stdin || fail "not covered by CODEOWNERS: $path"
done

exit $FAILED
