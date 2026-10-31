import { test, expect } from '@playwright/test';
import { s, sel, groupedGraph, openEditor, rectOf, emptyCanvas } from '../helpers/editor.js';

test.beforeEach(async ({ page }) => {
  await openEditor(page, groupedGraph);
});

test('double-clicking a node opens that node', async ({ page }) => {
  await page.locator(`${sel.node('idea')} text`).last().dblclick();

  await expect(page.locator(sel.inlineEdit)).toHaveValue('Idea');
});

test('a node inside a group resolves to the node, not the group', async ({ page }) => {
  const inside = await rectOf(page, sel.node('idea'));
  const boundary = await rectOf(page, sel.group('g1'));
  expect(inside.left).toBeGreaterThan(boundary.left);
  expect(inside.right).toBeLessThan(boundary.right);

  await page.locator(`${sel.node('idea')} text`).last().dblclick();

  await expect(page.locator(sel.inlineEdit)).toHaveValue('Idea');
});

test('double-clicking the group boundary opens nothing', async ({ page }) => {
  const boundary = await rectOf(page, `${sel.group('g1')} rect`);
  // Left gutter: inside the boundary, below its title, clear of the node.
  await page.locator(`${sel.group('g1')} rect`).dblclick({
    position: { x: 4, y: boundary.height * 0.7 },
  });

  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
});

test('double-clicking the group label opens the group', async ({ page }) => {
  await page.locator(s.groupLabel).dblclick();

  await expect(page.locator(sel.inlineEdit)).toHaveValue('My Group');
});

test('double-clicking empty canvas opens nothing', async ({ page }) => {
  await page.locator(s.preview).dblclick({ position: await emptyCanvas(page) });

  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
});

test('right-clicking the group boundary reaches the group', async ({ page }) => {
  const boundary = await rectOf(page, `${sel.group('g1')} rect`);
  await page.locator(`${sel.group('g1')} rect`).click({
    button: 'right',
    position: { x: 4, y: boundary.height * 0.7 },
  });

  await expect(page.locator(s.menu)).toBeVisible();
  await expect(page.locator(s.menuItem, { hasText: 'Fold group' })).toBeVisible();
});

// Was: "right-clicking empty canvas leaves the native menu alone". Blank canvas
// used to name nothing; it now resolves to the root group, which is a real
// element the renderer simply draws nothing for (ADR-0016).
test('right-clicking empty canvas reaches the root group', async ({ page }) => {
  await page.locator(s.preview).click({ button: 'right', position: await emptyCanvas(page) });

  await expect(page.locator(s.menu)).toBeVisible();
  await expect(page.locator(s.menuItem, { hasText: 'Add node…' })).toBeVisible();
});

// Right-clicking low on the canvas used to open the menu downward past the
// window's edge, leaving its last rows (Delete, Loop markers…) unreachable.
test('a menu opened at the bottom edge stays inside the window', async ({ page }) => {
  await openEditor(page, `vgraph cld: CLD "Demo" {
  node price: Stock "Price";
  node demand: Stock "Demand";
  edge price -> demand: opposite;
  edge demand -> price: same;
}`);
  const preview = await page.locator(s.preview).boundingBox();
  await page.locator(s.preview).click({ button: 'right', position: { x: 4, y: preview.height - 6 } });

  const menu = await page.locator(s.menu).boundingBox();
  const viewport = page.viewportSize();
  expect(menu.y).toBeGreaterThanOrEqual(0);
  expect(menu.y + menu.height).toBeLessThanOrEqual(viewport.height);
});
