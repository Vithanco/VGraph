#!/usr/bin/env bash
# Reviews a repository before it goes public: what must stay private has to be
# absent from the tracked tree, the commit messages and the commit identities.
# Read-only and not tied to VGraph. The forbidden strings live outside every
# repository, so no repository holds the strings it is meant to keep out.
#
# Usage: scripts/audit-public.sh <dir>
#   VITHANCO_FORBIDDEN  list file (default ~/.config/vithanco/forbidden-strings.txt):
#                       one fixed string per line, case-insensitive, # for comments.
# Exits non-zero on any finding.
set -uo pipefail

DIR=${1:?usage: audit-public.sh <dir>}
FINDINGS=0
finding() { echo "FAIL $*"; FINDINGS=1; }

if ! git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "FAIL $DIR is not a git repository"
    exit 1
fi
LIST=${VITHANCO_FORBIDDEN:-$HOME/.config/vithanco/forbidden-strings.txt}
if [ ! -f "$LIST" ]; then
    echo "FAIL forbidden-strings list not found: $LIST"
    exit 1
fi

cd "$DIR" || exit 1
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

grep -vE '^[[:space:]]*(#|$)' "$LIST" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' > "$WORK/patterns"

tracked_grep() { # grep args...: over tracked text files, file:line:text
    git ls-files -z | xargs -0 grep -InH "$@" -- 2>/dev/null
}

report_lines() { # label: one finding per input line
    while IFS= read -r line; do finding "$1: $line"; done
}

# Forbidden strings
if [ -s "$WORK/patterns" ]; then
    report_lines "forbidden string" < <(tracked_grep -iF -f "$WORK/patterns")
    while IFS= read -r p; do
        n=$(git log --all --regexp-ignore-case --fixed-strings --grep="$p" --format=%H | wc -l | tr -d ' ')
        [ "$n" -gt 0 ] && finding "forbidden string \"$p\" in commit messages: $n commits"
        n=$(git log --all --format='%an <%ae>' | grep -ciF -- "$p")
        [ "$n" -gt 0 ] && finding "forbidden string \"$p\" in author identities: $n commits"
        n=$(git log --all --format='%cn <%ce>' | grep -ciF -- "$p")
        [ "$n" -gt 0 ] && finding "forbidden string \"$p\" in committer identities: $n commits"
    done < "$WORK/patterns"
fi

# Forbidden whatever the list says. Assembled so this file does not match itself.
report_lines "home directory path" < <(tracked_grep -F "/Us""ers/")
report_lines "signing identity" < <(tracked_grep -E 'Developer ID Application: [^"()]+\([A-Z0-9]{10}\)')

# Issue numbers. Once the repository is public, a bare #N points at an unrelated
# new issue. Upstream references are written owner/repo#N; six- and eight-digit
# colours, entities, quoted or backticked literals and counters such as "(UDE #1)"
# are not references.
read -r -d '' BARE_ISSUE <<'AWK'
{
    s = $0; pos = 0
    while (match(s, /#[0-9][0-9A-Za-z_-]*/)) {
        at = pos + RSTART; len = RLENGTH
        pos = at + len - 1; s = substr($0, pos + 1)
        digits = substr($0, at + 1, len - 1)
        if (digits !~ /^[0-9]+$/ || length(digits) == 6 || length(digits) == 8) continue
        prev = at > 1 ? substr($0, at - 1, 1) : ""
        head = substr($0, 1, at - 1)
        if (prev ~ /[A-Za-z0-9_.\/&"'`-]/) continue
        if (head ~ /:[ \t]*$/) continue
        if (head ~ /\([A-Za-z]+ $/ && substr($0, at + len, 1) == ")") continue
        print FILENAME ":" FNR ":" $0
        next
    }
}
AWK
report_lines "bare issue number" < <(git ls-files -z | xargs -0 grep -IlE --null '#[0-9]' -- 2>/dev/null \
    | xargs -0 awk "$BARE_ISSUE" 2>/dev/null)

origin=$(git remote get-url origin 2>/dev/null | sed -E 's#^(https://|git@)github\.com[:/]##; s#\.git$##')
if [ -n "$origin" ]; then
    report_lines "link to an issue of this repository" \
        < <(tracked_grep -iE "github\.com/$origin/(issues|pull)/[0-9]")
fi

# What a public repository must carry
for f in LICENSE NOTICE README.md CONTRIBUTING.md SECURITY.md; do
    git ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || finding "missing $f"
done

for doc in README.md CONTRIBUTING.md SECURITY.md; do
    [ -f "$doc" ] || continue
    while IFS= read -r link; do
        target=${link%%#*}
        target=${target#<}; target=${target%>}
        target=${target//%20/ }
        case $link in ''|'#'*|*://*|mailto:*) continue ;; esac
        [ -e "$(dirname "$doc")/$target" ] || finding "broken link in $doc: $link"
    done < <(grep -oE '\]\([^)]+\)' "$doc" | sed -E 's/^\]\(//; s/\)$//; s/[[:space:]]+"[^"]*"$//')
done

# Large files are a human's call, not a failure
while IFS= read -r f; do
    echo "NOTE over 500 KB: $f"
done < <(git ls-files -z | xargs -0 sh -c 'find "$@" -prune -type f -size +500k' sh 2>/dev/null | sed 's#^\./##')

# Secrets, in the tracked tree and in every commit
if ! command -v gitleaks >/dev/null 2>&1; then
    finding "gitleaks not installed (brew install gitleaks)"
else
    git checkout-index -a -f --prefix="$WORK/tree/"
    gitleaks dir --no-banner --redact -v "$WORK/tree" > "$WORK/leaks" 2>&1 \
        || finding "gitleaks in the tracked tree: $(cat "$WORK/leaks")"
    gitleaks git --no-banner --redact -v "$PWD" > "$WORK/leaks" 2>&1 \
        || finding "gitleaks in the history: $(cat "$WORK/leaks")"
fi

[ $FINDINGS -eq 0 ] && echo "ok   $DIR is ready to be public"
exit $FINDINGS
