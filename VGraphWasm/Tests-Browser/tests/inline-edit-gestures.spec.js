import { test, expect } from '@playwright/test';
import {
  sel, oneConcept, openEditor, vglText, canUndo, renderNow, typeInline, emptyCanvas,
  countRenders,
} from '../helpers/editor.js';

test.beforeEach(async ({ page }) => {
  await openEditor(page, oneConcept);
  await page.locator(`${sel.node('idea')} text`).last().dblclick();
  await expect(page.locator(sel.inlineEdit)).toBeVisible();
});

test('opens seeded from the graph, with its text selected', async ({ page }) => {
  await expect(page.locator(sel.inlineEdit)).toHaveValue('Idea');

  const selected = await page.evaluate(() => {
    const f = document.getElementById('vg-inline-edit');
    return f.value.slice(f.selectionStart, f.selectionEnd);
  });
  expect(selected, 'typing must replace the label, not append to it').toBe('Idea');
});

test('Return commits', async ({ page }) => {
  await typeInline(page, 'Committed');
  await page.keyboard.press('Enter');

  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
  expect(await vglText(page)).toContain('"Committed"');
  expect(await canUndo(page)).toBe(true);
});

// Committing removes the field and refocuses the textarea mid-keydown, so without
// `preventDefault` the Enter's own default action ran against the textarea: it
// typed a newline into the document and armed the 400 ms debounce, whose render
// then closed any editor reopened in the meantime.
test('the Enter that commits does not reach the textarea', async ({ page }) => {
  await typeInline(page, 'First');

  const renders = await countRenders(page, async () => {
    await page.keyboard.press('Enter');
    await expect(page.locator(sel.svg)).toContainText('First');
    await page.waitForTimeout(700);  // longer than the 400 ms debounce
  });

  expect(renders, 'a commit renders once').toBe(1);
  expect(await vglText(page), 'Enter must not type into the textarea').not.toMatch(/\n\n$/);
});

test('clicking away commits', async ({ page }) => {
  await typeInline(page, 'Blurred');
  await page.locator(sel.preview).click({ position: await emptyCanvas(page) });

  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
  expect(await vglText(page)).toContain('"Blurred"');
});

test('Escape discards, and the blur it causes does not commit', async ({ page }) => {
  await typeInline(page, 'Discarded');
  await page.keyboard.press('Escape');

  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
  const vgl = await vglText(page);
  expect(vgl).toContain('"Idea"');
  expect(vgl).not.toContain('Discarded');
  await expect(page.locator(sel.svg)).toContainText('Idea');
});

// Promoted from known-defects.spec.js: opening the editor used to route through
// `setLabel` with no answer, which returned `.done` on an unchanged graph —
// recording a version and writing `exportVGL()` back over the user's own
// formatting. Looking at a label reformatted the document and left an undo step.
test('a double-click that is then cancelled leaves the VGL untouched', async ({ page }) => {
  await page.keyboard.press('Escape');
  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);

  expect(await vglText(page)).toBe(oneConcept);
  expect(await canUndo(page)).toBe(false);
});

test('a render closes the editor and discards', async ({ page }) => {
  await typeInline(page, 'Lost to a render');
  await renderNow(page);

  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
  const vgl = await vglText(page);
  expect(vgl).toContain('"Idea"');
  expect(vgl).not.toContain('Lost to a render');
});

// Undo bubbles out of the field to the root handler, so it renders without ever
// blurring — the ordering ADR-0009 calls out.
test('undo from inside the field closes the editor and discards', async ({ page }) => {
  await typeInline(page, 'First');
  await page.keyboard.press('Enter');
  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
  await expect(page.locator(sel.svg)).toContainText('First');

  await page.locator(`${sel.node('idea')} text`).last().dblclick();
  await expect(page.locator(sel.inlineEdit)).toBeVisible();
  await typeInline(page, 'Second');
  await page.keyboard.press('ControlOrMeta+z');

  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
  expect(await vglText(page)).not.toContain('Second');
});

// Reopening within the 400 ms debounce window used to lose the field: the commit
// armed a render (see known-defects) and a render closes the editor (ADR-0009).
test('reopening right after a commit survives the render debounce', async ({ page }) => {
  await typeInline(page, 'First');
  await page.keyboard.press('Enter');
  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
  await expect(page.locator(sel.svg)).toContainText('First');

  await page.locator(`${sel.node('idea')} text`).last().dblclick();
  await expect(page.locator(sel.inlineEdit)).toBeVisible();

  // A wait, not a poll: the claim is that nothing happens for longer than the
  // debounce, and a poll would pass inside the very window this guards.
  await page.waitForTimeout(700);
  await expect(page.locator(sel.inlineEdit)).toBeVisible();
  await expect(page.locator(sel.inlineEdit)).toHaveValue('First');
});

test('committing an empty label restores the placeholder', async ({ page }) => {
  await typeInline(page, '');
  await page.keyboard.press('Enter');

  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
  expect(
    await vglText(page),
    'the exporter omits an empty label and the parser then defaults it to the id',
  ).toContain('"Change Me"');
});

test('a commit is one undo step and is fully reversible', async ({ page }) => {
  await typeInline(page, 'Renamed');
  await page.keyboard.press('Enter');
  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
  expect(await vglText(page)).toContain('"Renamed"');

  await page.locator(sel.textarea).press('ControlOrMeta+z');
  await expect(page.locator(sel.textarea)).toHaveValue(/"Idea"/);

  await page.locator(sel.textarea).press('ControlOrMeta+Shift+z');
  await expect(page.locator(sel.textarea)).toHaveValue(/"Renamed"/);
});
