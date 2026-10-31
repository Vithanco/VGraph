import { test, expect } from '@playwright/test';
import { s, proposition, retypableEdge, openEditor, vglText } from '../helpers/editor.js';

const item = (page, name) => page.locator(s.menuItem, { hasText: name });
// The wrapping <g>, not its path: a straight edge's path has a zero-width
// bounding box, which Playwright reads as "not visible".
const rightClickEdge = (page, modifiers = []) =>
  page.locator(s.anyEdge).first().click({ button: 'right', modifiers });

test('a type picked from the menu retypes the edge in place', async ({ page }) => {
  await openEditor(page, retypableEdge);
  await rightClickEdge(page);

  await item(page, 'Change type').click();
  await expect(page.locator(s.menuItem)).toHaveText(['blocks', 'informs']);
  await item(page, 'blocks').click();

  await expect(page.locator(s.menu)).toHaveCount(0);
  const vgl = await vglText(page);
  expect(vgl).toContain('edge s1 -> s2: blocks');
  // Both ends stayed put: retyping is not a flip (ADR-0021).
  expect(vgl).not.toContain('edge s2 -> s1');
});

// ConceptMap declares one type for Concept → Relation, so there is nothing to
// become — and no break to reach for, unlike Split in the same menu.
test('the item is greyed where the notation offers no alternative, ⌥ included', async ({ page }) => {
  await openEditor(page, proposition);
  await rightClickEdge(page);
  await expect(item(page, 'Change type')).toHaveClass(/vg-ctx-disabled/);

  await page.mouse.click(5, 5);
  await expect(page.locator(s.menu)).toHaveCount(0);
  await rightClickEdge(page, ['Alt']);

  await expect(item(page, 'Change type')).toHaveClass(/vg-ctx-disabled/);
  await expect(item(page, 'Split (breaks notation)')).not.toHaveClass(/vg-ctx-disabled/);
});
