# VGraph task runner — the single front door to this repo.
#
#   The command ladder (each rung includes the one below):
#     build    → compile the engine (WASM, cli, mcp), NO tests, NO plugins
#     test     → build + swift test + wasm smoke + editor browser tests + plugin lint
#     release  → test + optimized WASM + plugins + release binaries + .vsix  (nothing pushed)
#
#   The plugins bundle only the optimized WASM, which `build` does not make, so
#   `plugins-build` and `release` build them.
#     publish-*→ actually ship one target (outward-facing / irreversible)
#
#   `release` is the safety line: reproducible and reversible. Everything below
#   `publish-*` leaves the building, and refuses to start unless
#   VITHANCO_MAINTAINER=1 is set: publishing needs the maintainer's own logins
#   anyway, so the guard only stops accidents.
#
# Run `just` (no args) for the full menu.

set positional-arguments

# ── Overridable variables ───────────────────────────────────────────────────
# Build configuration: "debug" (default, fast) or "release" (optimized).
# `just release` sets this to release for the whole build; override directly with
# e.g. `just config=release build`.
config        := "debug"
# Where the Vithanco Publish website lives (used by `stage-website`).
website_dir   := env_var_or_default("VITHANCO_WEBSITE_DIR", justfile_directory() / "../VithancoWebsite")
# Where the legacy-document converter lives (used by the `converter-*` recipes).
converter_dir := env_var_or_default("VITHANCO_CONVERTER_DIR", justfile_directory() / "../vithancoDataModel")
# Signing identity and notarisation profile for the converter's release binary.
# No defaults: they name a developer account, so the maintainer sets them.
signing_id     := env_var_or_default("VITHANCO_SIGNING_ID", "")
notary_profile := env_var_or_default("VITHANCO_NOTARY_PROFILE", "")
# Cloud Run image / region / service (used by the cloud recipes).
cloud_image   := env_var_or_default("VGRAPH_CLOUD_IMAGE", "europe-west1-docker.pkg.dev/vgraph-mcp/cloud-run-source-deploy/vgraph-mcp-http")
cloud_region  := env_var_or_default("VGRAPH_CLOUD_REGION", "europe-west1")
cloud_service := env_var_or_default("VGRAPH_CLOUD_SERVICE", "vgraph-mcp")

# Default: show the menu.
default:
    @just --list

# ═══════════════════════════════════════════════════════════════════════════
# Build / test / release (decomposed from the old build.sh monolith)
# ═══════════════════════════════════════════════════════════════════════════

# Compile the engine (WASM + cli + mcp) in {{config}} config. No tests, no plugins (see plugins-build).
[group('build')]
build: _wasm-build cli mcp
    @echo "✓ build complete ({{config}}, no tests)"

# Build the plugins that are cloned (they need the optimized WASM: `just config=release plugins-build`). A clone without them skips.
[group('build')]
plugins-build:
    #!/usr/bin/env bash
    set -euo pipefail
    for pair in obsidian-vithanco:obsidian-build vscode-vithanco:vscode-build; do
        dir=${pair%%:*}; recipe=${pair##*:}
        if [ -d "$dir" ]; then
            just config={{config}} "$recipe"
        else
            echo "· skipping $recipe: $dir/ is not cloned (just plugins-setup)"
        fi
    done

_plugin-lint-if-present:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -d obsidian-vithanco ]; then
        just obsidian-lint
    else
        echo "· skipping obsidian-lint: obsidian-vithanco/ is not cloned (just plugins-setup)"
    fi

# Build + deploy the WASM package. FLAGS: --release / --use-cdn / --skip-smoke.
[group('build')]
wasm *flags:
    ./build-wasm.sh {{flags}}

# Internal: WASM build for `build` (no smoke tests here; `--release` when config=release).
_wasm-build:
    ./build-wasm.sh --skip-smoke {{ if config == "release" { "--release" } else { "" } }}

# Build the native CLI. FLAGS: --release.
[group('build')]
cli *flags:
    swift build --product vgraph-cli -c {{ if flags == "" { config } else if flags == "--release" { "release" } else { error("unknown flag: " + flags + " (only --release)") } }}

# Rebuild fonts/ — the DM Sans faces the rasterisers need.
[group('build')]
fonts:
    # Rarely needed: only when the charset or the set of weights changes. Fetches
    # from Google Fonts, so it needs network, and it rewrites committed binaries.
    ./scripts/build-fonts.sh

# Build the native MCP server. FLAGS: --release.
[group('build')]
mcp *flags:
    swift build --product vgraph-mcp -c {{ if flags == "" { config } else if flags == "--release" { "release" } else { error("unknown flag: " + flags + " (only --release)") } }}

# Assemble the Node MCP host: vendor the engine + fonts, refresh tools.json.
[group('build')]
mcp-node: mcp
    #!/usr/bin/env bash
    set -euo pipefail
    # Always release, regardless of `config`. This vendors what npm publishes,
    # and the debug module is 78MB against 4.1MB — `just mcp-node` with the
    # default config would otherwise quietly build a package nobody should ship.
    ./build-wasm.sh --release --skip-smoke
    # Vendored rather than committed: the wasm is 4.1MB, and a copy in git is a
    # copy that can disagree with the engine it was built from. Same reason the
    # plugins re-copy it from website/Package on every build.
    rm -rf vgraph-mcp-node/vendor
    mkdir -p vgraph-mcp-node/vendor
    cp -R website/Package vgraph-mcp-node/vendor/Package
    cp -R fonts vgraph-mcp-node/vendor/fonts
    # Belt and braces: the line above asks for release, this catches the day
    # someone changes it back.
    WASM_BYTES=$(wc -c < vgraph-mcp-node/vendor/Package/VGraphWasm.wasm)
    if [ "$WASM_BYTES" -gt 20000000 ]; then
        echo "Error: vendored wasm is $WASM_BYTES bytes — that is a debug build." >&2
        exit 1
    fi
    ./scripts/dump-mcp-tools.sh
    echo "✓ vgraph-mcp-node vendored ($(du -sh vgraph-mcp-node/vendor | cut -f1))"

# Run the Node MCP host against the current engine build (stdio; Ctrl-C to stop).
[group('run')]
mcp-node-run: mcp-node
    cd vgraph-mcp-node && [ -d node_modules ] || npm install --silent; node src/server.mjs

# Publish the Node MCP host to npm, then list it in the MCP Registry.
[group('publish')]
publish-mcp-node otp='': _require-maintainer mcp-node
    #!/usr/bin/env bash
    set -euo pipefail
    cd vgraph-mcp-node
    PKG=$(node -p "require('./package.json').name")
    VER=$(node -p "require('./package.json').version")

    # Preflight: everything that can fail, before anything is published. An npm
    # version cannot be re-published once taken, so discovering a problem
    # halfway through leaves a burnt version number behind.
    FAIL=0

    if ! npm whoami >/dev/null 2>&1; then
        echo "Preflight: not logged in to npm — run 'npm login'." >&2
        FAIL=1
    fi

    # Not a failure: npm and the registry are two publishes, and the first run
    # got npm out and then died on an expired registry token. Aborting here
    # would have made the recipe unable to finish its own half-done work.
    NPM_DONE=0
    if npm view "$PKG@$VER" version >/dev/null 2>&1; then
        NPM_DONE=1
    fi

    # The registry verifies a server by matching `mcpName` in the *published*
    # package against the name in server.json. Getting this wrong is only
    # discoverable after npm has taken the version.
    MCP_NAME=$(node -p "require('./package.json').mcpName || ''")
    SRV_NAME=$(node -p "require('./server.json').name")
    SRV_VER=$(node -p "require('./server.json').version")
    SRV_PKG_VER=$(node -p "require('./server.json').packages[0].version")
    if [ "$MCP_NAME" != "$SRV_NAME" ]; then
        echo "Preflight: package.json mcpName ($MCP_NAME) != server.json name ($SRV_NAME)." >&2
        FAIL=1
    fi
    if [ "$SRV_VER" != "$VER" ] || [ "$SRV_PKG_VER" != "$VER" ]; then
        echo "Preflight: server.json versions ($SRV_VER / $SRV_PKG_VER) != package.json ($VER)." >&2
        FAIL=1
    fi

    # `just mcp-node` ran above, so these should hold — they catch someone
    # publishing from a tree where it half-failed.
    WASM="vendor/Package/VGraphWasm.wasm"
    if [ ! -f "$WASM" ]; then
        echo "Preflight: $WASM missing — 'just mcp-node' did not complete." >&2
        FAIL=1
    elif [ "$(wc -c < "$WASM")" -gt 20000000 ]; then
        echo "Preflight: $WASM is a debug build." >&2
        FAIL=1
    fi
    if [ ! -s tools.json ] || [ "$(node -p "require('./tools.json').length")" -eq 0 ]; then
        echo "Preflight: tools.json is empty — scripts/dump-mcp-tools.sh did not run." >&2
        FAIL=1
    fi
    # OFL 1.1 requires the licence ship with the fonts.
    if [ ! -f vendor/fonts/OFL.txt ]; then
        echo "Preflight: vendor/fonts/OFL.txt missing — the fonts must not ship without it." >&2
        FAIL=1
    fi

    if [ "$FAIL" -ne 0 ]; then
        echo "" >&2
        echo "Nothing was published." >&2
        exit 1
    fi

    if [ "$NPM_DONE" -eq 1 ]; then
        echo "· $PKG@$VER already on npm — skipping, going straight to the registry"
    else
        echo "Publishing $PKG@$VER to npm..."
        # npm requires 2FA or a granular token with 2FA bypass to publish,
        # whatever the account's own tfa setting says. With a granular token no
        # OTP is needed; with account 2FA one is, and it must be supplied at the
        # moment of use because it expires in seconds.
        if [ -n "{{otp}}" ]; then
            npm publish --access public --otp="{{otp}}"
        else
            npm publish --access public
        fi
    fi

    echo ""
    if ! command -v mcp-publisher >/dev/null 2>&1; then
        echo "✓ Published to npm. mcp-publisher not installed, so the registry entry"
        echo "  was skipped — 'brew install mcp-publisher', then:"
        echo "    cd vgraph-mcp-node && mcp-publisher login dns --domain vithanco.com && mcp-publisher publish"
        exit 0
    fi
    # The registry JWT is short-lived — the first real run logged in, spent
    # several minutes building and publishing to npm, and then failed with
    # "token is expired". So re-authenticate here, immediately before use,
    # rather than relying on a session from earlier.
    #
    # DNS auth, not GitHub: it is what earns the com.vithanco namespace rather
    # than io.github.vithanco.
    KEY="${MCP_SIGNING_KEY:-$HOME/.config/mcp-publisher/vithanco-ed25519.pem}"
    if [ -f "$KEY" ]; then
        echo "Refreshing the registry token..."
        mcp-publisher login dns --domain vithanco.com \
            --private-key "$(openssl pkey -in "$KEY" -outform DER | tail -c 32 | xxd -p -c 64)"
    else
        echo "· no signing key at $KEY — using whatever session mcp-publisher holds."
        echo "  (set MCP_SIGNING_KEY if it lives elsewhere)"
    fi

    echo "Publishing to the MCP Registry as $SRV_NAME..."
    mcp-publisher publish
    echo "✓ $PKG@$VER on npm and listed as $SRV_NAME"

# build + run the full test suite (format + swift + wasm smoke + editor browser + plugin lint). FILTER scopes swift test.
[group('test')]
test filter='': build
    just lint
    swift test {{ if filter == "" { "" } else { "--filter " + filter } }}
    just test-wasm
    just test-editor
    just plugin-api
    ./scripts/check-wasm-optimized.test.sh
    ./scripts/justfile-hygiene.test.sh
    ./scripts/doctor-kegs.test.sh
    ./scripts/doctor-sdk.test.sh
    ./scripts/codeowners.test.sh
    ./scripts/licence.test.sh
    ./scripts/audit-public.test.sh
    ./scripts/export-public.test.sh
    just _plugin-lint-if-present

# Node WASM smoke tests (vitest) against the deployed website/Package.
[group('test')]
test-wasm:
    cd VGraphWasm/Tests-JS && [ -d node_modules ] || npm install --silent; npm test

# Editor browser tests (Playwright) against the deployed website/. FILTER is a -g pattern.
[group('test')]
test-editor filter='':
    #!/usr/bin/env bash
    # A real browser, not jsdom: the inline label editor is positioned from
    # getBoundingClientRect and, for edges, getScreenCTM — jsdom has neither.
    # See VGraphWasm/Tests-Browser/README.md.
    set -euo pipefail
    cd VGraphWasm/Tests-Browser
    [ -d node_modules ] || npm install --silent
    npx playwright install --with-deps chromium >/dev/null
    npx playwright test {{ if filter == "" { "" } else { "-g " + quote(filter) } }}

# Fail on any formatting deviation. `--strict` is load-bearing: without it the
# linter prints its warnings and still exits 0, so nothing would ever go red.
[group('test')]
lint:
    swift format lint -r --strict --configuration .swift-format \
        Sources Tests VGraphWasm/Sources VGraphWasm/VGraphEditor

# Format all Swift sources in place — what to run when `just lint` goes red.
[group('test')]
format:
    swift-format -r -i --configuration .swift-format .

# test + produce all shippable artifacts (optimized WASM, release binaries, .vsix). Nothing is pushed.
[group('build')]
release: (_require-plugin "obsidian-vithanco") (_require-plugin "vscode-vithanco")
    #!/usr/bin/env bash
    set -euo pipefail
    # Run the full build+test gate in RELEASE config (optimized WASM flows into the
    # plugins via the binary embed), then package the .vsix. Single build — no debug detour.
    just config=release test
    just config=release plugins-build
    ( cd vscode-vithanco && npm run package --silent )
    echo ""
    echo "✓ release artifacts ready (nothing pushed)."
    echo ""
    # `release` builds the CURRENT version — it never bumps. If that version is
    # already tagged, publish-plugins cannot run, so say which step comes next
    # rather than always naming publish and letting it fail.
    V=$(node -p "require('./obsidian-vithanco/manifest.json').version" 2>/dev/null || echo "")
    if [ -n "$V" ] && git -C obsidian-vithanco rev-parse -q --verify "refs/tags/$V" >/dev/null 2>&1; then
        echo "  v$V is already published — bump before publishing:"
        echo "    just plugins-release patch     # -> next version, rebuilds main.js + .vsix"
        echo "    just publish-plugins           # tag + push + GitHub releases"
    else
        echo "  just publish-plugins             # tag + push + GitHub releases at v$V"
    fi
    echo "    just publish-cloud-run / just stage-website"

# Bump the JS library version: set it in website/dist/package.json and sync all filenames/refs.
[group('build')]
bump-js version:
    #!/usr/bin/env bash
    # Lifted out of the old build.sh — run this consciously per JS-lib bump,
    # not on every build. Source of truth: website/dist/package.json "version".
    set -euo pipefail
    NEW="{{version}}"
    if ! [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: version must be semver (e.g. 1.2.0), got '$NEW'" >&2
        exit 1
    fi
    OLD=$(node -p "require('./website/dist/package.json').version")
    # The library embeds the Apache-2.0 engine: LICENSE and NOTICE ship with it.
    cp LICENSE NOTICE website/dist/
    # Write the new version into dist/package.json.
    node -e "const fs=require('fs');const p=require('./website/dist/package.json');p.version='$NEW';fs.writeFileSync('./website/dist/package.json',JSON.stringify(p,null,2)+'\n');"
    if [ "$OLD" = "$NEW" ]; then
        echo "JS library already at v$NEW — nothing to rename."
        exit 0
    fi
    echo "JS version bump: $OLD → $NEW"
    mv "website/dist/vgraph-v${OLD}.js" "website/dist/vgraph-v${NEW}.js"
    sed -i '' "s/Version: ${OLD}/Version: ${NEW}/g" "website/dist/vgraph-v${NEW}.js"
    sed -i '' "s/version: '${OLD}'/version: '${NEW}'/g" "website/dist/vgraph-v${NEW}.js"
    sed -i '' "s/\"vgraph-v${OLD}/\"vgraph-v${NEW}/g" website/dist/package.json
    if [ -f "website/dist/vgraph-v${OLD}.d.ts" ]; then
        mv "website/dist/vgraph-v${OLD}.d.ts" "website/dist/vgraph-v${NEW}.d.ts"
    fi
    echo "  Updated: vgraph-v${NEW}.js/.d.ts, package.json"

# Clean Swift build artifacts (root + VGraphWasm).
clean:
    swift package clean
    cd VGraphWasm && swift package clean

# ═══════════════════════════════════════════════════════════════════════════
# Run / dev
# ═══════════════════════════════════════════════════════════════════════════

# Run the native CLI (pass args after --, e.g. `just run-cli -- --help`).
[group('run')]
run-cli *args:
    VGRAPH_LOG_LEVEL=debug swift run vgraph-cli {{args}}

# Run the native MCP server.
[group('run')]
run-mcp:
    VGRAPH_LOG_LEVEL=debug swift run vgraph-mcp

# Serve website/ locally for manual preview (ES modules need a real server).
[group('run')]
serve port='8000':
    cd website && python3 -m http.server {{port}}

# Inner loop: rebuild WASM once, then watch-build the Obsidian plugin.
[group('run')]
dev: _wasm-build
    cd obsidian-vithanco && npm run dev

# Build the LOCAL release MCP binary for Claude Desktop (distinct from the cloud image).
[group('run')]
local-server:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Formatting VGraphMCP..."
    swift-format -r -i --configuration .swift-format Sources/VGraphMCP
    echo "Running MCP server tests..."
    swift test --filter VGraphMCPTests
    echo "Building vgraph-mcp (release)..."
    swift build --product vgraph-mcp -c release
    echo ""
    echo "✓ Binary: .build/release/vgraph-mcp"
    ls -lh .build/release/vgraph-mcp | awk '{print "  " $5 " - " $9}'
    echo "  Quit & relaunch Claude Desktop to reload the server."

# ═══════════════════════════════════════════════════════════════════════════
# Plugins (separate git repos, driven by plugins.json)
# ═══════════════════════════════════════════════════════════════════════════

# Clone any missing plugin repos listed in plugins.json.
[group('plugins')]
plugins-setup:
    ./setup-plugins.sh

# git pull existing plugin repos (and clone missing ones).
[group('plugins')]
plugins-pull:
    ./setup-plugins.sh --pull

# Bump + rebuild every engine consumer. BUMP: patch|minor|major or an explicit version. PLUGIN: optional path.
[group('plugins')]
plugins-release bump='patch' plugin='':
    #!/usr/bin/env bash
    set -euo pipefail
    # `patch`/`minor`/`major` are flags to the driver; an explicit version is a
    # bare argument. Normalising here means `just plugins-release 1.2.0` works
    # as well as `just plugins-release minor`, without anyone needing to know
    # release-plugins.sh exists.
    case "{{bump}}" in
        patch|minor|major) ARG="--{{bump}}" ;;
        *)                 ARG="{{bump}}" ;;
    esac
    ./release-plugins.sh "$ARG" {{plugin}}

# Internal: fail with a helpful hint if a plugin repo isn't cloned.
_require-plugin name:
    #!/usr/bin/env bash
    if [ ! -d "{{name}}" ]; then
        echo "Error: {{name}}/ not found — run 'just plugins-setup' to clone it." >&2
        exit 1
    fi

[group('plugins')]
obsidian-build: (_require-plugin "obsidian-vithanco")
    cd obsidian-vithanco && npm run build

[group('plugins')]
obsidian-dev: (_require-plugin "obsidian-vithanco")
    cd obsidian-vithanco && npm run dev

[group('plugins')]
obsidian-lint: (_require-plugin "obsidian-vithanco")
    cd obsidian-vithanco && npm run lint

[group('plugins')]
vscode-build: (_require-plugin "vscode-vithanco")
    cd vscode-vithanco && npm run build

[group('plugins')]
vscode-watch: (_require-plugin "vscode-vithanco")
    cd vscode-vithanco && npm run watch

[group('plugins')]
vscode-package: (_require-plugin "vscode-vithanco")
    cd vscode-vithanco && npm run package

# Every `exports.X` the plugins call must still be an @JS function in the engine.
# `parity` compares the plugins to each other; this compares them to the engine,
# which is the direction a removed export actually breaks. Skips absent plugins.
[group('test')]
plugin-api:
    ./scripts/check-plugin-api.sh

# Review aid (NOT a gate): diff the shared render core between the two plugins.
[group('plugins')]
parity: (_require-plugin "obsidian-vithanco") (_require-plugin "vscode-vithanco")
    #!/usr/bin/env bash
    set -uo pipefail
    OBS=obsidian-vithanco/src/vgraph-loader.ts
    VSC=vscode-vithanco/src/renderer.ts
    # Extract the marked region, then normalise away the legitimate differences:
    # left-trim each line (the two blocks sit at different nesting depths) and
    # drop blank + full-line-comment lines (comments re-wrap differently). What
    # remains is the actual code, so a diff flags real logic drift only.
    norm() {
        awk '/BEGIN SHARED CORE/{f=1;next} /END SHARED CORE/{f=0} f' "$1" \
            | sed -E 's/^[[:space:]]+//' \
            | grep -vE '^(//|$)'
    }
    a=$(norm "$OBS"); b=$(norm "$VSC")
    if [ -z "$a" ] || [ -z "$b" ]; then
        echo "Error: SHARED CORE markers not found in one of the plugin files." >&2
        echo "  Wrap the shared render block in '// BEGIN SHARED CORE' / '// END SHARED CORE' in both:" >&2
        echo "    $OBS" >&2
        echo "    $VSC" >&2
        exit 2
    fi
    if diff <(echo "$a") <(echo "$b") >/dev/null; then
        echo "✓ parity OK — the shared render core is identical in both plugins (ignoring indentation/comments)."
    else
        echo "⚠ DRIFT — the shared render core differs between the plugins:"
        echo "  (< $OBS   > $VSC)"
        diff <(echo "$a") <(echo "$b") || true
        exit 1
    fi

# ═══════════════════════════════════════════════════════════════════════════
# Publish (outward-facing — the only irreversible recipes)
# ═══════════════════════════════════════════════════════════════════════════

# Commit + push + tag + GitHub release for BOTH plugins (parity-guarded). Stops before the marketplace.
[group('publish')]
publish-plugins: _require-maintainer (_require-plugin "obsidian-vithanco") (_require-plugin "vscode-vithanco")
    #!/usr/bin/env bash
    set -euo pipefail
    OBS_V=$(node -p "require('./obsidian-vithanco/manifest.json').version")
    VSC_V=$(node -p "require('./vscode-vithanco/package.json').version")
    if [ "$OBS_V" != "$VSC_V" ]; then
        echo "Parity guard: plugin versions differ (obsidian $OBS_V vs vscode $VSC_V)." >&2
        echo "Run 'just plugins-release <bump>' to bump both together first." >&2
        exit 1
    fi
    # Preflight: every check that can fail, before anything is mutated. Without
    # this the recipe discovers problems halfway through — and since Obsidian is
    # published first, a late failure leaves one plugin released and the other not.
    FAIL=0
    for spec in "obsidian-vithanco:main.js" "vscode-vithanco:vithanco-${OBS_V}.vsix"; do
        DIR=${spec%%:*}; ASSET=${spec#*:}
        if git -C "$DIR" rev-parse -q --verify "refs/tags/$OBS_V" >/dev/null; then
            echo "Preflight: $DIR already has tag $OBS_V — bump before publishing." >&2
            FAIL=1
        fi
        if gh release view "$OBS_V" --repo "Vithanco/$DIR" >/dev/null 2>&1; then
            echo "Preflight: $DIR already has a GitHub release $OBS_V." >&2
            FAIL=1
        fi
        if [ ! -f "$DIR/$ASSET" ]; then
            echo "Preflight: $DIR/$ASSET is missing — run 'just plugins-release <bump>' to build it." >&2
            FAIL=1
        fi
    done
    # A debug engine is ~20x oversized. Check the copy each plugin embeds, not
    # just website/Package: that is what shipped as a 115 MB main.js in 1.0.9.
    ./scripts/check-wasm-optimized.sh website/Package/VGraphWasm.wasm \
        obsidian-vithanco/VGraphWasm.wasm vscode-vithanco/VGraphWasm.wasm || FAIL=1
    # main.js carries the engine as base64 (~4/3), so this also catches a bundle
    # built before the engine was replaced.
    MAIN_BYTES=$(wc -c < obsidian-vithanco/main.js)
    if [ "$MAIN_BYTES" -gt 30000000 ]; then
        echo "Preflight: obsidian-vithanco/main.js is $MAIN_BYTES bytes — built from a debug engine. Rebuild it." >&2
        FAIL=1
    fi
    if [ "$FAIL" -ne 0 ]; then
        echo "" >&2
        echo "Nothing was published." >&2
        exit 1
    fi

    echo "Publishing both plugins at v$OBS_V (GitHub releases; marketplace stays manual)."
    echo ""
    # Obsidian
    ( cd obsidian-vithanco
      # main.js is gitignored in this repo — it ships as a GitHub release asset (below), not a commit.
      git add manifest.json package.json versions.json styles.css VGraphWasm.wasm
      git commit -m "chore: release $OBS_V"
      git tag "$OBS_V"
      git push origin HEAD "$OBS_V"
      gh release create "$OBS_V" --title "$OBS_V" --notes "Release $OBS_V" main.js manifest.json styles.css )
    # VS Code
    ( cd vscode-vithanco
      VSIX="vithanco-${VSC_V}.vsix"
      # package.json only: unlike the Obsidian plugin, this repo gitignores
      # VGraphWasm.wasm, and `git add` on an ignored path exits non-zero — which
      # aborted the whole recipe under `set -e`, after Obsidian had already
      # published. The engine ships to users inside the .vsix asset below.
      git add package.json
      git commit -m "chore: release $VSC_V"
      git tag "$VSC_V"
      git push origin HEAD "$VSC_V"
      gh release create "$VSC_V" --title "$VSC_V" --notes "Release $VSC_V" "$VSIX" )
    echo ""
    echo "✓ Plugins pushed + tagged + GitHub releases created at v$OBS_V."
    echo ""
    # The two plugins distribute differently, and conflating them is why the
    # marketplace step gets missed: Obsidian reads the GitHub release, so it is
    # finished here. VS Code does not — the release is only an attached .vsix.
    echo "  Obsidian  → DONE. Clients update from the GitHub release."
    echo "  VS Code   → NOT PUBLISHED YET. The release only attaches the .vsix;"
    echo "              the Marketplace needs its own push:"
    echo ""
    echo "                just publish-vscode-marketplace     # irreversible"

# Publish the VS Code extension to the Marketplace (irreversible; needs a publisher token).
[group('publish')]
publish-vscode-marketplace: _require-maintainer (_require-plugin "vscode-vithanco")
    #!/usr/bin/env bash
    set -euo pipefail
    V=$(node -p "require('./vscode-vithanco/package.json').version")
    cd vscode-vithanco && npx vsce publish --packagePath "vithanco-${V}.vsix" --no-dependencies

# Stage the JS dist into the VithancoWebsite repo, then print the manual finish steps.
[group('publish')]
stage-website:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{website_dir}}" ]; then
        echo "Error: website dir '{{website_dir}}' not found." >&2
        echo "  Set VITHANCO_WEBSITE_DIR or pass it: just website_dir=/path stage-website" >&2
        exit 1
    fi
    # deploy.sh already copies the docs (README, VGL_GUIDE).
    ./deploy.sh "{{website_dir}}/Resources/vgraph" --absolute-path "/vgraph/Package" \
        --canonical "https://vithanco.com/editor/"
    echo ""
    echo "Staged into {{website_dir}}/Resources/vgraph. Finish in the website repo:"
    echo "    cd {{website_dir}} && swift run    # preview, then deploy as usual"

# Stage, generate and deploy the website, then commit the staged engine.
[group('publish')]
publish-website: _require-maintainer stage-website
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v publish >/dev/null 2>&1; then
        echo "Error: the Publish CLI is not on PATH — the website cannot be generated." >&2
        exit 1
    fi
    VER=$(node -p "require('./plugins.json').plugins[0].version")
    REPO="$(pwd)"
    cd "{{website_dir}}"

    # `publish deploy` pushes Output/ to Vithanco/vithanco.github.io (see
    # Sources/Vithanco/main.swift). That is what makes the site live; the commit
    # below is the source repo's own record of what changed.
    #
    # VGRAPH_REPO is required: the site renders `vgl-render` blocks at build
    # time by calling this engine, and generation aborts outright without it.
    VGRAPH_REPO="$REPO" publish generate
    publish deploy

    # Scoped deliberately. The repo's push.sh does `git add .`, which right now
    # would sweep .agents/, .claude/skills/ and skills-lock.json into the
    # website repo. Only the staged engine and the prose belong here.
    git add Resources/vgraph Content
    if git diff --cached --quiet; then
        echo "Nothing staged changed — no commit."
    else
        git commit -m "content: site update, engine at v$VER"
        git push origin main
    fi
    echo "✓ website generated, deployed, and committed"

# Generic deploy of the dist to any target dir. FLAGS: --absolute-path <p>.
[group('publish')]
deploy target *flags:
    ./deploy.sh {{target}} {{flags}}

# Build the linux/amd64 image on Cloud Build + push it (no local Docker needed).
[group('publish')]
build-cloud-image: _require-maintainer _require-gcloud
    #!/usr/bin/env bash
    set -euo pipefail
    # Built remotely because Cloud Run is x86_64-only and this is an ARM Mac: a
    # local build must emulate amd64, and the Swift compiler dies under QEMU with
    # SIGILL partway through. Cloud Build is native amd64 — no emulation, no
    # Rosetta, no Docker. Use build-cloud-image-local if you want a local image.
    echo "=== Building {{cloud_service}} on Cloud Build (native linux/amd64) ==="
    # --tag builds AND pushes, so publish-cloud-run needs no separate docker push.
    # Upload honours .gcloudignore.
    gcloud builds submit --tag "{{cloud_image}}" .
    echo ""
    echo "✓ built and pushed {{cloud_image}}"

# Fallback: build the image locally with Docker instead of on Cloud Build.
[group('publish')]
build-cloud-image-local:
    #!/usr/bin/env bash
    set -euo pipefail
    # Needs an amd64-capable builder. On Apple Silicon that means Rosetta — under
    # QEMU user-mode emulation the Swift compiler crashes partway through:
    #   softwareupdate --install-rosetta --agree-to-license
    #   colima stop && colima start --vm-type=vz --vz-rosetta --cpu 6 --memory 12
    # Checked up front: without it the failure is a bare 'docker: command not
    # found' from inside the recipe, which says nothing about what to install.
    if ! command -v docker >/dev/null 2>&1; then
        echo "ERROR: docker is not installed, and this recipe builds a linux/amd64 image." >&2
        echo "" >&2
        echo "       Any Docker-compatible runtime will do, e.g." >&2
        echo "         brew install --cask docker        # Docker Desktop" >&2
        echo "         brew install colima docker        # lighter CLI-only alternative" >&2
        echo "" >&2
        echo "       Cloud Run is the only thing that needs this — the plugins, the" >&2
        echo "       website and the local MCP binary all build without it." >&2
        exit 1
    fi
    if ! docker info >/dev/null 2>&1; then
        echo "ERROR: docker is installed but the daemon is not running." >&2
        echo "       Start Docker Desktop (or 'colima start'), then re-run." >&2
        exit 1
    fi
    echo "=== Building {{cloud_service}} image for linux/amd64 ==="
    docker build --platform linux/amd64 -t "{{cloud_image}}" .
    SIZE=$(docker image inspect "{{cloud_image}}" --format='{{ "{{" }}.Size{{ "}}" }}')
    awk "BEGIN { printf \"  Image: {{cloud_image}}\n  Size:  %.0f MB\n\", $SIZE/1024/1024 }"

# Checked before build-cloud-image runs, so a missing gcloud costs a second
# rather than surfacing after a multi-minute image build.
_require-gcloud:
    #!/usr/bin/env bash
    if ! command -v gcloud >/dev/null 2>&1; then
        echo "ERROR: gcloud is not installed, and both remaining steps need it —" >&2
        echo "       'docker push' to Artifact Registry needs its credential helper," >&2
        echo "       and the deploy is 'gcloud run deploy'." >&2
        echo "" >&2
        echo "         brew install --cask google-cloud-sdk" >&2
        echo "         gcloud auth login && gcloud auth configure-docker" >&2
        exit 1
    fi

# First dependency of every recipe that publishes under the maintainer's accounts.
_require-maintainer:
    #!/usr/bin/env bash
    if [ "${VITHANCO_MAINTAINER:-}" != "1" ]; then
        echo "This recipe publishes under the Vithanco accounts and is for the maintainer." >&2
        echo "If that is you: export VITHANCO_MAINTAINER=1 in the shell that publishes." >&2
        exit 1
    fi

# Build + push the image + roll out a new Cloud Run revision + health check.
[group('publish')]
publish-cloud-run: _require-maintainer _require-gcloud build-cloud-image
    #!/usr/bin/env bash
    set -euo pipefail
    # No push step: `gcloud builds submit --tag` already pushed to Artifact
    # Registry. Building locally instead? Run build-cloud-image-local, then
    # `docker push {{cloud_image}}` yourself before deploying.
    echo "=== Deploying to Cloud Run ==="
    # The service is open to anyone (see SECURITY.md), so these bound what it can cost.
    # They used to be set by hand with `gcloud run services update`; a fresh deploy
    # would have lost them.
    limits=(
        # --max-instances: one instance caps the bill. The exposure left is
        # availability, which the per-request limits in MCPLimits are for.
        --max-instances=1
        # --concurrency: each render holds a Graphviz layout and, for the PNG, an
        # rsvg-convert process and its bitmap in the instance's 1 GiB. Four in flight
        # peaked at about 440 MB; docs/mcp-hardening.md has the measurements.
        --concurrency=4
        # --timeout: longer than the 120 s request deadline in MCPLimits, so the
        # client gets our 504 and not Cloud Run's.
        --timeout=150
        # --cpu-throttling: CPU only while a request is in flight. Layout is the
        # only work, and idle time then costs nothing.
        --cpu-throttling
    )
    gcloud run deploy "{{cloud_service}}" --image "{{cloud_image}}" --port 8080 --region "{{cloud_region}}" --memory 1Gi "${limits[@]}"
    echo ""
    echo "=== Verifying health check ==="
    curl -s https://mcp.vithanco.com/health
    echo ""
    echo "✓ Cloud Run deploy complete."

# Coordinated release across all surfaces. Builds, then confirms before anything ships.
[group('publish')]
publish-all: _require-maintainer release
    #!/usr/bin/env bash
    set -euo pipefail
    # Parity across every consumer in plugins.json, not a hardcoded pair. The
    # npm host joined the lockstep and this guard did not notice it, so all
    # three could be bumped together and only two published — the exact drift
    # the shared version exists to prevent.
    VERSIONS=$(node -p "
        require('./plugins.json').plugins.map(p => p.path + ' ' + p.version).join('\n')
    ")
    DISTINCT=$(echo "$VERSIONS" | awk '{print $2}' | sort -u | wc -l | tr -d ' ')
    if [ "$DISTINCT" -ne 1 ]; then
        echo "Parity guard: consumer versions differ — aborting." >&2
        echo "$VERSIONS" | sed 's/^/  /' >&2
        echo "Run 'just plugins-release <bump>' to move them together." >&2
        exit 1
    fi
    VER=$(echo "$VERSIONS" | head -1 | awk '{print $2}')

    # npm auth is checked here rather than inside publish-mcp-node's own
    # preflight because by then two plugins and a Cloud Run revision are
    # already out — the same reason publish-plugins preflights before it
    # mutates anything.
    if ! npm whoami >/dev/null 2>&1; then
        echo "Preflight: not logged in to npm — run 'npm login'." >&2
        echo "  (aborting now rather than after the plugins are already released)" >&2
        exit 1
    fi

    # The Marketplace is the one surface that may have no automated credential.
    # vsce needs a PAT; the alternative Microsoft offers is Entra workload
    # identity federation, which is CI-only and so no use to a release run from
    # a laptop. Uploading the .vsix through the publisher portal is a perfectly
    # good third option, and it is what shipped 1.0.8.
    #
    # So this is opportunistic rather than required: publish if a credential is
    # reachable, otherwise finish everything else and say what is left. A
    # release that aborts at the last step because of an auth method we chose
    # not to adopt would be worse than one that tells you to drag a file.
    # Detection, cheapest first. `vsce verify-pat` is the real proof, but it has
    # to read the secret out of the keychain, and a process without a TTY is not
    # granted that — so it reports "no credential" for a developer who is
    # perfectly well logged in. The keychain *entry* can be seen without
    # unlocking it, which is the signal that survives both contexts.
    #
    # None of these prove the token is still valid. An expired one fails at the
    # publish itself, which is why this step runs last.
    VSCE_AUTO=0
    if [ -n "${VSCE_PAT:-}" ]; then
        VSCE_AUTO=1
    elif security find-generic-password -s vscode-vsce -a vithanco >/dev/null 2>&1; then
        VSCE_AUTO=1
    elif npx vsce verify-pat vithanco >/dev/null 2>&1; then
        VSCE_AUTO=1
    fi

    echo ""
    echo "About to PUBLISH, all at v$VER:"
    echo "  • Plugins        → push + tag + GitHub release"
    echo "  • npm + registry → @vithanco/vgraph-mcp and com.vithanco/vgraph-mcp"
    echo "  • Website        → generate + deploy to vithanco.github.io, commit + push"
    echo "  • Cloud Run      → new revision of '{{cloud_service}}' in {{cloud_region}}"
    if [ "$VSCE_AUTO" -eq 1 ]; then
        echo "  • VS Code Mktpl  → vsce publish"
    else
        echo "  • VS Code Mktpl  → SKIPPED, no credential; upload the .vsix by hand"
    fi
    echo ""
    read -r -p "Type 'publish' to proceed: " ans
    if [ "$ans" != "publish" ]; then echo "Aborted."; exit 1; fi
    # Resumable. The first run of this shipped two GitHub releases and then died
    # on npm auth — and could not simply be re-run, because publish-plugins
    # refuses to overwrite the tag it had just created. Each surface is skipped
    # if it already carries this version, so a half-finished release can be
    # finished rather than unpicked.
    if gh release view "$VER" --repo Vithanco/obsidian-vithanco >/dev/null 2>&1 \
       && gh release view "$VER" --repo Vithanco/vscode-vithanco >/dev/null 2>&1; then
        echo "· plugins already released at $VER — skipping"
    else
        just publish-plugins
    fi

    if [ "$(npm view "@vithanco/vgraph-mcp" version 2>/dev/null)" = "$VER" ]; then
        echo "· npm already at $VER — skipping"
    else
        just publish-mcp-node
    fi

    just publish-website
    just publish-cloud-run

    if [ "$VSCE_AUTO" -eq 1 ]; then
        just publish-vscode-marketplace
    fi
    echo ""
    echo "✓ publish-all done. Live at v$VER:"
    echo "    Obsidian  → GitHub release (clients update from it)"
    if [ "$VSCE_AUTO" -eq 1 ]; then
        echo "    VS Code   → GitHub release + Marketplace"
    else
        echo "    VS Code   → GitHub release only. Marketplace still needs you:"
        echo "                upload vscode-vithanco/vithanco-$VER.vsix at"
        echo "                https://marketplace.visualstudio.com/manage/publishers/vithanco"
    fi
    echo "    npm       → @vithanco/vgraph-mcp"
    echo "    registry  → com.vithanco/vgraph-mcp"
    echo "    website   → vithanco.github.io"
    echo "    Cloud Run → {{cloud_service}} in {{cloud_region}}"

# ═══════════════════════════════════════════════════════════════════════════
# Misc
# ═══════════════════════════════════════════════════════════════════════════

# Register VGraph skills + MCP server for Claude/Cursor (interactive).
skills:
    ./mapping-skills/register-skills.sh

# First-run setup: clone plugins + install npm deps.
setup: plugins-setup
    #!/usr/bin/env bash
    set -euo pipefail
    git config core.hooksPath .githooks
    for d in obsidian-vithanco vscode-vithanco VGraphWasm/Tests-JS VGraphWasm/Tests-Browser .; do
        if [ -f "$d/package.json" ]; then
            echo "npm install in $d"
            ( cd "$d" && npm install --silent )
        fi
    done
    echo "✓ setup complete"

# Check that the toolchain this repo needs is installed.
doctor:
    #!/usr/bin/env bash
    have() { command -v "$1" >/dev/null 2>&1 && echo "  ✅ $1" || { echo "  ❌ $1 — $2"; MISSING=1; }; }
    # Optional: reported, but never fails the check — these gate one fallback
    # recipe, not the build.
    want() { command -v "$1" >/dev/null 2>&1 && echo "  ✅ $1" || echo "  ·  $1 (optional) — $2"; }
    MISSING=0
    # wasm-strip and wasm-opt may be installed but unlinked; look where the release build looks.
    . scripts/brew-kegs.sh
    append_brew_kegs wabt binaryen
    echo "Toolchain:"
    have swift     "install Xcode / swiftly"
    have swiftly   "needed to pin the Embedded WASM toolchain"
    have node      "brew install node"
    have npm       "comes with node"
    have jq        "brew install jq"
    have wasm-opt  "brew install binaryen"
    have wasm-strip "brew install wabt"
    want gcloud    "only for the maintainer's Cloud Run deploy (brew install --cask google-cloud-sdk)"
    want gitleaks  "only for the maintainer's public export (brew install gitleaks)"
    # Docker is optional now: build-cloud-image runs on Cloud Build. Only the
    # build-cloud-image-local fallback needs it — and buildx with it, since the
    # Dockerfile's `RUN --mount=type=cache` will not run on the legacy builder.
    want docker    "only for build-cloud-image-local (brew install colima docker)"
    want docker-buildx "with docker; the classic builder works too since the Dockerfile needs no BuildKit"
    have python3   "brew install python (just serve)"
    # Optional: only the wasm build, its smoke tests and the editor's browser
    # tests need the SDK; native `swift build` and `swift test` do not.
    . scripts/wasm-sdk.sh
    NO_SDK=0
    if command -v swift >/dev/null 2>&1; then
        if swift sdk list 2>/dev/null | grep -qx "$SWIFT_SDK_ID"; then
            echo "  ✅ $SWIFT_SDK_ID"
        else
            echo "  ·  $SWIFT_SDK_ID (optional) — only for the wasm build; see README.md#building"
            NO_SDK=1
        fi
    fi
    if [ "$MISSING" = 1 ]; then
        echo ""
        echo "Some tools are missing — recipes that need them will fail until installed."
        exit 1
    fi
    if [ "$NO_SDK" = 1 ]; then
        echo "WASM build unavailable without SDK. Install: https://swift.org/documentation/articles/wasm-getting-started.html"
        exit 0
    fi
    echo "All good."

# ═══════════════════════════════════════════════════════════════════════════
# vithanco2vgl — the converter that reads documents from the old Mac app
# ═══════════════════════════════════════════════════════════════════════════
# It lives in its own repo ({{converter_dir}}) because it carries the legacy
# Core Data model, which nothing else here should depend on. The recipes are
# front-doored from this justfile so a release is one ladder, not two.

# Build + sign the converter for distribution. Nothing leaves the machine.
[group('build')]
converter-release:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{converter_dir}}" ]; then
        echo "Error: converter dir '{{converter_dir}}' not found." >&2
        echo "  Set VITHANCO_CONVERTER_DIR or pass it: just converter_dir=/path converter-release" >&2
        exit 1
    fi
    if [ -z "{{signing_id}}" ]; then
        echo "Error: set VITHANCO_SIGNING_ID to your 'Developer ID Application: …' identity." >&2
        exit 1
    fi
    if ! security find-identity -v -p codesigning | grep -qF "{{signing_id}}"; then
        echo "Error: no signing identity '{{signing_id}}' in the keychain." >&2
        echo "  Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application" >&2
        exit 1
    fi
    cd "{{converter_dir}}"

    # --build-system swiftbuild is not optional: only that one runs momc, and
    # without a compiled model the tool dies on its first document.
    echo "=== Building (release, swiftbuild) ==="
    swift build -c release --build-system swiftbuild
    OUT=".build/out/Products/Release"
    test -d "$OUT/VithancoDataModel_VithancoDataModel.bundle/Contents/Resources/Document.momd" || {
        echo "Error: the Core Data model was not compiled — wrong build system?" >&2; exit 1; }

    DIST=".build/dist"
    rm -rf "$DIST" && mkdir -p "$DIST/vithanco2vgl"
    cp -R "$OUT/vithanco2vgl" "$OUT/VithancoDataModel_VithancoDataModel.bundle" "$DIST/vithanco2vgl/"

    # The bundle is signed first: signing the executable afterwards is what seals it.
    echo "=== Signing ==="
    codesign --force --options runtime --timestamp --sign "{{signing_id}}" \
        "$DIST/vithanco2vgl/VithancoDataModel_VithancoDataModel.bundle"
    codesign --force --options runtime --timestamp --sign "{{signing_id}}" \
        "$DIST/vithanco2vgl/vithanco2vgl"
    codesign --verify --strict "$DIST/vithanco2vgl/vithanco2vgl"

    ditto -c -k --keepParent "$DIST/vithanco2vgl" "$DIST/vithanco2vgl.zip"
    echo ""
    echo "✓ Signed: $(cd "{{converter_dir}}" && pwd)/$DIST/vithanco2vgl.zip"
    echo "  $(lipo -archs "$DIST/vithanco2vgl/vithanco2vgl")  •  not yet notarised"
    echo "  Next: just publish-converter"

# Notarise the signed converter and stage it into the website. Uploads to Apple.
[group('publish')]
publish-converter: _require-maintainer converter-release
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{notary_profile}}" ]; then
        echo "Error: set VITHANCO_NOTARY_PROFILE to your notarytool keychain profile." >&2
        exit 1
    fi
    cd "{{converter_dir}}"
    ZIP=".build/dist/vithanco2vgl.zip"

    echo "=== Notarising (uploads to Apple, usually a couple of minutes) ==="
    xcrun notarytool submit "$ZIP" --keychain-profile "{{notary_profile}}" --wait

    # The ticket binds to the binary's cdhash and is served from Apple's CDN, so
    # this asks the real question — is it notarised? — rather than trusting the
    # submission's exit code. A zip cannot be stapled; only .app/.pkg/.dmg can.
    codesign --test-requirement="=notarized" --verify --verbose=1 \
        ".build/dist/vithanco2vgl/vithanco2vgl"

    if [ -d "{{website_dir}}" ]; then
        cp "$ZIP" "{{website_dir}}/Resources/tools/vithanco2vgl.zip"
        echo ""
        echo "Staged into {{website_dir}}/Resources/tools. Finish in the website repo:"
        echo "    cd {{website_dir}} && swift run    # preview, then deploy as usual"
    else
        echo ""
        echo "Website dir '{{website_dir}}' not found — zip left at $ZIP"
    fi
