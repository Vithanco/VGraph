#!/usr/bin/env bash
# Graphviz is quoted under three different licences across the repo and the plugin
# READMEs. It is EPL-2.0, and a dependency that moves under an open-ended `from:`
# changes what the engine is built from without anyone touching this repo.
# Plugin directories are separate checkouts that are gitignored here, so they are
# checked when present.
set -uo pipefail

FAILED=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $*" >&2; FAILED=1; }

# A line states a Graphviz licence when it names Graphviz and a licence in one breath.
states_licence() { grep -E 'Graphviz' "$1" 2>/dev/null | grep -E 'EPL|Eclipse' ; }

must_state_epl2() { # label file
    local out
    out=$(states_licence "$2")
    if [ -z "$out" ]; then fail "$1: no Graphviz licence statement in $2"
    elif echo "$out" | grep -qE 'EPL-2\.0|Eclipse Public License,? (v|V)?(ersion )?2\.0'; then pass "$1"
    else fail "$1: $2 does not say EPL-2.0: $out"; fi
}

may_state_epl2() { # label file
    local out
    out=$(states_licence "$2")
    if [ -z "$out" ] || echo "$out" | grep -qE 'EPL-2\.0|Eclipse Public License,? (v|V)?(ersion )?2\.0'; then pass "$1"
    else fail "$1: $2 does not say EPL-2.0: $out"; fi
}

# 1: the sentence about Graphviz itself, not the EPL-2.0 label on swiftGraphviz next to it
sentence=$(tr '\n' ' ' < NOTICE | tr -s ' ' | grep -oE 'Graphviz is licensed[^;]*')
if echo "$sentence" | grep -qE 'EPL-2\.0|Eclipse Public License,? (v|V)?(ersion )?2\.0'; then
    pass 'Given the tree, when NOTICE is read, then it names Graphviz as EPL-2.0'
else
    fail "NOTICE does not say Graphviz is EPL-2.0: ${sentence:-no sentence about the Graphviz licence}"
fi

# 2
if [ -f obsidian-vithanco/README.md ]; then
    must_state_epl2 "Given the tree, when the Obsidian README is read, then it names Graphviz as EPL-2.0" obsidian-vithanco/README.md
else
    echo "skip Obsidian README: obsidian-vithanco/ is not checked out"
fi

# 3 and 4: a README that says nothing about the licence has nothing to contradict
for f in vscode-vithanco/README.md website/dist/README.md; do
    [ -f "$f" ] && may_state_epl2 "Given the tree, when $f is read, then any Graphviz licence it states is EPL-2.0" "$f"
done

# 5
stale=$(git ls-files -z | xargs -0 grep -InE 'EPL-1\.0|Public License,? (v|V)?(ersion )?1\.0' -- 2>/dev/null \
    | grep -v '^scripts/licence.test.sh:' | grep -i graphviz)
for f in obsidian-vithanco/README.md vscode-vithanco/README.md; do
    [ -f "$f" ] && stale+=$(grep -nE 'EPL-1\.0' "$f" | sed "s|^|$f:|")
done
if [ -z "$stale" ]; then pass 'Given the tree, when any tracked file is searched, then EPL-1.0 for Graphviz appears nowhere'
else fail "EPL-1.0 for Graphviz: $stale"; fi

# 7
line=$(grep -n 'Vithanco/swiftGraphviz' Package.swift | head -1)
if echo "$line" | grep -qE 'exact:|upToNextMinor|\.\.<'; then
    pass 'Given Package.swift, when the swiftGraphviz requirement is read, then it is exact or bounded'
else
    fail "swiftGraphviz requirement is open-ended: $line"
fi

exit $FAILED
