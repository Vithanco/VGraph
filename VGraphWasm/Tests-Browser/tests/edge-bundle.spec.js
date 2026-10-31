// An [[Edge bundle]]: several edges running the same way into a folded box,
// drawn as one (ADR-0027). It is not an element of the OriginGraph, so what the
// browser needs to prove is that it offers nothing an edge would — only to
// unfold the group it runs into.

import { test, expect } from '@playwright/test';
import { s, sel, openEditor, vglText } from '../helpers/editor.js';

const bundled = `vgraph demo: CLD "Demo" {
  node a: Stock "A";
  folded group g "G" {
    node x1: Stock "X1";
    node x2: Stock "X2";
  }
  edge a -> x1: same;
  edge a -> x2: same;
}`;

const bundle = '.vgraph-edge-bundle';
// Edge labels are drawn twice, halo then text, and a CLD link adds its polarity
// mark: the count is the last text reading "×".
const label = (page) => page.locator(`${bundle} text`, { hasText: '×' }).last();
const item = (page, name) => page.locator(s.menuItem, { hasText: name });

test('two edges into a folded box are drawn as one, with the count', async ({ page }) => {
  await openEditor(page, bundled);

  await expect(page.locator(bundle)).toHaveCount(1);
  await expect(label(page)).toHaveText('×2');
  // One type among the members, so the bundle keeps its look — polarity mark included.
  await expect(page.locator(`${bundle} text`, { hasText: '+' })).not.toHaveCount(0);
  await expect(page.locator(`${bundle} title`)).toHaveText('A → X1 (same)\nA → X2 (same)');
});

test('right-clicking a bundle offers only to unfold, and unfolding works', async ({ page }) => {
  await openEditor(page, bundled);

  await label(page).click({ button: 'right' });
  await expect(page.locator(s.menuItem)).toHaveText(['Unfold “G”']);

  await item(page, 'Unfold').click();
  expect(await vglText(page)).not.toContain('folded group g');
  await expect(page.locator(bundle)).toHaveCount(0);
});

test('double-clicking a bundle opens no editor', async ({ page }) => {
  await openEditor(page, bundled);

  await label(page).dblclick();
  await page.waitForTimeout(300);
  await expect(page.locator(s.inlineEdit)).toHaveCount(0);
  expect(await vglText(page)).toBe(bundled);
});
