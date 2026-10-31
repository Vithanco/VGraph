// Which loops a Causal Loop Diagram marks is the author's choice (ADR-0028),
// reached from the canvas menu. What only a browser shows is the whole trip:
// the menu row, the question, and the markers going away on the answer.

import { test, expect } from '@playwright/test';
import { s, openEditor, vglText, emptyCanvas } from '../helpers/editor.js';

const loop = `vgraph cld: CLD "Demo" {
  node price: Stock "Price";
  node demand: Stock "Demand";
  edge price -> demand: opposite;
  edge demand -> price: same;
}`;

const item = (page, name) => page.locator(s.menuItem, { hasText: name });
const rightClickCanvas = async (page) =>
  page.locator(s.preview).click({ button: 'right', position: await emptyCanvas(page) });

test('the canvas menu sets which loops are marked', async ({ page }) => {
  await openEditor(page, loop);
  await expect(page.locator('.loop-indicator')).toHaveCount(1);

  await rightClickCanvas(page);
  await item(page, 'Loop markers…').click();
  await expect(page.locator(s.menuItem)).toHaveText(['All loops ✓', 'Independent loops', 'No loop markers']);

  await item(page, 'No loop markers').click();
  await expect(page.locator('.loop-indicator')).toHaveCount(0);
  expect(await vglText(page)).toContain('loopmarkers: none');
});
