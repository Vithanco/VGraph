// VGraphWasm smoke harness — Phase 0 safety net.
//
// Loads the built website/Package/VGraphWasm.wasm via the PackageToJS-generated
// index.js entry point, then exercises the four layout-free @JS functions for
// every built-in notation plus a `vnotation extends` fixture.
//
// Phase 1 (struct-only registry + reflection refactor) and Phase 3 (Embedded
// flip) must both keep this green. Failures here mean the WASM build's wire
// surface has changed.
//
// The three layout-dependent functions (renderGraphWithLayout,
// renderGraphWithLayoutDark, layoutGraphWithLayout) require a host-computed
// Graphviz JSON they aren't exercised here; they're covered by manual browser
// checks against website/index.html.

import { describe, test, expect, beforeAll } from 'vitest';
import { instantiate } from '../../website/Package/instantiate.js';
import { defaultNodeSetup } from '../../website/Package/platforms/node.js';
import { fixtures, dynamicNotationFixture, viewsFixture } from './fixtures.js';

let api;

beforeAll(async () => {
  // Use the PackageToJS-emitted Node platform setup (the default index.js is
  // browser-only — see website/Package/index.js). VGraphWasm declares zero
  // JS-side imports (see bridge-js.d.ts: `Imports = {}`).
  const instantiateOptions = await defaultNodeSetup({});
  const { exports } = await instantiate(instantiateOptions);
  api = exports;
});

// Sanity: the four expected entry points are exposed.
test('WASM exports the expected layout-free @JS functions', () => {
  for (const fn of ['convertToDot', 'dotForLayout', 'debugGraph', 'exportToVGL']) {
    expect(typeof api[fn]).toBe('function');
  }
});

// Each notation × each layout-free function → non-empty, non-Error output.
for (const [notation, vgl] of Object.entries(fixtures)) {
  describe(notation, () => {
    test('convertToDot produces valid DOT', () => {
      const dot = api.convertToDot(vgl);
      expect(dot, `convertToDot(${notation}) output`).toBeTruthy();
      expect(dot.startsWith('Error:'), `convertToDot(${notation}) error: ${dot}`).toBe(false);
      expect(dot).toMatch(/digraph|graph/i);
    });

    test('dotForLayout produces valid DOT', () => {
      const dot = api.dotForLayout(vgl);
      expect(dot, `dotForLayout(${notation}) output`).toBeTruthy();
      expect(dot.startsWith('Error:'), `dotForLayout(${notation}) error: ${dot}`).toBe(false);
      expect(dot).toMatch(/digraph|graph/i);
    });

    test('debugGraph reports parsed nodes and edges', () => {
      const debug = api.debugGraph(vgl);
      expect(debug, `debugGraph(${notation}) output`).toBeTruthy();
      expect(debug.startsWith('Error'), `debugGraph(${notation}) error: ${debug}`).toBe(false);
      expect(debug).toMatch(/Nodes:\s*2/);
    });

    test('exportToVGL preserves the notation name', () => {
      const vglOut = api.exportToVGL(vgl);
      expect(vglOut, `exportToVGL(${notation}) output`).toBeTruthy();
      expect(vglOut.startsWith('Error'), `exportToVGL(${notation}) error: ${vglOut}`).toBe(false);
      expect(vglOut).toContain(notation);
    });
  });
}

// Dynamic notation path — must survive the closure-registry refactor.
describe('vnotation extends', () => {
  test('convertToDot accepts a dynamic notation', () => {
    const dot = api.convertToDot(dynamicNotationFixture);
    expect(dot, 'convertToDot(dynamic) output').toBeTruthy();
    expect(dot.startsWith('Error:'), `convertToDot(dynamic) error: ${dot}`).toBe(false);
  });

  test('exportToVGL round-trips a dynamic notation', () => {
    const vglOut = api.exportToVGL(dynamicNotationFixture);
    expect(vglOut, 'exportToVGL(dynamic) output').toBeTruthy();
    expect(vglOut.startsWith('Error'), `exportToVGL(dynamic) error: ${vglOut}`).toBe(false);
    // Either preserves vnotation or applies it (registers MyNotation): either way the output references it.
    expect(vglOut).toMatch(/MyNotation/);
  });
});

// A notation's self-description comes from the notation, not from a graph.
describe('describeNotation', () => {
  test('describes a built-in notation', () => {
    const markdown = api.describeNotation('IBIS');
    expect(markdown.startsWith('# IBIS'), `describeNotation(IBIS): ${markdown.slice(0, 80)}`).toBe(true);
    expect(markdown).toContain('## Node types');
  });

  test('reports a notation it does not know', () => {
    expect(api.describeNotation('DoesNotExist').startsWith('Error:')).toBe(true);
  });
});

describe('views', () => {
  test('listViews returns name and label in document order', () => {
    expect(JSON.parse(api.listViews(viewsFixture))).toEqual([
      { name: 'first', label: 'First View' },
      { name: 'second', label: 'Second View' },
    ]);
  });

  test('listViews is empty for a document without views', () => {
    expect(JSON.parse(api.listViews(fixtures.ConceptMap))).toEqual([]);
  });

  test('renderGraphWithQuality with an empty view name is the default view', () => {
    const byDefault = JSON.parse(api.renderGraphWithQuality(viewsFixture, ''));
    expect(byDefault.svg).toBe(api.renderGraph(viewsFixture));
  });

  test('renderGraphWithQuality with a view name draws that view', () => {
    const view = JSON.parse(api.renderGraphWithQuality(viewsFixture, 'first'));
    const byDefault = JSON.parse(api.renderGraphWithQuality(viewsFixture, ''));
    expect(view.svg).toContain('<svg');
    expect(view.svg).not.toBe(byDefault.svg);
    expect(view.quality).toEqual(byDefault.quality);
  });

  test('an unknown view is an error that lists the views', () => {
    const result = JSON.parse(api.renderGraphWithQuality(viewsFixture, 'nope'));
    expect(result.error).toContain("no view 'nope'");
    expect(result.error).toContain('first, second');
  });
});
