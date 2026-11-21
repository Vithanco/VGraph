#!/usr/bin/env bash
# `just release` skips the tests CI already ran, so it must only do that when
# every check the main ruleset requires passed on the very commit it builds.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(mktemp -d) || exit 1
trap 'rm -rf "$ROOT"' EXIT
FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }
command -v jq >/dev/null || { echo "SKIP: needs jq"; exit 0; }

# Answers with the API's JSON from CI/, through the caller's --jq like gh does.
mkdir "$ROOT/bin"
cat > "$ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$CI/gh.log"
[ -f "$CI/offline" ] && { echo "error connecting to api.github.com" >&2; exit 1; }
case "$2" in
    */rules/branches/main) body="$CI/rules.json" ;;
    */check-runs*) body="$CI/runs.json" ;;
    *) exit 1 ;;
esac
[ "$3" = --jq ] && exec jq -r "$4" "$body"
cat "$body"
EOF
chmod +x "$ROOT/bin/gh"
export PATH="$ROOT/bin:$PATH"

REQUIRED='"Swift on Linux","Wasm build","Shell tests"'
given_checks() { # name:status:conclusion ...
    export CI=$(mktemp -d "$ROOT/ci.XXXXXX")
    printf '[{"type":"pull_request"},{"type":"required_status_checks","parameters":{"required_status_checks":[%s]}}]\n' \
        "$(echo "$REQUIRED" | sed 's/"\([^"]*\)"/{"context":"\1"}/g')" > "$CI/rules.json"
    local runs="" r name status conclusion
    for r in "$@"; do
        IFS=: read -r name status conclusion <<<"$r"
        [ -n "$conclusion" ] && conclusion="\"$conclusion\"" || conclusion=null
        runs="$runs${runs:+,}{\"name\":\"$name\",\"status\":\"$status\",\"conclusion\":$conclusion}"
    done
    echo "{\"total_count\":$#,\"check_runs\":[$runs]}" > "$CI/runs.json"
}
status() { "$REPO_ROOT/scripts/ci-status.sh" abc123 >"$CI/out" 2>&1; }
GREEN=("Swift on Linux:completed:success" "Wasm build:completed:success" "Shell tests:completed:success")

# Given every required check passed, and one that is not required failed, then CI is green.
given_checks "${GREEN[@]}" "Analyze (python):completed:failure"
status || fail "required checks passed but not green: $(cat "$CI/out")"
grep -q 'commits/abc123/check-runs' "$CI/gh.log" || fail "did not ask about the given commit: $(cat "$CI/gh.log")"

# Given a required check still running, then not green, and it says which.
given_checks "Swift on Linux:in_progress:" "Wasm build:completed:success" "Shell tests:completed:success"
status && fail "green while a check runs"
grep -q 'Swift on Linux' "$CI/out" || fail "does not name the running check: $(cat "$CI/out")"

# Given a required check that failed, then not green.
given_checks "Swift on Linux:completed:success" "Wasm build:completed:failure" "Shell tests:completed:success"
status && fail "green with a failed check"
grep -q 'Wasm build' "$CI/out" || fail "does not name the failed check: $(cat "$CI/out")"

# Given a required check that never ran on the commit, then not green.
given_checks "Swift on Linux:completed:success" "Wasm build:completed:success"
status && fail "green with a check missing"
grep -q 'Shell tests' "$CI/out" || fail "does not name the missing check: $(cat "$CI/out")"

# Given a ruleset that requires nothing, then not green: there is nothing to trust.
REQUIRED=''
given_checks "${GREEN[@]}"
status && fail "green with no required checks"
REQUIRED='"Swift on Linux","Wasm build","Shell tests"'

# Given GitHub unreachable, then not green.
given_checks "${GREEN[@]}"
touch "$CI/offline"
status && fail "green while offline"

exit "$FAILED"
