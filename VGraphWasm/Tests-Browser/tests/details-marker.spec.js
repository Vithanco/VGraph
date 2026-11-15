// Folded, a detailed node draws exactly as a node of its type (ADR-0032), so
// the editor marks it as having details. The mark is the editor's: the SVG it
// saves carries none.

import { test, expect } from '@playwright/test';
import { s, sel, openEditor, editVGL, renderNow, savedSVG, useTheme } from '../helpers/editor.js';

const banking = `vgraph banking: C4 "Internet Banking" {
  node customer: Person "Customer";
  node mainframe: SoftwareSystem "Mainframe";
  group ibs: SoftwareSystem "Internet Banking System" {
    node web: Container "Webapp";
  }
  folded group bank "Big Bank" {
    node teller: Person "Teller";
  }
  edge customer -> web;
}`;

const marker = '.vg-details-marker';
const folded = (id) => `${sel.group(id)}.vgraph-folded-group`;

test('a folded detailed node is marked as having details, and nothing else is', async ({ page }) => {
  await openEditor(page, banking);
  await expect(page.locator(folded('ibs'))).toBeVisible();
  await expect(page.locator(folded('bank')), 'a folded plain group').toBeVisible();

  await expect(page.locator(`${sel.group('ibs')} ${marker}`)).toHaveCount(1);
  await expect(page.locator(`${s.svg} ${marker}`)).toHaveCount(1);
  await expect(page.locator(marker), 'the count of details unfolding reveals').toHaveText('+1');
});

test('the marker sits inside the box it marks', async ({ page }) => {
  await openEditor(page, banking);

  const box = await page.locator(`${sel.group('ibs')} > g`).first().boundingBox();
  const mark = await page.locator(marker).boundingBox();
  expect(mark.x).toBeGreaterThanOrEqual(box.x);
  expect(mark.y).toBeGreaterThanOrEqual(box.y);
  expect(mark.x + mark.width).toBeLessThanOrEqual(box.x + box.width);
  expect(mark.y + mark.height).toBeLessThanOrEqual(box.y + box.height);
  // Bottom-right, so it never meets the URL badge in the top-right corner.
  expect(mark.x).toBeGreaterThan(box.x + box.width / 2);
  expect(mark.y).toBeGreaterThan(box.y + box.height / 2);
});

// The box outlives a render (ADR-0015 F1), so last render's marker is still in it.
test('a second render leaves one marker, not two', async ({ page }) => {
  await openEditor(page, banking);
  await expect(page.locator(marker)).toHaveCount(1);

  await renderNow(page);
  await renderNow(page);

  await expect(page.locator(folded('ibs'))).toBeVisible();
  await expect(page.locator(marker)).toHaveCount(1);
});

// A folded box glides to its new place like any node (ADR-0015 F1), and the
// marker is painted when the glide has only just begun. Undo moves the box
// here because typing would: its debounced second render repaints the marker
// and hides one left behind.
test('the marker travels with a box that a render moves', async ({ page }) => {
  await openEditor(page, banking);
  const acrossBox = () =>
    page.evaluate(
      ({ boxSel, markSel }) => {
        const box = document.querySelector(boxSel).getBoundingClientRect();
        const mark = document.querySelector(markSel).getBoundingClientRect();
        return { at: (mark.x - box.x) / box.width, boxX: box.x };
      },
      { boxSel: `${sel.group('ibs')} > g`, markSel: marker },
    );
  await editVGL(
    page,
    banking.replace('edge customer -> web;', 'edge customer -> web;\n  edge customer -> mainframe;'),
    'Mainframe',
  );
  await page.waitForTimeout(800);  // the debounced render and its glide
  const moved = await acrossBox();

  await page.locator(s.undo).click();
  await page.waitForTimeout(500);  // past the glide
  const back = await acrossBox();

  expect(back.boxX, 'undo moves the box').not.toBeCloseTo(moved.boxX, 0);
  expect(back.at).toBeCloseTo(moved.at, 2);
  expect(back.at).toBeGreaterThan(0.5);
});

// Style guide §13: --pill-bg chip, --ink-2 count, in either theme.
test('the marker takes the guide\'s colours in light and dark', async ({ page }) => {
  await openEditor(page, banking);
  await expect(page.locator(`${marker} rect`)).toHaveCSS('fill', 'rgb(238, 236, 232)');
  await expect(page.locator(`${marker} text`)).toHaveCSS('fill', 'rgb(90, 86, 78)');

  await useTheme(page, 'Dark theme');

  await expect(page.locator(`${marker} rect`)).toHaveCSS('fill', 'rgb(38, 36, 32)');
  await expect(page.locator(`${marker} text`)).toHaveCSS('fill', 'rgb(168, 164, 154)');
});

test('unfolded, a detailed node shows its details and loses the marker', async ({ page }) => {
  await openEditor(page, banking);

  await page.locator(sel.group('ibs')).click({ button: 'right' });
  await page.locator(s.menuItem, { hasText: 'Unfold' }).click();

  await expect(page.locator(sel.node('web'))).toBeVisible();
  await expect(page.locator(marker)).toHaveCount(0);
});

test('the saved SVG carries no marker', async ({ page }) => {
  await openEditor(page, banking);
  await expect(page.locator(marker)).toHaveCount(1);

  const svg = await savedSVG(page);
  expect(svg).toContain('vgraph-folded-group');
  expect(svg).not.toContain('vg-details-marker');
});
