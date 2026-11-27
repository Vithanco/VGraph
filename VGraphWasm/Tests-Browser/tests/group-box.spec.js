// A CLD is laid out by neato, which in the wasm build of Graphviz (no
// IPSEPCOLA) never writes a cluster's box. Read from there, the box was whatever
// that memory held, and now and then so large that the render trapped.

import { test, expect } from '@playwright/test';
import { s, sel, openEditor } from '../helpers/editor.js';

const bundled = `vgraph demo: CLD "Demo" {
  node a: Stock "A";
  folded group g "G" {
    node x1: Stock "X1";
    node x2: Stock "X2";
  }
  edge a -> x1: same;
  edge a -> x2: same;
}`;

const box = (page, selector) => page.locator(selector).evaluate((e) => {
  const r = e.getBoundingClientRect();
  return { left: r.left, top: r.top, right: r.right, bottom: r.bottom };
});

test('a group unfolded in a neato layout is drawn around its members', async ({ page }) => {
  await openEditor(page, bundled);
  await page.locator('.vgraph-edge-bundle text', { hasText: '×' }).last().click({ button: 'right' });
  await page.locator(s.menuItem, { hasText: 'Unfold' }).click();
  await expect(page.locator(sel.node('x1'))).toBeVisible();
  // Measured where the nodes land, not mid-glide.
  await page.waitForFunction(() => document.getAnimations().length === 0);

  const group = await box(page, `${sel.group('g')} > rect`);
  // A node's stroke reaches a hair past the box neato lays out.
  const slack = 1;
  for (const member of ['x1', 'x2']) {
    const node = await box(page, sel.node(member));
    expect(group.left, member).toBeLessThanOrEqual(node.left + slack);
    expect(group.top, member).toBeLessThanOrEqual(node.top + slack);
    expect(group.right, member).toBeGreaterThanOrEqual(node.right - slack);
    expect(group.bottom, member).toBeGreaterThanOrEqual(node.bottom - slack);
  }
});
