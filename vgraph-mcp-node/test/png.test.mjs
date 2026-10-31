import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, test, expect, beforeAll } from 'vitest';
import { loadVGraph } from '../src/wasm-host.mjs';
import { svgToPixels } from '../src/png.mjs';

// The real engine draws the diagram and the real PNG path renders it. Both come
// from vendor/Package, so these fail until `release.sh` has vendored a build
// that draws icons.
const PKG_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'vendor', 'Package');

let api;
beforeAll(async () => {
  api = await loadVGraph(PKG_DIR);
});

const question = 'vgraph g: IBIS "T" {\n  node q1: Question "Why?";\n}';
const incorrectEquals = `vgraph a: Arithmetic "A" {
  node three: Number "3"; node four: Number "4"; node op: Times; node eq: Equals "11";
  edge three -> op: times_first_operand;
  edge four -> op: times_second_operand;
  edge op -> eq: times_result;
}`;

const withoutIcons = (svg) => svg.replace(/<use\b[^>]*href="#icon-[^"]*"[^>]*\/>/g, '');

// Icons are drawn white on the badge's coloured circle; nothing else in a light
// rendering of these diagrams is opaque white.
const opaqueWhite = ({ pixels }) => {
  let count = 0;
  for (let i = 0; i < pixels.length; i += 4) {
    if (pixels[i] === 255 && pixels[i + 1] === 255 && pixels[i + 2] === 255 && pixels[i + 3] === 255) count++;
  }
  return count;
};

const differing = (a, b) => {
  let count = 0;
  for (let i = 0; i < a.pixels.length; i += 4) {
    if (a.pixels[i] !== b.pixels[i] || a.pixels[i + 1] !== b.pixels[i + 1] || a.pixels[i + 2] !== b.pixels[i + 2]) count++;
  }
  return count;
};

describe('icons in the PNG path', () => {
  test('Given a node type badge rendered to PNG, when its icon area is read, then it holds icon-coloured pixels', async () => {
    const svg = api.renderGraph(question);
    expect(opaqueWhite(await svgToPixels(svg))).toBeGreaterThan(5);
    expect(differing(await svgToPixels(svg), await svgToPixels(withoutIcons(svg)))).toBeGreaterThan(20);
  });

  test('Given an incorrect equals node rendered to PNG, when its centre is read, then it holds icon-coloured pixels', async () => {
    const svg = api.renderGraph(incorrectEquals);
    expect(svg).not.toContain('≠');
    expect(differing(await svgToPixels(svg), await svgToPixels(withoutIcons(svg)))).toBeGreaterThan(20);
  });

  test('Given the same badge with its icon left out, when rendered to PNG, then the icon area holds no icon-coloured pixels', async () => {
    const svg = withoutIcons(api.renderGraph(question));
    expect(opaqueWhite(await svgToPixels(svg))).toBe(0);
  });
});
