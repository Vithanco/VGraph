// Copy and paste as VGL (Vithanco/VGraph-archive#112). Whether ⌘C and ⌘V reach the graph or the text
// is a matter of which element holds focus after a gesture, which only a real
// browser can show; what a copy holds and where a paste lands are unit tested.

import { test, expect } from '@playwright/test';
import { s, sel, openEditor, vglText, emptyCanvas } from '../helpers/editor.js';

const pair = `vgraph demo: ConceptMap "Demo" {
  node a: Concept "A";
  node b: Relation "B";
  edge a -> b;
}`;

const item = (page, text) => page.locator(s.menuItem).filter({ hasText: text });

const selectedIds = (page) =>
  page.evaluate(() => [...document.querySelectorAll('.vg-selected')].map((e) => e.id));

const chord = (page, key) => page.keyboard.press(`ControlOrMeta+${key}`);

async function selectBoth(page) {
  await page.locator(sel.node('a')).click();
  await page.locator(sel.node('b')).click({ modifiers: ['Shift'] });
}

test.beforeEach(async ({ context }) => {
  await context.grantPermissions(['clipboard-read', 'clipboard-write']);
});

test('Given two nodes selected, when ⌘C then ⌘V, then the diagram shows their duplicates', async ({ page }) => {
  await openEditor(page, pair);
  await selectBoth(page);

  await chord(page, 'c');
  await chord(page, 'v');

  await expect(page.locator(sel.node('a_2'))).toBeVisible();
  await expect(page.locator(sel.node('b_2'))).toBeVisible();
});

test('Given a paste, when ⌘Z is pressed once, then the duplicates are gone', async ({ page }) => {
  await openEditor(page, pair);
  await selectBoth(page);
  await chord(page, 'c');
  await chord(page, 'v');
  await expect(page.locator(sel.node('a_2'))).toBeVisible();

  await chord(page, 'z');

  await expect(page.locator(sel.node('a_2'))).toHaveCount(0);
  await expect(page.locator(sel.node('b_2'))).toHaveCount(0);
});

test('Given a paste, then the duplicates are the selection', async ({ page }) => {
  await openEditor(page, pair);
  await selectBoth(page);
  await chord(page, 'c');
  await chord(page, 'v');
  await expect(page.locator(sel.node('a_2'))).toBeVisible();

  expect(await selectedIds(page)).toEqual(['node-a_2', 'node-b_2']);
});

test("Given Copy chosen from a selection's menu, then the clipboard holds the selection's fragment", async ({
  page,
}) => {
  await openEditor(page, pair);
  await selectBoth(page);

  await page.locator(sel.node('a')).click({ button: 'right' });
  await item(page, 'Copy').click();

  await expect
    .poll(() => page.evaluate(() => navigator.clipboard.readText()))
    .toBe('node a: Concept "A"\nnode b: Relation "B"\nedge a -> b\n');
});

test('Given a clipboard holding a foreign type, when ⌘V in the diagram, then the diagram is unchanged', async ({
  page,
}) => {
  await openEditor(page, pair);
  await page.evaluate(() => navigator.clipboard.writeText('node c: Actor "C";'));
  await page.locator(sel.node('a')).click();

  await chord(page, 'v');

  await expect(page.locator(sel.node('c'))).toHaveCount(0);
  expect(await vglText(page)).toBe(pair);
});

test('Given text selected in the source pane, when ⌘C then ⌘V there, then the text is copied and pasted as text', async ({
  page,
}) => {
  await openEditor(page, pair);
  const textarea = page.locator(s.textarea);
  await textarea.click();
  await textarea.evaluate((t) => t.setSelectionRange(0, 'vgraph'.length));

  await chord(page, 'c');
  await textarea.evaluate((t) => t.setSelectionRange(t.value.length, t.value.length));
  await chord(page, 'v');

  expect(await vglText(page)).toBe(pair + 'vgraph');
});

test('Given a fragment on the clipboard, when Paste is chosen from the canvas menu, then it appears in the diagram', async ({
  page,
}) => {
  await openEditor(page, pair);
  await page.evaluate(() => navigator.clipboard.writeText('node c: Concept "C";'));

  await page.locator(s.preview).click({ button: 'right', position: await emptyCanvas(page) });
  await item(page, 'Paste').click();

  await expect(page.locator(sel.node('c'))).toBeVisible();
});
