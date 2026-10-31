import { test, expect } from '@playwright/test';
import { s, typedGroups, groupedGraph, openEditor, vglText } from '../helpers/editor.js';

const item = (page, name) => page.locator(s.menuItem, { hasText: name });
const rightClickGroup = (page) => page.locator(s.groupLabel).click({ button: 'right' });

test('a boundary kind picked from the menu types the group', async ({ page }) => {
  await openEditor(page, typedGroups);
  await rightClickGroup(page);

  await item(page, 'Change type').click();
  await expect(page.locator(s.menuItem)).toHaveText([
    'Team', 'Guild', 'Chapter',
  ]);
  await page.locator(s.menuItem, { hasText: 'Team' }).click();

  await expect(page.locator(s.menu)).toHaveCount(0);
  expect(await vglText(page)).toContain('group core: Team "Core"');
});

// Untyped is a real state, not the absence of one, so the way back has to be
// clickable too (ADR-0020).
test('Plain group takes the boundary kind away again', async ({ page }) => {
  await openEditor(page, typedGroups);
  await rightClickGroup(page);
  await item(page, 'Change type').click();
  await page.locator(s.menuItem, { hasText: 'Team' }).click();
  await expect(page.locator(s.menu)).toHaveCount(0);

  await rightClickGroup(page);
  await item(page, 'Change type').click();
  await item(page, 'Plain group').click();

  const vgl = await vglText(page);
  expect(vgl).toContain('group core "Core"');
  expect(vgl).not.toContain('group core: Team');
});

// ConceptMap registers no boundary kinds, so there is nothing to ask and ⌥
// reaches nothing either — the item is greyed, not breakable.
test('the item is greyed where the notation has no boundaries', async ({ page }) => {
  await openEditor(page, groupedGraph);
  await rightClickGroup(page);

  await expect(item(page, 'Change type')).toHaveClass(/vg-ctx-disabled/);
});
