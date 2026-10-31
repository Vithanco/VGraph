#!/usr/bin/env bash
# What a fresh public clone must be able to rely on in the task runner:
# a recipe that publishes under the maintainer's accounts refuses to start
# without the maintainer's say-so, and nothing personal is a default.
# The guard is for accidents (a contributor, or an agent, running
# `just publish-all`); the real protection is that publishing needs the
# maintainer's own logins.
set -uo pipefail

FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }

# Recipes in the publish group that need no guard: they build or stage locally
# and push nothing under anyone's account.
EXEMPT="stage-website deploy build-cloud-image-local"

unguarded=$(just --dump --dump-format json | EXEMPT="$EXEMPT" python3 -c '
import json, os, sys
exempt = set(os.environ["EXEMPT"].split())
for name, r in json.load(sys.stdin)["recipes"].items():
    in_publish = any(a.get("group") == "publish" for a in r.get("attributes", []) if isinstance(a, dict))
    deps = [d["recipe"] for d in r.get("dependencies", [])]
    if in_publish and name not in exempt and "_require-maintainer" not in deps:
        print(name)
')
[ -z "$unguarded" ] || fail "publish recipes without _require-maintainer: $(echo $unguarded)"

env -u VITHANCO_MAINTAINER just _require-maintainer >/dev/null 2>&1 \
    && fail "_require-maintainer passed without VITHANCO_MAINTAINER"
msg=$(env -u VITHANCO_MAINTAINER just _require-maintainer 2>&1 >/dev/null)
echo "$msg" | grep -q "VITHANCO_MAINTAINER" || fail "_require-maintainer does not name the variable that unlocks it"
VITHANCO_MAINTAINER=1 just _require-maintainer >/dev/null 2>&1 \
    || fail "_require-maintainer failed with VITHANCO_MAINTAINER=1"

# A contributor clones the plugins over https; the ssh alias only exists on one machine.
bad=$(python3 -c '
import json
for p in json.load(open("plugins.json"))["plugins"]:
    if p.get("repo") and not p["repo"].startswith("https://"):
        print(p["path"], p["repo"])
')
[ -z "$bad" ] || fail "plugins.json repo not cloneable over https: $bad"

# A clone without the plugin repos still builds and tests the engine: the plugins
# are separate repos, so they are built and linted when present and skipped when not.
# `build` leaves them out: a plugin bundles only the optimized wasm, which a debug
# `build` does not produce, so `plugins-build` and `release` build them.
EMPTY=$(mktemp -d)
trap 'rm -rf "$EMPTY"' EXIT
for recipe in plugins-build _plugin-lint-if-present; do
    out=$(just --justfile justfile --working-directory "$EMPTY" "$recipe" 2>&1) \
        || fail "$recipe fails when the plugin repos are absent"
    echo "$out" | grep -q "plugins-setup" || fail "$recipe does not say how to get the plugins"
done
# ...and builds them when they are there. The inner `just` finds the stub justfile in
# the working directory, so nothing real is built.
WITH=$(mktemp -d)
trap 'rm -rf "$EMPTY" "$WITH"' EXIT
mkdir "$WITH/obsidian-vithanco" "$WITH/vscode-vithanco"
printf 'config := "debug"\nobsidian-build:\n\t@echo BUILT obsidian\nvscode-build:\n\t@echo BUILT vscode\nobsidian-lint:\n\t@echo LINTED obsidian\n' > "$WITH/justfile"
out=$(just --justfile justfile --working-directory "$WITH" plugins-build 2>&1)
echo "$out" | grep -q "BUILT obsidian" && echo "$out" | grep -q "BUILT vscode" \
    || fail "plugins-build skips plugins that are cloned: $out"
out=$(just --justfile justfile --working-directory "$WITH" _plugin-lint-if-present 2>&1)
echo "$out" | grep -q "LINTED obsidian" || fail "_plugin-lint-if-present skips a cloned plugin: $out"

just --dump --dump-format json | python3 -c '
import json, sys
r = json.load(sys.stdin)["recipes"]
build = [d["recipe"] for d in r["build"]["dependencies"]]
for plugin in ("obsidian-build", "vscode-build", "plugins-build", "_plugins-if-present"):
    if plugin in build: print("build builds the plugins: " + plugin)
if "plugins-build" not in json.dumps(r["release"]["body"]): print("release does not build the plugins")
test = json.dumps(r["test"]["body"])
if "just obsidian-lint" in test: print("test lints the obsidian plugin unconditionally")
if "_plugin-lint-if-present" not in test: print("test does not lint the plugins that are present")
' | while read -r line; do fail "$line"; done

# `just doctor` is what a contributor runs first; gcloud only serves the maintainer's deploy.
grep -qE '^    have +gcloud' justfile && fail "doctor requires gcloud"

# A signing identity names a person's developer account; it comes from the environment.
grep -qE 'Developer ID Application: [^"]+\([A-Z0-9]{10}\)' justfile && fail "justfile defaults to a signing identity"

exit $FAILED
