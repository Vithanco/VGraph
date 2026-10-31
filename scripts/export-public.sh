#!/usr/bin/env bash
# Makes the public repository: the tracked files of main, minus what is local to an
# agent, checked by audit-public.sh and the rules only VGraph has, proven to build
# and test as a clean clone, then committed once as the maintainer. Nothing of the
# old history travels. It never pushes; creating the repository and pushing is the
# maintainer's step.
#
# Usage: scripts/export-public.sh <target-dir>      (run inside the source repository)
#   VITHANCO_FORBIDDEN     passed on to audit-public.sh
#   VITHANCO_EXPORT_CHECK  clean-clone check run in the target (default: just doctor && just test)
# The report is written next to the target as <target-dir>-report.txt.
set -uo pipefail

TARGET=${1:?usage: export-public.sh <target-dir>}
TARGET=${TARGET%/}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CHECK=${VITHANCO_EXPORT_CHECK:-just doctor && just test}
MAINTAINER_NAME="Klaus Kneupner"
MAINTAINER_EMAIL="klaus@vithanco.com"
EXCLUDED=".claude .agents skills-lock.json"
CODE_DIRS="Sources Tests VGraphWasm vgraph-mcp-node scripts"

refuse() { echo "REFUSED $*" >&2; exit 1; }

SRC=$(git rev-parse --show-toplevel 2>/dev/null) || refuse "not inside a git repository"
cd "$SRC" || exit 1
[ -z "$(git status --porcelain)" ] || refuse "uncommitted changes in $SRC"
[ "$(git branch --show-current)" = main ] || refuse "HEAD is not on main"
if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET")" ]; then refuse "$TARGET exists and is not empty"; fi

mkdir -p "$TARGET"
TARGET=$(cd "$TARGET" && pwd)
REPORT="$TARGET-report.txt"
: > "$REPORT"
FAILED=0
say() { echo "$*" | tee -a "$REPORT"; }
fail() { say "FAIL $*"; FAILED=1; }

say "source: $SRC at $(git rev-parse HEAD)"
git archive HEAD | tar -x -C "$TARGET"
for path in $EXCLUDED; do
    while IFS= read -r f; do say "excluded: $f"; done < <(git ls-files -- "$path")
    rm -rf "${TARGET:?}/$path"
done

cd "$TARGET" || exit 1
tree_grep() { # grep args...: over every exported text file, file:line:text
    find . -type f -print0 | xargs -0 grep -InH "$@" -- 2>/dev/null | sed 's#^\./##'
}

# Apple's icon set, which VGraph does not ship. Three places name it on purpose. Assembled so
# this file does not match itself.
SFS="SF Sym""bol"
while IFS= read -r m; do
    case $m in
        CONTEXT.md:*|docs/VGL_GUIDE.md:*|docs/adr/0022-*) say "allowed $SFS: $m" ;;
        *) fail "$SFS: $m" ;;
    esac
done < <(tree_grep -F "$SFS")

# OLD-N is history, kept in docs and ADRs; in code a number goes stale.
for d in $CODE_DIRS; do
    [ -d "$d" ] || continue
    while IFS= read -r m; do fail "old issue number in code: $m"; done \
        < <(tree_grep -E 'OLD-[0-9]+' | grep -E "^$d/")
done

git init -q -b main
git add -A
GIT_AUTHOR_NAME=$MAINTAINER_NAME GIT_AUTHOR_EMAIL=$MAINTAINER_EMAIL \
GIT_COMMITTER_NAME=$MAINTAINER_NAME GIT_COMMITTER_EMAIL=$MAINTAINER_EMAIL \
    git -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -q --no-verify -m "VGraph" \
    || fail "could not commit"

if ! out=$("$HERE/audit-public.sh" "$TARGET" 2>&1); then
    say "$out"
    fail "audit-public.sh found problems in the exported tree"
else
    say "$out"
fi

if [ $FAILED -eq 0 ]; then
    if sh -c "$CHECK" >> "$REPORT" 2>&1; then say "ok   clean-clone check: $CHECK"
    else fail "clean-clone check failed: $CHECK (output in $REPORT)"; fi
fi

if [ $FAILED -ne 0 ]; then
    rm -rf "$TARGET/.git"
    say "export failed; the tree is left in $TARGET without a commit"
    exit 1
fi
say "ok   one commit in $TARGET; review $REPORT, then push by hand"
