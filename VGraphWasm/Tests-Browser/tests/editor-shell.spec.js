import { test, expect } from '@playwright/test';
import {
  s,
  sel,
  oneConcept,
  groupedGraph,
  openEditor,
  canUndo,
  editVGL,
  openVGLFile,
  readDownload,
  savedNameOf,
  savedSVG,
  useTheme,
} from '../helpers/editor.js';

const withLabel = (label) => oneConcept.replace('"Idea"', `"${label}"`);

test('?vgl= seeds the editor, and does so from inside the wasm', async ({ page }) => {
  await openEditor(page, oneConcept);

  await expect(page.locator(s.textarea)).toHaveValue(oneConcept);
  await expect(page.locator(sel.node('idea'))).toBeVisible();
  expect(await canUndo(page), 'host-pushed text is a new document').toBe(false);
});

test('typing re-renders after the debounce', async ({ page }) => {
  await openEditor(page, oneConcept);

  await page.locator(s.textarea).fill(`vgraph demo: ConceptMap "Demo" {
  node idea: Concept "Idea";
  node second: Concept "Second";
}`);

  await expect(page.locator(sel.node('second'))).toBeVisible();
});

test('an invalid edit keeps the last good diagram and reports the failure', async ({ page }) => {
  await openEditor(page, oneConcept);
  await expect(page.locator(sel.node('idea'))).toBeVisible();

  await page.locator(s.textarea).fill('vgraph demo: ConceptMap "Demo" { node ');

  await expect(page.locator(s.diagnostics)).toContainText('ERROR');
  await expect(page.locator(sel.node('idea'))).toBeVisible();
});

test('the diagnostics box reports the quality report', async ({ page }) => {
  await openEditor(page, oneConcept);

  await expect(page.locator(s.diagnostics)).toContainText(/WARN|INFO/);
});

test('a typing burst collapses into one undo step', async ({ page }) => {
  await openEditor(page, oneConcept);

  await editVGL(page, withLabel('Idea one'), 'Idea one');
  await editVGL(page, withLabel('Idea one two'), 'Idea one two');

  await page.locator(s.textarea).press('ControlOrMeta+z');
  await expect(page.locator(s.textarea)).toHaveValue(oneConcept);
});

test('blurring the textarea seals the run so the next edit is its own step', async ({ page }) => {
  await openEditor(page, oneConcept);

  await editVGL(page, withLabel('First'), 'First');
  await page.locator(s.textarea).blur();
  await editVGL(page, withLabel('First Second'), 'First Second');

  await page.locator(s.textarea).press('ControlOrMeta+z');
  await expect(page.locator(s.textarea)).toHaveValue(withLabel('First'));
});

test('every toolbar control stays inside the bar, clear of the diagram', async ({ page }) => {
  await openEditor(page, oneConcept);

  const strays = await page.evaluate(
    ([toolbarSel, previewSel]) => {
      const bar = document.querySelector(toolbarSel).getBoundingClientRect();
      const preview = document.querySelector(previewSel).getBoundingClientRect();
      return [...document.querySelectorAll(`${toolbarSel} select, ${toolbarSel} button`)]
        .filter((c) => {
          const r = c.getBoundingClientRect();
          return r.right > bar.right || r.bottom > preview.top;
        })
        .map((c) => c.textContent.trim());
    },
    [s.toolbar, s.preview],
  );

  expect(strays).toEqual([]);
});

// The canvas is the guide's --page: #faf9f6 light, #0e0d0a dark (Rule 4).
test('the dark toggle re-renders in the dark palette', async ({ page }) => {
  await openEditor(page, oneConcept);
  const preview = page.locator(s.preview);
  await expect(preview).toHaveCSS('background-color', 'rgb(250, 249, 246)');

  await useTheme(page, 'Dark theme');

  await expect(page.locator(s.root)).toHaveClass(/vg-dark/);
  await expect(preview).toHaveCSS('background-color', 'rgb(14, 13, 10)');
  await expect(page.locator(sel.node('idea')), 're-rendered, not just re-tinted').toBeVisible();
});

test('picking an example loads it as a new document with fresh history', async ({ page }) => {
  await openEditor(page, oneConcept);
  await editVGL(page, withLabel('Renamed'), 'Renamed');
  expect(await canUndo(page)).toBe(true);

  const examples = page.locator(s.examples);
  const name = await examples.locator('option').nth(1).textContent();
  await examples.selectOption({ label: name });

  await expect(page.locator(s.textarea)).not.toHaveValue(/"Renamed"/);
  expect(await canUndo(page)).toBe(false);
  await expect(examples, 'resets so the same example can be picked again').toHaveValue('');
});

test('the File menu saves the rendered diagram as a .vithanco.svg', async ({ page }) => {
  await openEditor(page, oneConcept);

  await page.locator(s.fileMenuButton).click();
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.locator(s.fileMenuItem, { hasText: 'Save SVG' }).click(),
  ]);

  expect(download.suggestedFilename()).toBe('vgraph-diagram.vithanco.svg');
  expect(await readDownload(download), 'the VGL rides along').toContain('<vithanco:vgl xmlns:vithanco="https://vithanco.com/ns/vgl" version="1"><![CDATA[');
  await expect(page.locator(s.fileMenu), 'the menu closes behind the save').toBeHidden();
});

test('the File menu saves the VGL the user sees, comments and all', async ({ page }) => {
  const commented = `// a note the exporter would move\n${oneConcept}`;
  await openEditor(page, commented);

  await page.locator(s.fileMenuButton).click();
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.locator(s.fileMenuItem, { hasText: 'Save VGL' }).click(),
  ]);

  expect(download.suggestedFilename()).toBe('vgraph-diagram.vgl');
  expect(await readDownload(download)).toBe(commented);
});

test('opening a .vgl loads it as a new document', async ({ page }) => {
  await openEditor(page, oneConcept);
  await editVGL(page, withLabel('Renamed'), 'Renamed');
  expect(await canUndo(page)).toBe(true);

  const opened = `vgraph opened: ConceptMap "Opened" {
  node fromfile: Concept "From file";
}`;
  await openVGLFile(page, 'my-diagram.vgl', opened);

  await expect(page.locator(s.textarea)).toHaveValue(opened);
  await expect(page.locator(sel.node('fromfile'))).toBeVisible();
  expect(await canUndo(page), 'an opened file is a new document').toBe(false);
});

test('the saved name follows the opened file, extension or not', async ({ page }) => {
  await openEditor(page, oneConcept);
  expect(await savedNameOf(page, 'Save VGL'), 'until a file is opened').toBe('vgraph-diagram.vgl');

  await openVGLFile(page, 'plain', oneConcept);
  expect(await savedNameOf(page, 'Save VGL'), 'no extension to strip').toBe('plain.vgl');
  expect(await savedNameOf(page, 'Save SVG'), 'the SVG follows it too').toBe('plain.vithanco.svg');

  await openVGLFile(page, 'two.dots.vgl', oneConcept);
  expect(await savedNameOf(page, 'Save VGL'), 'only the last extension goes').toBe('two.dots.vgl');
});

// `demo.vithanco (1).svg` is what the browser writes when the name is taken.
test('a browser collision suffix survives a round trip without accumulating', async ({ page }) => {
  await openEditor(page, oneConcept);

  await openVGLFile(page, 'demo.vithanco (1).svg', await savedSVG(page));
  expect(await savedNameOf(page, 'Save SVG')).toBe('demo (1).vithanco.svg');
  expect(await savedNameOf(page, 'Save VGL')).toBe('demo (1).vgl');

  await openVGLFile(page, 'demo (1).vithanco.svg', await savedSVG(page));
  expect(await savedNameOf(page, 'Save SVG'), 'and again, unchanged').toBe('demo (1).vithanco.svg');
});

test('a name that merely ends in brackets is left alone', async ({ page }) => {
  await openEditor(page, oneConcept);

  await openVGLFile(page, 'notes (draft).vgl', oneConcept);
  expect(await savedNameOf(page, 'Save VGL'), 'not a counter').toBe('notes (draft).vgl');
});

test('a saved SVG reopens as the document it came from', async ({ page }) => {
  await openEditor(page, groupedGraph);

  await page.locator(s.fileMenuButton).click();
  const [saved] = await Promise.all([
    page.waitForEvent('download'),
    page.locator(s.fileMenuItem, { hasText: 'Save SVG' }).click(),
  ]);
  const svg = await readDownload(saved);

  // Somewhere else entirely, so nothing but the file can put the graph back.
  await openEditor(page, oneConcept);
  await expect(page.locator(sel.node('detail'))).toBeHidden();

  await openVGLFile(page, 'round-trip.vithanco.svg', svg);

  await expect(page.locator(sel.node('detail')), 'the graph is back').toBeVisible();
  await expect(page.locator(sel.group('g1'))).toBeVisible();
  await expect(page.locator(s.textarea), 'the VGL, not the SVG markup').toHaveValue(/^vgraph demo:/);
  expect(await canUndo(page), 'a reopened diagram is a new document').toBe(false);
  // Both extensions come off, so a second save does not grow the name.
  expect(await savedNameOf(page, 'Save SVG')).toBe('round-trip.vithanco.svg');
});

test('what a file is read as follows its content, not its name', async ({ page }) => {
  await openEditor(page, groupedGraph);
  await page.locator(s.fileMenuButton).click();
  const [saved] = await Promise.all([
    page.waitForEvent('download'),
    page.locator(s.fileMenuItem, { hasText: 'Save SVG' }).click(),
  ]);
  const svg = await readDownload(saved);

  await openEditor(page, oneConcept);
  await openVGLFile(page, 'renamed-by-hand.txt', svg);

  await expect(page.locator(sel.group('g1')), 'still opened as its graph').toBeVisible();
});

test('an SVG that VGraph did not save is refused, not loaded as VGL', async ({ page }) => {
  await openEditor(page, oneConcept);

  await openVGLFile(page, 'elsewhere.svg', '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>');

  await expect(page.locator(s.status)).toContainText('carries no VGL');
  await expect(page.locator(s.textarea), 'the document is left alone').toHaveValue(oneConcept);
  await expect(page.locator(sel.node('idea'))).toBeVisible();
});

test('an open context menu swallows the click that dismisses it', async ({ page }) => {
  await openEditor(page, oneConcept);
  await page.locator(sel.node('idea')).click({ button: 'right' });
  await expect(page.locator(s.menu)).toBeVisible();

  // `force` because the dismiss layer covers the viewport: the click lands on
  // it, not on the button underneath — which is what keeps the two menus from
  // ever being open at once.
  await page.locator(s.fileMenuButton).click({ force: true });
  await expect(page.locator(s.menu)).toBeHidden();
  await expect(page.locator(s.fileMenu), 'dismissed, not swapped').toBeHidden();

  await page.locator(s.fileMenuButton).click();
  await expect(page.locator(s.fileMenu), 'the next click gets through').toBeVisible();
});

test('the rendered ids are the ones the editor resolves clicks against', async ({ page }) => {
  await openEditor(page, oneConcept);

  const stamped = await page.evaluate(
    (q) => [...document.querySelectorAll(`${q} [id]`)]
      .map((e) => e.id)
      .filter((id) => /^(node|edge|group)-/.test(id)),
    s.svg,
  );
  expect(stamped).toEqual(['node-idea']);
});
