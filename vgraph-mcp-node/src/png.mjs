// SVG -> PNG via resvg compiled to wasm: keeps the "no native dependency"
// property that makes the npx story work.
//
// Fonts are bundled, not scavenged from the host and not read from the SVG:
//
//  - resvg has no filesystem, so `loadSystemFonts` finds nothing. Whatever the
//    host happens to have installed is irrelevant.
//  - resvg also ignores an `@font-face` embedded in the SVG. Verified: the same
//    SVG with a base64 DM Sans inlined and with no font information at all
//    produce byte-identical output, with no text drawn. The `@import` the SVG
//    carries for browsers does nothing here.
//
// So every face has to arrive as a buffer, and as TTF:
//
//  - resvg-wasm panics ("unreachable") on DM Sans italic as woff2 — including
//    Google's own unmodified file. The same face as TTF is fine.
//  - resvg ignores a variable font's weight axis: one variable file renders
//    400, 500, 600 and 700 identically. Static instances per weight are the
//    only way to get the weights the SVG asks for.
//
// DM Sans is SIL Open Font License; OFL.txt ships beside these files.
import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { initWasm, Resvg } from '@resvg/resvg-wasm';

const require = createRequire(import.meta.url);
const FONT_DIR = path.join(path.dirname(path.dirname(fileURLToPath(import.meta.url))), 'vendor', 'fonts');

let ready = null;
let fontBuffers = [];

export async function initPng() {
  if (ready) return ready;
  ready = (async () => {
    await initWasm(await readFile(require.resolve('@resvg/resvg-wasm/index_bg.wasm')));
    const files = (await readdir(FONT_DIR)).filter((f) => f.endsWith('.ttf')).sort();
    fontBuffers = await Promise.all(files.map((f) => readFile(path.join(FONT_DIR, f))));
    console.error(`[png] ${files.length} bundled face(s): ${files.join(', ')}`);
  })();
  return ready;
}

function render(svg, dpi) {
  return new Resvg(svg, {
    dpi,
    font: { fontBuffers, defaultFontFamily: 'DM Sans', loadSystemFonts: false },
  }).render();
}

export async function svgToPng(svg, { dpi = 144 } = {}) {
  await initPng();
  return Buffer.from(render(svg, dpi).asPng());
}

// RGBA, row by row. Tests read pixels from here rather than decoding the PNG.
export async function svgToPixels(svg, { dpi = 144 } = {}) {
  await initPng();
  const image = render(svg, dpi);
  return { width: image.width, height: image.height, pixels: image.pixels };
}
