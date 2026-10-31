// Zoom, "hide source" and focus mode. None of it is document state.

import { test, expect } from '@playwright/test';
import {
  s, sel, openEditor, oneConcept, typedGroups, connectable, boxedGraph, centreOf, rectOf, typeInline, vglText, zoomControl, closeDisplayPanel,
  useTheme,
} from '../helpers/editor.js';

const wide = `vgraph demo: ConceptMap "Demo" {
  rankdir: LR;
${Array.from({ length: 14 }, (_, i) => `  node n${i}: Concept "Node number ${i}";`).join('\n')}
${Array.from({ length: 13 }, (_, i) => `  edge n${i} -> n${i + 1};`).join('\n')}
}`;

const box = async (page, selector) => (await page.locator(selector).boundingBox());
const natural = (page) =>
  page.locator(s.svg).evaluate((el) => ({ w: el.viewBox.baseVal.width, h: el.viewBox.baseVal.height }));
const label = (page) => page.locator(s.displayButton);
const button = (page, name) => page.locator(`${s.toolbar} button`, { hasText: name });

test.use({ viewport: { width: 1200, height: 700 } });

test('a diagram bigger than the pane starts fitted, with no scrolling', async ({ page }) => {
  await openEditor(page, wide);

  const pane = await box(page, s.preview);
  const svg = await box(page, s.svg);
  expect(svg.width).toBeLessThanOrEqual(pane.width);
  expect(svg.height).toBeLessThanOrEqual(pane.height);
  await expect(label(page)).toHaveText('Auto ▾');
  expect(await page.locator(s.preview).evaluate((el) => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(0);
});

test('a small diagram is not enlarged to fill the pane', async ({ page }) => {
  await openEditor(page, oneConcept);
  const { w } = await natural(page);
  expect((await box(page, s.svg)).width).toBeCloseTo(w, 0);
});

test('100% draws the natural size and the preview scrolls', async ({ page }) => {
  await openEditor(page, wide);
  const { w, h } = await natural(page);

  await zoomControl(page, '100%');

  await expect(label(page)).toHaveText('100% ▾');
  const svg = await box(page, s.svg);
  expect(svg.width).toBeCloseTo(w, 0);
  expect(svg.height).toBeCloseTo(h, 0);
  expect(await page.locator(s.preview).evaluate((el) => el.scrollWidth > el.clientWidth)).toBe(true);
});

test('+ and − step the zoom and Fit returns to fitting', async ({ page }) => {
  await openEditor(page, wide);
  await zoomControl(page, '100%');

  await zoomControl(page, '+');
  await expect(label(page)).toHaveText('125% ▾');
  await zoomControl(page, '−');
  await zoomControl(page, '−');
  await expect(label(page)).toHaveText('90% ▾');

  await zoomControl(page, 'Fit');
  await expect(label(page)).toHaveText('Auto ▾');
  const pane = await box(page, s.preview);
  expect((await box(page, s.svg)).width).toBeLessThanOrEqual(pane.width);
});

test('stepping out of fit starts from the fitted scale', async ({ page }) => {
  await openEditor(page, wide);
  const { w } = await natural(page);
  const fitted = (await box(page, s.svg)).width / w;

  await zoomControl(page, '+');

  const drawn = (await box(page, s.svg)).width / w;
  expect(drawn).toBeGreaterThan(fitted);
  expect(drawn).toBeLessThan(fitted * 1.6);
});

test('ctrl+wheel zooms and stops the browser zooming the page', async ({ page }) => {
  await openEditor(page, wide);
  await zoomControl(page, '100%');
  const before = (await box(page, s.svg)).width;

  const prevented = await page.locator(s.preview).evaluate((el) => {
    const event = new WheelEvent('wheel', { deltaY: -40, ctrlKey: true, bubbles: true, cancelable: true });
    el.dispatchEvent(event);
    return event.defaultPrevented;
  });

  expect(prevented, 'a passive listener would let the page zoom too').toBe(true);
  expect((await box(page, s.svg)).width).toBeGreaterThan(before);
});

test('a plain wheel still scrolls', async ({ page }) => {
  await openEditor(page, wide);
  await zoomControl(page, '100%');

  const prevented = await page.locator(s.preview).evaluate((el) => {
    const event = new WheelEvent('wheel', { deltaY: 40, bubbles: true, cancelable: true });
    el.dispatchEvent(event);
    return event.defaultPrevented;
  });

  expect(prevented).toBe(false);
  await expect(label(page)).toHaveText('100% ▾');
});

test('a node is still hit at a fixed zoom', async ({ page }) => {
  await openEditor(page, wide);
  await zoomControl(page, '100%');
  await zoomControl(page, '+');

  await page.locator(sel.node('n0')).click({ button: 'right' });

  await expect(page.locator(s.menu)).toBeVisible();
  await expect(page.locator(s.menuItem).first()).toBeVisible();
});

test('hiding the source gives the preview the width', async ({ page }) => {
  await openEditor(page, wide);
  const before = (await box(page, s.preview)).width;

  await page.locator(s.sourceToggle).click();

  await expect(page.locator(s.textarea)).toBeHidden();
  expect((await box(page, s.preview)).width).toBeGreaterThan(before + 300);

  await page.locator(s.sourceToggle).click();
  await expect(page.locator(s.textarea)).toBeVisible();
  expect((await box(page, s.preview)).width).toBeCloseTo(before, 0);
});

test('fit follows the pane when the source is hidden', async ({ page }) => {
  await openEditor(page, wide);
  const before = (await box(page, s.svg)).width;

  await page.locator(s.sourceToggle).click();

  await expect.poll(async () => (await box(page, s.svg)).width).toBeGreaterThan(before);
});

test('hiding the source also gives the preview the height', async ({ page }) => {
  await openEditor(page, typedGroups);
  const before = await box(page, s.preview);

  await page.locator(s.sourceToggle).click();

  await expect.poll(async () => (await box(page, s.preview)).height).toBeGreaterThan(before.height);
  const pane = await box(page, s.preview);
  const strip = await box(page, s.diagnosticsHead);
  expect(pane.y + pane.height).toBeLessThanOrEqual(strip.y + 1);
  expect(strip.y + strip.height).toBeCloseTo(700, 0);
});

test('with the source hidden, the diagnostics pane is a one-line strip', async ({ page }) => {
  await openEditor(page, typedGroups);
  await page.locator(s.sourceToggle).click();

  await expect(page.locator(s.diagnosticsHead)).toContainText('Rendered');
  await expect(page.locator(s.diagnostics)).toBeHidden();
  expect((await box(page, s.diagnosticsHead)).height).toBeLessThan(40);
});

test('a failed render is still reported when the source is hidden', async ({ page }) => {
  await openEditor(page, oneConcept);
  await page.locator(s.textarea).fill('vgraph demo: ConceptMap "Demo" { node');
  await expect(page.locator(s.status)).toContainText('Render failed');
  await page.locator(s.sourceToggle).click();

  await expect(page.locator(s.diagnosticsHead)).toContainText('Render failed');
  await page.locator(s.diagnosticsHead).click();
  await expect(page.locator(s.diagnostics)).toBeVisible();
  const before = await box(page, s.preview);

  await page.locator(s.diagnosticsHead).click();
  await expect(page.locator(s.diagnostics)).toBeHidden();
  expect((await box(page, s.preview)).height, 'opening the list does not resize the preview').toBe(before.height);
});

test('zoom and hiding the source do not touch the document', async ({ page }) => {
  await openEditor(page, wide);
  await page.locator(s.sourceToggle).click();
  await zoomControl(page, '+');
  await page.locator(s.sourceToggle).click();

  await expect(page.locator(s.textarea)).toHaveValue(wide);
  await expect(page.locator(s.undo)).toHaveClass(/vg-unavailable/);
});

test('a fixed zoom survives a re-render', async ({ page }) => {
  await openEditor(page, wide);
  await zoomControl(page, '100%');
  const before = (await box(page, s.svg)).width;

  await page.locator(s.textarea).fill(wide.replace('Node number 0', 'Nude number 0'));

  await expect(page.locator(sel.node('n0'))).toContainText('Nude number 0');
  expect((await box(page, s.svg)).width).toBeCloseTo(before, 0);
  await expect(label(page)).toHaveText('100% ▾');
});

test('fit survives a re-render', async ({ page }) => {
  await openEditor(page, wide);
  const pane = await box(page, s.preview);

  await page.locator(s.textarea).fill(wide.replace('Node number 0', 'Nude number 0'));

  await expect(page.locator(sel.node('n0'))).toContainText('Nude number 0');
  expect((await box(page, s.svg)).width).toBeLessThanOrEqual(pane.width);
});

// Hit tests, the inline editor's position and the rubber band all read screen
// coordinates, so they are the things a scaled SVG could get wrong.
test.describe('at 150%', () => {
  async function zoomTo150(page) {
    await zoomControl(page, '100%');
    await zoomControl(page, '+');
    await zoomControl(page, '+');
    await expect(label(page)).toHaveText('150% ▾');
  }

  test('the inline label editor opens over the node it edits', async ({ page }) => {
    await openEditor(page, oneConcept);
    await zoomTo150(page);

    await page.locator(`${sel.node('idea')} text`).last().dblclick();
    await expect(page.locator(s.inlineEdit)).toBeVisible();

    const node = await rectOf(page, sel.node('idea'));
    const field = await box(page, s.inlineEdit);
    const centre = { x: field.x + field.width / 2, y: field.y + field.height / 2 };
    expect(centre.x).toBeGreaterThan(node.left);
    expect(centre.x).toBeLessThan(node.left + node.width);
    expect(centre.y).toBeGreaterThan(node.top);
    expect(centre.y).toBeLessThan(node.top + node.height);

    await typeInline(page, 'Zoomed');
    await page.keyboard.press('Enter');
    expect(await vglText(page)).toContain('"Zoomed"');
  });

  test('dragging one node onto another connects them', async ({ page }) => {
    await openEditor(page, connectable);
    await zoomTo150(page);
    const from = await centreOf(page, sel.node('idea'));
    const to = await centreOf(page, sel.node('link'));

    await page.mouse.move(from.x, from.y);
    await page.mouse.down();
    await page.mouse.move(from.x + 12, from.y + 12);
    await page.mouse.move(to.x, to.y, { steps: 4 });
    await page.mouse.up();

    await expect(page.locator(s.textarea)).toHaveValue(/edge idea -> link/);
  });

  test('a rubber band catches what it encloses', async ({ page }) => {
    await openEditor(page, boxedGraph);
    await zoomTo150(page);
    const one = await rectOf(page, sel.node('outside'));
    const pane = await box(page, s.preview);

    await page.mouse.move(pane.x + 4, one.top - 12);
    await page.mouse.down();
    await page.mouse.move(one.left + one.width + 12, one.top + one.height + 12, { steps: 10 });
    await page.mouse.up();

    const selected = await page.evaluate(() =>
      [...document.querySelectorAll('.vg-selected')].map((e) => e.id));
    expect(selected).toContain('node-outside');
  });
});
