#!/usr/bin/env bash
# Push vscode-vithanco's packaged .vsix to the Marketplace when a credential is
# reachable; otherwise say how to finish by hand. A version the Marketplace
# already has is skipped, so a resumed release can run this again.
#
#   scripts/vscode-marketplace.sh                   # push, or explain
#   scripts/vscode-marketplace.sh --has-credential  # exit 0 when one is reachable
#
# The Marketplace may have no automated credential. vsce needs a PAT; the
# alternative Microsoft offers is Entra workload identity federation, which is
# CI-only and so no use to a release run from a laptop. Uploading the .vsix
# through the publisher portal is a perfectly good third option, and it is what
# shipped 1.0.8. A release that fails at the last step because of an auth method
# we chose not to adopt would be worse than one that tells you to drag a file.
set -euo pipefail

cd vscode-vithanco
PUBLISHER=$(node -p "require('./package.json').publisher")

# Cheapest first. `vsce verify-pat` is the real proof, but it has to read the
# secret out of the keychain, and a process without a TTY is not granted that —
# so it reports "no credential" for a developer who is perfectly well logged in.
# The keychain *entry* can be seen without unlocking it, which is the signal
# that survives both contexts. None of these prove the token is still valid: an
# expired one fails at the publish itself.
has_credential() {
    [ -n "${VSCE_PAT:-}" ] \
        || security find-generic-password -s vscode-vsce -a "$PUBLISHER" >/dev/null 2>&1 \
        || npx vsce verify-pat "$PUBLISHER" >/dev/null 2>&1
}

if [ "${1:-}" = --has-credential ]; then
    has_credential
    exit
fi

V=$(node -p "require('./package.json').version")
ID=$(node -p "const p = require('./package.json'); p.publisher + '.' + p.name")
VSIX="vithanco-$V.vsix"

LISTED=$(npx vsce show "$ID" --json 2>/dev/null \
    | node -e 'let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
          try { console.log(JSON.parse(s).versions[0].version); } catch { }
      })' || true)
if [ "$LISTED" = "$V" ]; then
    echo "· VS Code Marketplace already has $V — skipping"
    exit 0
fi

if has_credential; then
    npx vsce publish --packagePath "$VSIX" --no-dependencies
    echo "✓ VS Code Marketplace at $V"
else
    echo "VS Code Marketplace → NOT PUBLISHED: no credential (VSCE_PAT, or 'npx vsce login $PUBLISHER')."
    echo "  Upload vscode-vithanco/$VSIX at"
    echo "  https://marketplace.visualstudio.com/manage/publishers/$PUBLISHER"
    echo "  or, with a credential: just publish-vscode-marketplace"
fi
