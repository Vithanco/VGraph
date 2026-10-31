#!/usr/bin/env bash
# Rebuild fonts/ — the DM Sans faces the *rasterisers* need.
#
# A browser opening one of our SVGs gets DM Sans from the `@import` in
# SVGBuilder.dmSansFontImportCSS(). Nothing else does: rasterisers don't fetch
# stylesheets, and resvg ignores an `@font-face` embedded in the SVG outright
# (the same SVG with a base64 font inlined and with no font information at all
# render byte-identically, text missing). So every non-browser consumer needs
# the faces as files, and this builds them.
#
# Three constraints decide the output format, all found by testing:
#
#  - TTF, not woff2. resvg-wasm panics ("unreachable") on DM Sans italic as
#    woff2 — including Google's own unmodified file. TTF is fine, and
#    fontconfig (the cloud image's rsvg-convert) wants TTF anyway.
#  - Static instances, not the variable font. resvg ignores the weight axis:
#    one variable file renders 400, 500, 600 and 700 identically, so the
#    weights VSVGNode asks for would silently come out regular.
#  - Subset, not the whole face. We ship ASCII plus Latin-1 and the punctuation
#    labels realistically carry. A label outside that range falls back rather
#    than rendering — widen CHARSET below if that shows up.
#
# Requires Python 3. Everything else is fetched or built into a throwaway venv.
set -euo pipefail

# Reproducible output. fontTools stamps head.modified with the build time, so
# without this every run rewrites all five files with identical glyphs and a new
# timestamp — `just fonts` would dirty the tree on a no-op and a real change
# would be indistinguishable from noise. fontTools honours SOURCE_DATE_EPOCH;
# the specific instant is arbitrary and only has to be fixed.
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1735689600}"  # 2025-01-01T00:00:00Z

cd "$(dirname "${BASH_SOURCE[0]}")/.."
OUT="fonts"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The weights VSVGNode/VSVGNodeLayout emit, plus the italic edge and relation
# labels. Weight 300 is in the @import but no code path emits it.
WEIGHTS=(400 500 600 700)

CHARSET=$(python3 - <<'PY'
ascii_ = ''.join(chr(c) for c in range(0x20, 0x7F))
accents = 'äöüÄÖÜßéèêëáàâãíìîïóòôõúùûñçÉÈÊËÁÀÂÍÌÎÓÒÔÚÙÛÑÇåÅøØæÆœŒšŠžŽ'
punct = '–—…“”‘’‚„•·°±×÷≤≥≠→←↑↓€£¥§¶©®™«»‹›'
print(ascii_ + accents + punct, end='')
PY
)

echo "Setting up fonttools..."
python3 -m venv "$WORK/venv" >/dev/null
"$WORK/venv/bin/pip" install -q fonttools brotli
PY_BIN="$WORK/venv/bin/python"

# Google serves DM Sans as one variable file per style, which is why the CSS
# declares six faces but only two files exist behind it.
# The weight RANGE matters: ask for single weights and Google serves static
# faces with no `fvar` to instance from. A range gets the variable file.
CSS_URL="https://fonts.googleapis.com/css2?family=DM+Sans:ital,wght@0,400..700;1,400&display=swap"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120.0 Safari/537.36"

echo "Fetching DM Sans..."
curl -sSf -A "$UA" "$CSS_URL" -o "$WORK/dmsans.css"

"$PY_BIN" - "$WORK" <<'PY'
import re, sys, urllib.request, pathlib
work = pathlib.Path(sys.argv[1])
css = (work / 'dmsans.css').read_text()
# Take the `latin` block for each style; latin-ext is covered by our subset.
for subset, body in zip(*[iter(re.split(r'/\* ([a-z-]+) \*/', css)[1:])] * 2):
    if subset != 'latin':
        continue
    style = re.search(r'font-style:\s*(\w+)', body).group(1)
    url = re.search(r'url\((https://[^)]+\.woff2)\)', body).group(1)
    (work / f'src-{style}.woff2').write_bytes(urllib.request.urlopen(url).read())
    print(f'  fetched {style}')
PY

"$PY_BIN" - "$WORK" <<'VARCHECK'
import sys, pathlib
from fontTools.ttLib import TTFont
src = pathlib.Path(sys.argv[1]) / 'src-normal.woff2'
if TTFont(src).get('fvar') is None:
    sys.exit('src-normal.woff2 has no weight axis — the CSS query stopped '
             'returning the variable face; check CSS_URL asks for a range.')
VARCHECK

mkdir -p "$OUT"
for w in "${WEIGHTS[@]}"; do
    "$PY_BIN" -m fontTools.varLib.instancer "$WORK/src-normal.woff2" "wght=$w" \
        -o "$WORK/inst-$w.ttf" >/dev/null
    "$PY_BIN" -m fontTools.subset "$WORK/inst-$w.ttf" \
        --text="$CHARSET" --output-file="$OUT/DMSans-$w.ttf" \
        --layout-features=kern,liga --no-hinting --desubroutinize
    echo "  $OUT/DMSans-$w.ttf"
done

# The italic face is already static upstream — no instancing step.
"$PY_BIN" -m fontTools.subset "$WORK/src-italic.woff2" \
    --text="$CHARSET" --output-file="$OUT/DMSans-400-italic.ttf" \
    --layout-features=kern,liga --no-hinting --desubroutinize
echo "  $OUT/DMSans-400-italic.ttf"

# Rename. Upstream calls this family "DM Sans 9pt" — DM Sans v4 is an
# optical-size family, and the instancer keeps that name. Our SVGs ask for
# "DM Sans", which never matches it, so without this step fontconfig lists the
# faces and rsvg-convert still substitutes. The instancer also leaves every
# weight's style name as "Regular", so the four files are indistinguishable to
# a matcher that reads names rather than OS/2.usWeightClass.
#
# Naming follows the usual OpenType split: the two RIBBI-legal weights (400,
# 700) and the italic go in family "DM Sans" directly; 500 and 600 have no
# RIBBI slot, so they take their own legacy family and are reunited under
# "DM Sans" by the typographic names (16/17).
"$PY_BIN" - "$OUT" <<'RENAME'
import pathlib, sys
from fontTools.ttLib import TTFont

STYLES = {
    'DMSans-400.ttf':        ('DM Sans',          'Regular', 'Regular'),
    'DMSans-700.ttf':        ('DM Sans',          'Bold',    'Bold'),
    'DMSans-400-italic.ttf': ('DM Sans',          'Italic',  'Italic'),
    'DMSans-500.ttf':        ('DM Sans Medium',   'Regular', 'Medium'),
    'DMSans-600.ttf':        ('DM Sans SemiBold', 'Regular', 'SemiBold'),
}

out = pathlib.Path(sys.argv[1])
for fname, (family, subfamily, typo_style) in STYLES.items():
    path = out / fname
    font = TTFont(path)
    name = font['name']
    full = f'{family} {subfamily}'.replace(' Regular', '') or family
    ps = f"{family.replace(' ', '')}-{typo_style}"
    for nid, value in (
        (1, family), (2, subfamily), (4, full), (6, ps),
        (16, 'DM Sans'), (17, typo_style),
    ):
        # Windows/Unicode records; mac records are dropped by the subsetter.
        name.setName(value, nid, 3, 1, 0x409)
    font.save(path)
    print(f'  named {fname}: family={family!r} typo={typo_style!r} '
          f'weight={font["OS/2"].usWeightClass}')
RENAME

# OFL 1.1 requires the licence travel with the font.
curl -sSf "https://raw.githubusercontent.com/google/fonts/main/ofl/dmsans/OFL.txt" -o "$OUT/OFL.txt"
echo "  $OUT/OFL.txt"

echo "Done. $(du -sh "$OUT" | cut -f1) total."
