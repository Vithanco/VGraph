#!/usr/bin/env bash
# Tag a VGraph release and start each plugin's build against it. The maintainer's
# own gh login starts them, so no cross-repository token has to live in CI.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=${1:-}
TAG="v$VERSION"
die() { echo "Error: $*" >&2; echo "Nothing was released." >&2; exit 1; }

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must be plain semver such as 1.2.3, got '$VERSION'"
[ "$(git branch --show-current)" = main ] || die "release from main"
[ -z "$(git status --porcelain)" ] || die "the working tree is not clean"
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse FETCH_HEAD)" ] || die "main differs from origin/main"
[ -z "$(git ls-remote --tags origin "refs/tags/$TAG")" ] || die "$TAG already exists on origin"

REPOS=$(node -e "
    for (const p of JSON.parse(require('fs').readFileSync('plugins.json', 'utf8')).plugins) {
        if (p.repo) console.log(p.repo.replace('https://github.com/', '').replace(/\.git\$/, ''));
    }
")
for repo in $REPOS; do
    gh workflow view ci.yml --repo "$repo" >/dev/null || die "$repo has no ci.yml workflow to start"
done

git tag "$TAG"
git push -q origin "refs/tags/$TAG"
echo "Pushed $TAG."

status=0
for repo in $REPOS; do
    args=(ci.yml --repo "$repo" -f "vgraph_ref=$TAG" -f "release_version=$VERSION")
    if gh workflow run "${args[@]}"; then
        echo "Started the build of $repo."
    else
        echo "Error: the build of $repo did not start. $TAG stands; start it with:" >&2
        echo "  gh workflow run ${args[*]}" >&2
        status=1
    fi
done
[ "$status" -eq 0 ] && echo "Each plugin opens a bump PR once it builds. After merging them: just plugins-pull, just release, just publish-plugins."
exit "$status"
