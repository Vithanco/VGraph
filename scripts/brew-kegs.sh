# Sourced, not run. Homebrew refuses to link a formula whose binaries collide with
# another's (wabt and binaryen both ship `wasm2c`), which leaves its tools installed
# but absent from PATH. Append each keg's own bin so they are found without
# repointing a symlink another formula owns. Appended, so anything already linked
# still wins.
append_brew_kegs() {
    command -v brew >/dev/null 2>&1 || return 0
    local keg bin
    for keg in "$@"; do
        bin="$(brew --prefix "$keg" 2>/dev/null)/bin"
        if [ -d "$bin" ]; then PATH="$PATH:$bin"; fi
    done
    export PATH
}
