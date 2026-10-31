#!/usr/bin/env bash
# The public repository is one commit made from the tracked files of main. Anything
# ignored, local to an agent, or unchecked must not travel, the clean copy must
# build and test on its own, and the commit must carry the maintainer and nothing
# else. The check command and gitleaks are stood in for, since a fixture cannot run
# the real `just test`.
set -uo pipefail

FAILED=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $*" >&2; FAILED=1; }

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.test
export GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.test

CORP="SAMPLE-""CORP"
SFS="SF Sym""bol"
OLD12="OLD""-12"
MAINTAINER="Klaus Kneupner <klaus@vithanco.com>"

LIST="$TMP/forbidden.txt"
printf '# sample list\n%s\n' "$CORP" > "$LIST"

FAKEBIN="$TMP/fakebin"
mkdir -p "$FAKEBIN"
printf '#!/bin/sh\nexit 0\n' > "$FAKEBIN/gitleaks"
chmod +x "$FAKEBIN/gitleaks"
BASEPATH="/usr/bin:/bin"

T="$TMP/template"
mkdir -p "$T/scripts"
git init -q -b main "$T"
printf 'Apache License\n' > "$T/LICENSE"
printf 'Fixture notice\n' > "$T/NOTICE"
printf '# Fixture\n\nSee [contributing](CONTRIBUTING.md).\n' > "$T/README.md"
printf 'How to contribute\n' > "$T/CONTRIBUTING.md"
printf 'How to report\n' > "$T/SECURITY.md"
printf 'ignored.txt\n' > "$T/.gitignore"
for f in audit-public.sh audit-public.test.sh export-public.sh export-public.test.sh; do
    cp "$REPO/scripts/$f" "$T/scripts/$f"
done
git -C "$T" add -A && git -C "$T" commit -qm "initial"

new_source() { local d; d=$(mktemp -d "$TMP/s.XXXXXX"); cp -R "$T/." "$d"; echo "$d"; }

commit_file() { # repo path content
    mkdir -p "$(dirname "$1/$2")"
    printf '%s\n' "$3" > "$1/$2"
    git -C "$1" add -f -- "$2" && git -C "$1" commit -qm "add $2"
}

run_export() { # source target [extra env assignments...]
    local src=$1 target=$2; shift 2
    OUT=$(cd "$src" && env VITHANCO_FORBIDDEN="$LIST" PATH="$FAKEBIN:$BASEPATH" VITHANCO_EXPORT_CHECK=true \
        "$@" ./scripts/export-public.sh "$target" 2>&1)
    STATUS=$?
}

report_of() { echo "$1-report.txt"; }
has_commit() { git -C "$1" rev-parse -q --verify HEAD >/dev/null 2>&1; }

check() { # name condition-status
    if [ "$2" -eq 0 ]; then pass "$1"; else fail "$1: exit $STATUS: $OUT"; fi
}

fails_with() { # name extended-regex
    if [ "$STATUS" -ne 0 ] && grep -qiE -- "$2" <<<"$OUT"; then pass "$1"
    else fail "$1: exit $STATUS, wanted /$2/: $OUT"; fi
}

# Refusals

s=$(new_source)
printf 'changed\n' >> "$s/README.md"
run_export "$s" "$TMP/out-dirty"
if [ "$STATUS" -ne 0 ] && grep -qiE "uncommitted|dirty" <<<"$OUT" && [ ! -e "$TMP/out-dirty" ]; then
    pass "Given uncommitted changes, then it refuses and creates no target"
else fail "Given uncommitted changes, then it refuses and creates no target: exit $STATUS: $OUT"; fi

s=$(new_source)
git -C "$s" checkout -qb other
run_export "$s" "$TMP/out-branch"
fails_with "Given HEAD on another branch, then it refuses" "not on main|main"

s=$(new_source)
mkdir -p "$TMP/out-full" && printf 'x\n' > "$TMP/out-full/keep.txt"
run_export "$s" "$TMP/out-full"
fails_with "Given a target that already exists and is not empty, then it refuses" "not empty|exists"

# A clean export carrying one of each case that must pass

s=$(new_source)
printf 'secret\n' > "$s/ignored.txt"
commit_file "$s" .claude/settings.json '{}'
commit_file "$s" docs/e.md "colour #fff, decided in $OLD12"
commit_file "$s" CONTEXT.md "*Avoid*: $SFS"
commit_file "$s" docs/VGL_GUIDE.md "$SFS-style icons"
commit_file "$s" docs/adr/0022-icons.md "Amended: no $SFS"
commit_file "$s" docs/adr/0003-old.md "Reversed in $OLD12."
git -C "$s" commit -q --allow-empty -m $'last\n\nCo-Authored-By: Someone <someone@example.test>'
SOURCE_SHA=$(git -C "$s" rev-parse HEAD)
D="$TMP/out-clean"
run_export "$s" "$D" GIT_AUTHOR_NAME="Someone Else" GIT_AUTHOR_EMAIL=else@example.test \
    GIT_COMMITTER_NAME="Someone Else" GIT_COMMITTER_EMAIL=else@example.test
CLEAN_STATUS=$STATUS
[ "$STATUS" -eq 0 ] || echo "  clean export failed: exit $STATUS: $OUT" >&2
R=$(report_of "$D")

# What travels

[ ! -e "$D/ignored.txt" ] && [ -f "$D/README.md" ]
check "Given an ignored, untracked file, then the target does not contain it" $?

[ ! -e "$D/.claude" ] && [ -f "$D/README.md" ]
check "Given a tracked .claude/settings.json, then the target does not contain it" $?

grep -qF ".claude/settings.json" "$R" 2>/dev/null
check "Given a tracked .claude/ file, then the report lists it as excluded" $?

cmp -s "$s/docs/e.md" "$D/docs/e.md" && cmp -s "$s/docs/adr/0003-old.md" "$D/docs/adr/0003-old.md"
check "Given tracked files containing \"#fff\" and \"$OLD12\", then the target holds them byte for byte" $?

[ -f "$D/scripts/audit-public.sh" ] && [ -f "$D/scripts/audit-public.test.sh" ] \
    && [ -f "$D/scripts/export-public.sh" ] && [ -f "$D/scripts/export-public.test.sh" ]
check "Given the scripts and their tests, then the target contains them" $?

# VGraph rules

check "Given \"$SFS\" in the CONTEXT.md avoid-list, docs/VGL_GUIDE.md and the ADR-0022 amendment, then it passes" "$CLEAN_STATUS"

grep -qF "CONTEXT.md:1" "$R" 2>/dev/null && grep -qF "docs/VGL_GUIDE.md:1" "$R" && grep -qF "docs/adr/0022-icons.md:1" "$R"
check "Given those allowed matches, then the report shows each one" $?

s=$(new_source)
commit_file "$s" docs/other.md "uses an $SFS"
run_export "$s" "$TMP/out-sfs"
fails_with "Given \"$SFS\" in any other file, then it fails naming file:line" "docs/other\.md:1"

check "Given \"$OLD12\" in docs/adr, then it passes" "$CLEAN_STATUS"

s=$(new_source)
commit_file "$s" Sources/x.swift "// see $OLD12"
run_export "$s" "$TMP/out-old"
fails_with "Given \"$OLD12\" in Sources/, then it fails naming file:line" "Sources/x\.swift:1"

s=$(new_source)
commit_file "$s" a.md "works for $CORP"
run_export "$s" "$TMP/out-corp"
if [ "$STATUS" -ne 0 ] && grep -qF "a.md:1" <<<"$OUT" && ! has_commit "$TMP/out-corp"; then
    pass "Given a forbidden string in the exported tree, then it fails and makes no commit"
else fail "Given a forbidden string in the exported tree, then it fails and makes no commit: exit $STATUS: $OUT"; fi
CORP_REPORT=$(report_of "$TMP/out-corp")

# Clean clone

s=$(new_source)
run_export "$s" "$TMP/out-check" VITHANCO_EXPORT_CHECK=false
if [ "$STATUS" -ne 0 ] && grep -qiE "check" <<<"$OUT" && ! has_commit "$TMP/out-check"; then
    pass "Given a check command that fails, then the export fails and makes no commit"
else fail "Given a check command that fails, then the export fails and makes no commit: exit $STATUS: $OUT"; fi

s=$(new_source)
CHECKED="$TMP/checked-in"
run_export "$s" "$TMP/out-where" VITHANCO_EXPORT_CHECK="pwd -P > '$CHECKED'"
[ -f "$CHECKED" ] && [ "$(cat "$CHECKED")" = "$(cd "$TMP/out-where" 2>/dev/null && pwd -P)" ]
check "Given the check command, then it runs inside the target" $?

# The commit

[ "$(git -C "$D" rev-list --count HEAD 2>/dev/null)" = "1" ] && [ "$(git -C "$D" branch --show-current 2>/dev/null)" = "main" ]
check "Given a clean export, then the target has exactly one commit, on main" $?

[ "$(git -C "$D" log --format='%an <%ae>|%cn <%ce>' 2>/dev/null)" = "$MAINTAINER|$MAINTAINER" ]
check "Given a local git identity of someone else, then author and committer are both the maintainer" $?

has_commit "$D" && [ -z "$(git -C "$D" log -1 --format=%B | git interpret-trailers --parse)" ]
check "Given a clean export, then the commit message has no trailer" $?

has_commit "$D" && [ -z "$(git -C "$D" remote)" ]
check "Given a clean export, then the target has no remote" $?

# Report

[ -f "$R" ] && [ -f "$CORP_REPORT" ] && [ -z "$(find "$D" "$TMP/out-corp" -name '*report*' 2>/dev/null)" ]
check "Given any run, then the report is written next to the target, not inside it" $?

grep -qF "$SOURCE_SHA" "$R" 2>/dev/null
check "Given a clean export, then the report names the source commit" $?

has_commit "$D" && ! git -C "$D" log -1 --format=%B | grep -qF "${SOURCE_SHA:0:7}"
check "Given a clean export, then the commit message does not name the source commit" $?

exit $FAILED
