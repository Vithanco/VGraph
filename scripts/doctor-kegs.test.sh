#!/usr/bin/env bash
# wabt and binaryen both ship `wasm2c`, so Homebrew links one and leaves the
# other's tools installed but off PATH. build-wasm.sh finds them in their kegs;
# `just doctor` must too, or it tells every contributor with both installed that
# wasm-strip is missing while the release build works.
set -uo pipefail

FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }

JUST=$(command -v just)
STUB=$(mktemp -d)
trap 'rm -rf "$STUB"' EXIT
mkdir -p "$STUB/bin" "$STUB/wabt/bin"
printf '#!/bin/sh\n[ "$1 $2" = "--prefix wabt" ] && echo "%s"\n[ "$1 $2" = "--prefix binaryen" ] && echo "%s/none"\nexit 0\n' \
    "$STUB/wabt" "$STUB" > "$STUB/bin/brew"
printf '#!/bin/sh\necho fake\n' > "$STUB/wabt/bin/wasm-strip"
chmod +x "$STUB/bin/brew" "$STUB/wabt/bin/wasm-strip"

# A PATH with nothing but the system tools, so the host's own installs cannot answer for us.
without=$(PATH="/usr/bin:/bin" "$JUST" doctor 2>&1)
echo "$without" | grep -q "❌ wasm-strip" || fail "control: wasm-strip should be missing on a bare PATH"

with=$(PATH="$STUB/bin:/usr/bin:/bin" "$JUST" doctor 2>&1)
echo "$with" | grep -q "✅ wasm-strip" || fail "doctor ignores a tool that is installed in its keg but not linked"

# One place knows how to look, and the release build uses it.
[ -f scripts/brew-kegs.sh ] || fail "scripts/brew-kegs.sh is missing"
grep -q "brew-kegs.sh" build-wasm.sh || fail "build-wasm.sh does not use scripts/brew-kegs.sh"

exit $FAILED
