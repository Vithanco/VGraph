#!/usr/bin/env bash
# Exit 0 when every check the `main` ruleset requires passed on a commit.
#
#   scripts/ci-status.sh [commit]   # default HEAD
#
# `just release` trusts these instead of running the same tests again. The list
# comes from the ruleset rather than from here, so a check made required later
# is trusted only once it has passed too.
set -uo pipefail

REPO=Vithanco/VGraph
SHA=${1:-$(git rev-parse HEAD)}

if ! REQUIRED=$(gh api "repos/$REPO/rules/branches/main" \
        --jq '.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context'); then
    echo "Could not read the checks main requires." >&2
    exit 1
fi
if [ -z "$REQUIRED" ]; then
    echo "main requires no checks, so there is nothing to trust." >&2
    exit 1
fi
if ! RUNS=$(gh api "repos/$REPO/commits/$SHA/check-runs?per_page=100" \
        --jq '.check_runs[] | [.name, .status, (.conclusion // "")] | @tsv'); then
    echo "Could not read the checks on $SHA." >&2
    exit 1
fi

GREEN=1
while IFS= read -r name; do
    run=$(printf '%s\n' "$RUNS" | awk -F'\t' -v n="$name" '$1 == n { print $2 "\t" $3; exit }')
    case "$run" in
        "completed	success") ;;
        "") echo "  $name: has not run on ${SHA:0:7}" >&2; GREEN=0 ;;
        completed*) echo "  $name: ${run#completed	}" >&2; GREEN=0 ;;
        *) echo "  $name: still running" >&2; GREEN=0 ;;
    esac
done <<<"$REQUIRED"

if [ "$GREEN" -eq 1 ]; then
    echo "CI passed on ${SHA:0:7}: $(echo "$REQUIRED" | paste -sd';' - | sed 's/;/; /g')"
fi
[ "$GREEN" -eq 1 ]
