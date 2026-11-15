// The preview is mounted, not replaced: a render patches the elements already
// drawn (ADR-0015 F1). Element identity is what transitions will animate between.

import { test, expect } from '@playwright/test';
import { s, sel, openEditor, renderNow, groupedGraph } from '../helpers/editor.js';

const withOneMore = groupedGraph.replace(
  'edge idea -> detail;',
  'node extra: Concept "Extra";\n  edge idea -> detail;',
);

// A second target under `idea`, so `detail` has to make room and its line bends.
const forked = groupedGraph.replace(
  'edge idea -> detail;',
  'node extra: Concept "Extra";\n  edge idea -> extra;\n  edge idea -> detail;',
);

const mark = (page, selector) =>
  page.evaluate((q) => {
    document.querySelector(q).__keptAcrossRender = true;
  }, selector);

const isMarked = (page, selector) =>
  page.evaluate((q) => document.querySelector(q).__keptAcrossRender === true, selector);

test('a node keeps its element when a render adds another', async ({ page }) => {
  await openEditor(page, groupedGraph);
  await mark(page, sel.node('idea'));
  await mark(page, s.svg);

  await page.locator(s.textarea).fill(withOneMore);
  await renderNow(page);

  await expect(page.locator(sel.node('extra'))).toBeVisible();
  expect(await isMarked(page, sel.node('idea')), 'the node element').toBe(true);
  expect(await isMarked(page, s.svg), 'the svg root').toBe(true);
});

test('a node that leaves the graph leaves the preview', async ({ page }) => {
  await openEditor(page, withOneMore);
  await expect(page.locator(sel.node('extra'))).toBeVisible();

  await page.locator(s.textarea).fill(groupedGraph);
  await renderNow(page);

  await expect(page.locator(sel.node('extra'))).toHaveCount(0);
  await expect(page.locator(sel.node('idea'))).toBeVisible();
});

// Edge ids are minted by the parse, so a text edit renumbers every edge. The
// element has to survive that for a line to have anything to move from.
test('an edge keeps its element when a text edit adds an edge before it', async ({ page }) => {
  await openEditor(page, groupedGraph);
  const edge = '[data-key="idea>detail"]';
  await mark(page, `${edge} path`);

  await page.locator(s.textarea).fill(forked);
  await renderNow(page);

  await expect(page.locator(sel.node('extra'))).toBeVisible();
  expect(await isMarked(page, `${edge} path`), 'the line').toBe(true);
});

// What is in flight on `selector` right after a render that moves the layout.
async function transitionsAfterRender(page, selector) {
  await openEditor(page, groupedGraph);
  await page.locator(s.textarea).fill(forked);
  return page.evaluate(async (q) => {
    window.__vgraphRenderNow();
    await new Promise((done) => requestAnimationFrame(done));
    return document.querySelector(q).getAnimations().map((a) => a.transitionProperty);
  }, selector);
}

test('a node glides to its new place', async ({ page }) => {
  expect(await transitionsAfterRender(page, `${sel.node('detail')} > g`)).toContain('transform');
});

test('a line follows', async ({ page }) => {
  expect(await transitionsAfterRender(page, '[data-key="idea>detail"] path')).toContain('d');
});

test('nothing glides for someone who asked for reduced motion', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });

  expect(await transitionsAfterRender(page, `${sel.node('detail')} > g`)).toEqual([]);
  expect(await transitionsAfterRender(page, '[data-key="idea>detail"] path')).toEqual([]);
});

// Everything else drawn for an edge or a group moves too. `z` above `a` pushes
// the group, the line, its head and both of its labels down a rank.
const labelled = `vnotation Flow {
  node type: Step [nodeStyle: roundedBox, color: "#3366cc"]
  edge type: next from: Step to: Step [headLabel: "+"]
}

vgraph f: Flow "Demo" {
  group g1 "Team" {
    node a: Step "A";
  };
  node b: Step "B";
  edge a -> b: next "leads to";
}`;
const pushedDown = labelled.replace('edge a -> b', 'node z: Step "Z";\n  edge z -> a: next;\n  edge a -> b');

const parts = {
  arrowhead: '[data-key="a>b"] > polygon',
  'edge label': '[data-key="a>b"] > text:nth-of-type(1)',
  'edge-end label': '[data-key="a>b"] > text:nth-of-type(2)',
  'group label': `${sel.group('g1')} > .vgraph-group-label`,
  'group box': `${sel.group('g1')} > rect`,
};

async function partsInFlightAfterRender(page) {
  await openEditor(page, labelled);
  await page.locator(s.textarea).fill(pushedDown);
  return page.evaluate(async (named) => {
    window.__vgraphRenderNow();
    await new Promise((done) => requestAnimationFrame(done));
    return Object.fromEntries(
      Object.entries(named).map(([name, q]) => [
        name,
        document.querySelector(q).getAnimations().map((a) => a.transitionProperty),
      ]),
    );
  }, parts);
}

test('what is drawn with an edge or a group moves with it', async ({ page }) => {
  const inFlight = await partsInFlightAfterRender(page);

  expect(inFlight.arrowhead).toContain('transform');
  expect(inFlight['edge label']).toContain('transform');
  expect(inFlight['edge-end label']).toContain('transform');
  expect(inFlight['group label']).toContain('transform');
  expect(inFlight['group box']).toContain('y');
});

test('none of it moves for someone who asked for reduced motion', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });

  expect(await partsInFlightAfterRender(page)).toEqual({
    arrowhead: [],
    'edge label': [],
    'edge-end label': [],
    'group label': [],
    'group box': [],
  });
});

// A redraw that changes the diagram's bounds changes the `viewBox`. Left to
// jump, that rescales and shifts everything at once, and the glide starts from
// the wrong place.
const frameWidth = (page) => page.evaluate((q) => document.querySelector(q).viewBox.baseVal.width, s.svg);

async function frameWidthsAroundRender(page) {
  await openEditor(page, groupedGraph);
  const before = await frameWidth(page);
  await page.locator(s.textarea).fill(forked);
  const during = await page.evaluate(async (q) => {
    window.__vgraphRenderNow();
    const frame = () => new Promise((done) => requestAnimationFrame(done));
    await frame();
    await frame();
    await frame();
    return document.querySelector(q).viewBox.baseVal.width;
  }, s.svg);
  await page.waitForTimeout(600);
  return { before, during, after: await frameWidth(page) };
}

test('the frame eases to its new bounds', async ({ page }) => {
  const { before, during, after } = await frameWidthsAroundRender(page);

  expect(after, 'the fixture widens the diagram').toBeGreaterThan(before + 1);
  expect(during).toBeGreaterThan(before);
  expect(during).toBeLessThan(after);
});

test('the frame goes straight to its new bounds under reduced motion', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const { before, during, after } = await frameWidthsAroundRender(page);

  expect(after).toBeGreaterThan(before + 1);
  expect(during).toBe(after);
});

// Wider than the pane, so it is drawn scaled down to fit, and one more node
// changes that scale: everything on screen shifts while the frame eases.
const wide = `vgraph demo: ConceptMap "Wide" {
${Array.from({ length: 14 }, (_, i) => `  node c${i}: Concept "Concept number ${i}";`).join('\n')}
}`;

// The field is placed when the node appears, which is while the frame is still
// easing. It has to be placed where the node will be, not where it is.
test('the inline editor opens where a newly added node comes to rest', async ({ page }) => {
  await openEditor(page, wide);
  const scaleBefore = await page.evaluate((q) => document.querySelector(q).getScreenCTM().a, s.svg);

  await page.locator(s.toolbar).locator('button').filter({ hasText: 'Node' }).click();
  await page.locator(s.menuItem).filter({ hasText: /^Concept$/ }).click();
  await expect(page.locator(s.inlineEdit)).toBeVisible();
  await page.waitForTimeout(600);  // past the easing

  const scaleAfter = await page.evaluate((q) => document.querySelector(q).getScreenCTM().a, s.svg);
  expect(scaleAfter, 'the fixture rescales the drawing').toBeLessThan(scaleBefore * 0.97);
  const node = await page.locator(sel.node('concept_15')).boundingBox();
  const field = await page.locator(s.inlineEdit).boundingBox();
  expect(Math.abs(field.x - node.x), 'left edges').toBeLessThan(4);
  expect(Math.abs(field.y - node.y), 'top edges').toBeLessThan(4);
});
