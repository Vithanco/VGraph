import { test, expect } from '@playwright/test';
import { s, sel, connectable, openEditor, vglText, centreOf } from '../helpers/editor.js';

const item = (page, name) => page.locator(s.menuItem, { hasText: name });

// ⌥-drag a pair ConceptMap never joins, leaving a red edge to promote.
async function breakOnto(page, fromId, toId) {
  const from = await centreOf(page, sel.node(fromId));
  const to = await centreOf(page, sel.node(toId));
  await page.keyboard.down('Alt');
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  await page.mouse.move(from.x + 12, from.y + 12);
  await page.mouse.move(to.x, to.y, { steps: 4 });
  await page.mouse.up();
  await page.keyboard.up('Alt');
  await expect(page.locator(s.diagnostics)).toContainText('invalid edge type');
}

const rightClickEdge = (page) =>
  page.locator(s.anyEdge).first().click({ button: 'right' });

test('a red edge offers a way out under Change type', async ({ page }) => {
  await openEditor(page, connectable);
  await breakOnto(page, 'idea', 'other');

  await rightClickEdge(page);
  await expect(item(page, 'Change type')).not.toHaveClass(/vg-ctx-disabled/);
  await item(page, 'Change type').click();

  // ConceptMap names nothing for Concept → Concept, so the way out is the list.
  await expect(page.locator(s.menuItem)).toHaveText(['New relationship…']);
});

test('naming it declares the relationship and clears the error', async ({ page }) => {
  await openEditor(page, connectable);
  await breakOnto(page, 'idea', 'other');

  await rightClickEdge(page);
  await item(page, 'Change type').click();
  await item(page, 'New relationship…').click();
  // Seeded from the two node types, so Return alone would do.
  await expect(page.locator(s.ctxInput)).toHaveValue('concept_to_concept');
  await page.keyboard.press('Enter');

  await expect(page.locator(s.menu)).toHaveCount(0);
  const vgl = await vglText(page);
  expect(vgl).toContain('vnotation ConceptMapExtended extends ConceptMap');
  expect(vgl).toContain('edge type: concept_to_concept');
  expect(vgl).toContain('edge idea -> other');
  expect(vgl).not.toContain('__UNKNOWN_EDGE_TYPE__');
  await expect(page.locator(s.diagnostics)).not.toContainText('invalid edge type');
});

// The promoted document is ordinary VGL, which is the point of promoting.
test('what promotion produces survives a keystroke in the text pane', async ({ page }) => {
  await openEditor(page, connectable);
  await breakOnto(page, 'idea', 'other');
  await rightClickEdge(page);
  await item(page, 'Change type').click();
  await item(page, 'New relationship…').click();
  await page.keyboard.press('Enter');
  await expect(page.locator(s.menu)).toHaveCount(0);

  await page.locator(s.textarea).click();
  await page.keyboard.press('End');
  await page.keyboard.type(' ');

  await expect(page.locator(s.diagnostics)).not.toContainText('Parsing error');
});

// A name the parser would refuse re-opens the field rather than closing the menu.
test('a bad name asks again', async ({ page }) => {
  await openEditor(page, connectable);
  await breakOnto(page, 'idea', 'other');
  await rightClickEdge(page);
  await item(page, 'Change type').click();
  await item(page, 'New relationship…').click();

  await page.locator(s.ctxInput).fill('2fast');
  await page.keyboard.press('Enter');

  await expect(page.locator(s.ctxInput)).toHaveValue('2fast');
  expect(await vglText(page)).not.toContain('2fast');
});
