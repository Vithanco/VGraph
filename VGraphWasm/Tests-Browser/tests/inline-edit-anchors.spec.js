import { test, expect } from '@playwright/test';
import { s, sel, groupedGraph, openEditor, rectOf } from '../helpers/editor.js';

const near = (a, b, tolerance = 2) => Math.abs(a - b) <= tolerance;

test('a node anchors on its own client rect', async ({ page }) => {
  await openEditor(page, groupedGraph);
  const node = await rectOf(page, sel.node('detail'));

  await page.locator(`${sel.node('detail')} text`).last().dblclick();
  await expect(page.locator(sel.inlineEdit)).toBeVisible();
  const overlay = await rectOf(page, sel.inlineEdit);

  expect(near(overlay.left, node.left)).toBe(true);
  expect(near(overlay.top, node.top)).toBe(true);
  expect(overlay.width, 'narrow elements get a floor').toBeGreaterThanOrEqual(90);
});

test('a group anchors on its label, not on its boundary', async ({ page }) => {
  await openEditor(page, groupedGraph);
  const boundary = await rectOf(page, sel.group('g1'));
  const label = await rectOf(page, s.groupLabel);

  await page.locator(s.groupLabel).dblclick();
  await expect(page.locator(sel.inlineEdit)).toBeVisible();
  const overlay = await rectOf(page, sel.inlineEdit);

  expect(near(overlay.left, label.left)).toBe(true);
  expect(near(overlay.top, label.top)).toBe(true);
  expect(near(overlay.top, boundary.top)).toBe(false);
});

test('a group is seeded from the graph, not from its uppercased rendering', async ({ page }) => {
  await openEditor(page, groupedGraph);

  await expect(page.locator(s.groupLabel)).toHaveText('MY GROUP');
  await page.locator(s.groupLabel).dblclick();

  await expect(page.locator(sel.inlineEdit)).toHaveValue('My Group');
});

test('an edge anchors on its rendered path midpoint, through getScreenCTM', async ({ page }) => {
  await openEditor(page, groupedGraph);

  const viewBox = await page.locator(s.svg).getAttribute('viewBox');
  expect(viewBox.startsWith('-'), `viewBox origin must be negative, got ${viewBox}`).toBe(true);

  const { screen, naive } = await page.evaluate(({ svgSel, edgeSel }) => {
    const svg = document.querySelector(svgSel);
    const path = document.querySelector(`${edgeSel} path`);
    const mid = path.getPointAtLength(path.getTotalLength() / 2);
    const p = svg.createSVGPoint();
    p.x = mid.x;
    p.y = mid.y;
    const t = p.matrixTransform(path.getScreenCTM());
    const box = svg.getBoundingClientRect();
    return {
      screen: { x: t.x, y: t.y },
      naive: { x: box.left + mid.x, y: box.top + mid.y },
    };
  }, { svgSel: s.svg, edgeSel: s.anyEdge });

  await page.locator(`${s.anyEdge} path`).dblclick({ force: true });
  await expect(page.locator(sel.inlineEdit)).toBeVisible();

  const overlay = await rectOf(page, sel.inlineEdit);
  expect(near(overlay.left + 70, screen.x)).toBe(true);
  expect(near(overlay.top + 12, screen.y)).toBe(true);
  expect(near(overlay.width, 140)).toBe(true);

  const drift = Math.hypot(screen.x - naive.x, screen.y - naive.y);
  expect(drift, 'user-space and screen coords must differ for this to prove anything')
    .toBeGreaterThan(20);

  const edge = await rectOf(page, s.anyEdge);
  const centre = { x: overlay.left + overlay.width / 2, y: overlay.top + overlay.height / 2 };
  expect(centre.x).toBeGreaterThanOrEqual(edge.left - 4);
  expect(centre.x).toBeLessThanOrEqual(edge.right + 4);
  expect(centre.y).toBeGreaterThanOrEqual(edge.top - 4);
  expect(centre.y).toBeLessThanOrEqual(edge.bottom + 4);
});

test('an unlabelled edge opens an empty field, and commits a label into the VGL', async ({ page }) => {
  await openEditor(page, groupedGraph);

  await page.locator(`${s.anyEdge} path`).dblclick({ force: true });
  await expect(page.locator(sel.inlineEdit)).toHaveValue('');

  await page.locator(sel.inlineEdit).fill('leads to');
  await page.keyboard.press('Enter');

  await expect(page.locator(sel.textarea)).toHaveValue(/leads to/);
});
