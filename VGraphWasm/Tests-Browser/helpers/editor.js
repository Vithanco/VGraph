// Selectors and fixtures for the editor browser tests. Every selector here is
// something Editor.swift or SVGElementId stamps, so a rename there breaks one file.

import { expect } from '@playwright/test';

// Plain strings only — anything passed into `page.evaluate` has to survive
// structured cloning, which functions do not.
export const s = {
  preview: '#vg-editor-preview',
  svg: '#vg-editor-preview svg',
  textarea: '#vg-vgl-input',
  highlight: '#vg-vgl-highlight',
  diagnostics: '#vg-editor-diagnostics',
  diagnosticsHead: '#vg-editor-diagnostics-head',
  status: '#vg-editor-status',
  inlineEdit: '#vg-inline-edit',
  ctxInput: '#vg-ctx-input',
  urlBadge: '.vgraph-url-badge',
  menu: '.vg-ctx-menu',
  menuItem: '.vg-ctx-menu .vg-ctx-item',
  menuHead: '.vg-ctx-head',
  dragOverlay: '#vg-drag-overlay',
  dragLine: '#vg-drag-overlay .vg-drag-line',
  dragLegal: '#vg-drag-overlay .vg-drag-legal',
  dragIllegal: '#vg-drag-overlay .vg-drag-illegal',
  groupLabel: '.vgraph-group-label',
  anyEdge: '.vgraph-edge',
  edgeEnd: '.vgraph-edge-end',
  root: '.vg-editor-root',
  toolbar: '.vg-toolbar',
  examples: '#vg-examples',
  fileMenuButton: '#vg-file-menu',
  fileMenu: '#vg-file-menu-panel',
  fileMenuItem: '#vg-file-menu-panel .vg-ctx-item',
  fileInput: '#vg-file-input',
  displayButton: '#vg-display-button',
  displayPanel: '#vg-display-panel',
  sourceToggle: '#vg-source-toggle',
  enlarge: '#vg-fullscreen',
  undo: '#vg-undo',
  redo: '#vg-redo',
  viewMenuButton: '#vg-view-menu',
  viewMenuItem: '#vg-view-menu-panel .vg-ctx-item',
  splitter: '.vg-splitter',
};

export const sel = {
  ...s,
  node: (id) => `#node-${id}`,
  group: (id) => `#group-${id}`,
  // Scoped to one edge's own `<g>`, so a fixture with several edges can still
  // address one end unambiguously. `edgeSel` is normally `s.anyEdge` — fine
  // wherever a fixture has exactly one edge, as the reattach specs do.
  edgeEndOn: (edgeSel, end) => `${edgeSel} .vgraph-edge-end[data-end="${end}"]`,
};

export const oneConcept = `vgraph demo: ConceptMap "Demo" {
  node idea: Concept "Idea";
}`;

// Renders with a negative viewBox origin, which is what the edge anchor's
// getScreenCTM exists for.
export const groupedGraph = `vgraph demo: ConceptMap "Demo" {
  group g1 "My Group" {
    node idea: Concept "Idea";
  };
  node detail: Concept "Detail";
  edge idea -> detail;
}`;

// Two nodes outside a boundary and two inside it, so that "everything" and "all
// of one group" are different sets. Same shape as selection.spec.js's `boxed`.
export const boxedGraph = `vgraph demo: ConceptMap "Demo" {
  node outside: Concept "Outside";
  node spare: Concept "Spare";
  group box "Box" {
    node one: Concept "One";
    node two: Concept "Two";
  }
}`;

// One node type only, so the list behind "Other type…" has a single entry.
export const causalLoop = `vgraph demo: CLD "Demo" {
  node stock: Stock "Stock";
}`;

// Concept → Relation: the notation carries this pair both ways, so the edge can
// be flipped, but nothing may sit between them.
export const proposition = `vgraph demo: ConceptMap "Demo" {
  node idea: Concept "Idea";
  node link: Relation "leads to";
  edge idea -> link;
}`;

// Concept → Relation is declared both ways; Concept → Concept is not. So one
// drag is legal, another is not, and neither needs a bound to be declared.
export const connectable = `vgraph demo: ConceptMap "Demo" {
  node idea: Concept "Idea";
  node other: Concept "Other";
  node link: Relation "leads to";
}`;

// Group types of its own, so a group retype from the menu needs no C4 boundary.
export const typedGroups = `vnotation Teams {
  node type: Member [nodeStyle: roundedBox, color: "#3366cc"]
  group type: Team
  group type: Guild
  group type: Chapter
}

vgraph org: Teams "Org" {
  node lead: Member "Lead";
  group core "Core" {
    node ann: Member "Ann";
  }
}`;

// Three edge types join the one node type, so an edge between two Steps has two
// alternatives to be retyped into and the menu has to ask which.
export const retypableEdge = `vnotation Flow {
  node type: Step [nodeStyle: roundedBox, color: "#3366cc"]
  edge type: next from: Step to: Step
  edge type: blocks from: Step to: Step
  edge type: informs from: Step to: Step
}

vgraph f: Flow "Demo" {
  node s1: Step "One";
  node s2: Step "Two";
  edge s1 -> s2: next;
}`;

// Two edge types join the only node type, so a drop cannot be decided from the
// two nodes alone.
export const twoStocks = `vgraph demo: CLD "Demo" {
  node price: Stock "Price";
  node demand: Stock "Demand";
}`;
// Fetching and instantiating the wasm is ~850 ms idle but has been measured at 6 s
// under the load a full parallel run puts on the machine — too close to the 10 s
// expect default, which failed whole suites at `goto`. The 60 s test timeout still
// backstops a real boot failure.
const BOOT_TIMEOUT = 30_000;

export async function openEditor(page, vgl) {
  await page.goto(`/index.html?vgl=${encodeURIComponent(vgl)}`);
  await expect(page.locator(s.svg)).toBeVisible({ timeout: BOOT_TIMEOUT });
  await expect(page.locator(s.textarea)).toHaveValue(vgl, { timeout: BOOT_TIMEOUT });
}

export const vglText = (page) => page.locator(s.textarea).inputValue();

// Read from the computed style: ElementaryUI writes the `style` attribute but the
// browser hands it back normalised, so matching what the Swift wrote never would.
export function canUndo(page) {
  return page.evaluate(() => {
    const b = document.getElementById('vg-undo');
    return getComputedStyle(b).opacity === '1';
  });
}

// The host's own render entry. Unlike clicking a button it does not blur the
// inline editor first, which is what separates "a render closes the editor" from
// "clicking away commits".
export async function renderNow(page) {
  await page.evaluate(() => window.__vgraphRenderNow());
}

// Bottom left, not top: see known-defects.spec.js.
export async function emptyCanvas(page) {
  const box = await page.locator(s.preview).boundingBox();
  return { x: 4, y: box.height - 6 };
}

// The wrapping <g>'s box, so the label counts as part of the target.
export async function centreOf(page, selector) {
  const r = await rectOf(page, selector);
  return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
}

// A screen point at `fraction` along the edge's rendered path, through
// getScreenCTM — the same technique inline-edit-anchors.spec.js uses to find
// the label anchor. An [[Edge end]] handle is opacity:0/pointer-events:none
// until `.vgraph-edge:hover`, and the browser only grants that by landing the
// pointer on the actual painted stroke — its bounding box is not enough.
export async function edgePathPoint(page, edgeSelector, fraction) {
  return page.evaluate(
    ({ svgSel, edgeSel, fraction }) => {
      const svg = document.querySelector(svgSel);
      const path = document.querySelector(`${edgeSel} path`);
      const point = path.getPointAtLength(path.getTotalLength() * fraction);
      const p = svg.createSVGPoint();
      p.x = point.x;
      p.y = point.y;
      const t = p.matrixTransform(path.getScreenCTM());
      return { x: t.x, y: t.y };
    },
    { svgSel: s.svg, edgeSel: edgeSelector, fraction },
  );
}

// Grab an [[Edge end]] handle and drag it toward `to`, without releasing.
// Approaches along the path first — mirroring how a real drag would arrive,
// and keeping `.vgraph-edge:hover` continuously true so the handle stays
// interactive right up to the moment the pointer reaches it (ADR-0021).
export async function dragEdgeEndOver(page, edgeSelector, end, to) {
  const nearFraction = end === 'from' ? 0.05 : 0.95;
  const near = await edgePathPoint(page, edgeSelector, nearFraction);
  const handle = await centreOf(page, sel.edgeEndOn(edgeSelector, end));

  await page.mouse.move(near.x, near.y);
  await page.mouse.move(handle.x, handle.y);
  await page.mouse.down();
  await page.mouse.move(handle.x + 12, handle.y + 12);
  await page.mouse.move(to.x, to.y, { steps: 4 });
  return { handle, to };
}

export async function dragEdgeEndOnto(page, edgeSelector, end, toSelector) {
  const to = await centreOf(page, toSelector);
  await dragEdgeEndOver(page, edgeSelector, end, to);
  await page.mouse.up();
}

// Playwright's `page.mouse` always reports `pointerType: "mouse"`, and
// `page.touchscreen` only taps — so a finger *drag* has to be built by hand.
// Dispatched on whatever `elementFromPoint` returns, so it bubbles to the same
// handlers a real touch reaches.
export async function finger(page, type, x, y) {
  await page.evaluate(
    ({ type, x, y }) => {
      const down = type === 'pointerdown';
      const held = type !== 'pointerup' && type !== 'pointercancel';
      const target = document.elementFromPoint(x, y) || document.body;
      target.dispatchEvent(
        new PointerEvent(type, {
          bubbles: true,
          cancelable: true,
          composed: true,
          clientX: x,
          clientY: y,
          pointerId: 1,
          pointerType: 'touch',
          isPrimary: true,
          // A touch move carries no button, exactly as a real one does.
          button: down || type === 'pointerup' ? 0 : -1,
          buttons: held ? 1 : 0,
        }),
      );
    },
    { type, x, y },
  );
}

export async function fingerTap(page, { x, y }) {
  await finger(page, 'pointerdown', x, y);
  await finger(page, 'pointerup', x, y);
}

// Several steps, not one jump — the first must clear the 4px threshold and the
// rest are what a real drag looks like. Mirrors `dragOver` in
// drag-to-connect.spec.js so the two gestures are tested the same shape.
export async function fingerDrag(page, from, to) {
  await finger(page, 'pointerdown', from.x, from.y);
  await finger(page, 'pointermove', from.x + 12, from.y + 12);
  for (let step = 1; step <= 4; step++) {
    await finger(
      page,
      'pointermove',
      from.x + ((to.x - from.x) * step) / 4,
      from.y + ((to.y - from.y) * step) / 4,
    );
  }
  await finger(page, 'pointerup', to.x, to.y);
}

// Held past `longPressDelayMs` (500 ms in Editor.swift). The release is included
// because it is supposed to be inert once the menu has opened.
export async function fingerLongPress(page, { x, y }) {
  await finger(page, 'pointerdown', x, y);
  await page.waitForTimeout(700);
  await finger(page, 'pointerup', x, y);
}

export async function rectOf(page, selector) {
  return page.evaluate((q) => {
    const el = document.querySelector(q);
    if (!el) return null;
    const { left, top, right, bottom, width, height } = el.getBoundingClientRect();
    return { left, top, right, bottom, width, height };
  }, selector);
}

// Feeds the hidden picker directly: the real dialog is native chrome Playwright
// cannot drive, and `setInputFiles` fires the same `change` the editor listens for.
export async function openVGLFile(page, name, vgl) {
  await page.locator(s.fileInput).setInputFiles({
    name,
    mimeType: 'text/plain',
    buffer: Buffer.from(vgl, 'utf8'),
  });
}

// Picks `item` out of the File menu and reports the name the browser was told to
// save under — the only place the editor's document name is observable.
export async function savedNameOf(page, item) {
  await page.locator(s.fileMenuButton).click();
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.locator(s.fileMenuItem, { hasText: item }).click(),
  ]);
  return download.suggestedFilename();
}

export async function savedSVG(page) {
  await page.locator(s.fileMenuButton).click();
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.locator(s.fileMenuItem, { hasText: 'Save SVG' }).click(),
  ]);
  return readDownload(download);
}

export async function readDownload(download) {
  const stream = await download.createReadStream();
  const chunks = [];
  for await (const chunk of stream) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf8');
}

export async function typeInline(page, text) {
  await page.locator(s.inlineEdit).fill(text);
}

// How many times the preview was re-rendered while `during` ran. Each
// `performRender` swaps the preview's innerHTML, which is one mutation record.
export async function countRenders(page, during) {
  await page.evaluate((q) => {
    window.__renders = 0;
    window.__renderWatch = new MutationObserver((records) => {
      for (const r of records) if (r.target.id === q) window.__renders++;
    });
    window.__renderWatch.observe(document.body, { childList: true, subtree: true });
  }, 'vg-editor-preview');
  await during();
  return page.evaluate(() => {
    window.__renderWatch.disconnect();
    return window.__renders;
  });
}

// Waits for the debounced render to land, proven by the diagram; asserting on the
// textarea alone races the 400 ms debounce and every history assertion needs the
// render to have recorded a version.
export async function editVGL(page, vgl, renderedText) {
  await page.locator(s.textarea).fill(vgl);
  await expect(page.locator(s.svg)).toContainText(renderedText);
}

// A `?src=` fixture, served by route interception rather than by a file in
// `website/` — that directory is what `deploy.sh` stages onto the live site, so
// test fixtures have no business in it. The CORS header is what a real
// third-party host would have to send for a cross-origin fetch to be readable.
export async function serveSrc(page, pattern, body, opts = {}) {
  const { status = 200, contentType = 'text/plain' } = opts;
  await page.route(pattern, (route) =>
    route.fulfill({
      status,
      contentType,
      body,
      headers: { 'access-control-allow-origin': '*' },
    })
  );
}

// Boots the editor at an arbitrary query string. Waits only for the preview,
// not for particular text: a refused or missing `?src=` still leaves the default
// diagram on screen, and that is exactly what those tests assert about.
export async function openEditorAt(page, query) {
  await page.goto(`/index.html${query}`);
  await expect(page.locator(s.svg)).toBeVisible({ timeout: BOOT_TIMEOUT });
}

export async function pickView(page, label) {
  await page.locator(s.viewMenuButton).click();
  await page.locator(s.viewMenuItem).filter({ hasText: new RegExp(`^(✓ )?${label}$`) }).click();
}

// Closes the panel after: its dismiss layer would block the next click.
export async function zoomControl(page, name) {
  await page.locator(s.displayButton).click();
  await page.locator(`${s.displayPanel} button`, { hasText: name }).click();
  await closeDisplayPanel(page);
}

export async function closeDisplayPanel(page) {
  await page.locator('.vg-dismiss').click({ position: { x: 2, y: 2 } });
}

export async function useTheme(page, name) {
  await page.locator(s.displayButton).click();
  await page.locator(`${s.displayPanel} .vg-ctx-item`, { hasText: name }).click();
}
