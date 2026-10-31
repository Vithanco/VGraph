// Everything about views can be done in the editor without writing VGL: the
// picker switches, the View menu manages, and presentation changes go to the
// view being shown (ADR-0029). What only a browser shows is the whole trip.

import { test, expect } from '@playwright/test';
import { s, sel, openEditor, openEditorAt, vglText, pickView } from '../helpers/editor.js';

const doc = `vgraph demo: ConceptMap "Demo" {
  group g1 "My Group" {
    node idea: Concept "Idea";
  };
  node detail: Concept "Detail";
}`;

const menuItem = (page, name) => page.locator(s.viewMenuItem, { hasText: name });

async function createView(page, label) {
  await page.locator(s.viewMenuButton).click();
  await menuItem(page, 'New view…').click();
  await page.locator(s.ctxInput).fill(label);
  await page.keyboard.press('Enter');
}

async function foldGroup(page) {
  await page.locator(s.groupLabel).click({ button: 'right' });
  await page.locator(s.menuItem, { hasText: 'Fold group' }).click();
}

const folded = (page) => page.locator(`${sel.group('g1')}.vgraph-folded-group`);

test('a group folded in a view is open in the default view', async ({ page }) => {
  await openEditor(page, doc);
  await createView(page, 'Containers');
  await foldGroup(page);
  await expect(folded(page)).toBeVisible();

  await pickView(page, 'Default view');
  await expect(folded(page)).toHaveCount(0);
  await expect(page.locator(sel.node('idea'))).toBeVisible();

  await pickView(page, 'Containers');
  await expect(folded(page)).toBeVisible();
});

test('a view is relabelled from the View menu', async ({ page }) => {
  await openEditor(page, doc);
  await createView(page, 'Containers');

  await page.locator(s.viewMenuButton).click();
  await menuItem(page, 'Rename view…').click();
  await page.locator(s.ctxInput).fill('Boxes');
  await page.keyboard.press('Enter');

  await expect(page.locator(s.viewMenuButton)).toContainText('Boxes');
  expect(await vglText(page)).toContain('vview containers "Boxes"');
});

test('a deleted view takes the picker back to the default view', async ({ page }) => {
  await openEditor(page, doc);
  await createView(page, 'Containers');

  await page.locator(s.viewMenuButton).click();
  await menuItem(page, 'Delete view').click();
  await page.locator(s.menuItem, { hasText: 'Delete' }).first().click();

  await expect(page.locator(s.viewMenuButton)).toHaveText('Default view ▾');
});

test('the status line names the view being shown, and only then', async ({ page }) => {
  await openEditor(page, doc);
  await expect(page.locator(s.status)).not.toContainText('View:');

  await createView(page, 'Containers');
  await expect(page.locator(s.status)).toContainText('View: Containers');

  await pickView(page, 'Default view');
  await expect(page.locator(s.status)).not.toContainText('View:');
});

test('after a reload the view being shown comes back', async ({ page }) => {
  await openEditor(page, doc);
  await createView(page, 'Containers');
  await foldGroup(page);

  await openEditorAt(page, '');

  await expect(page.locator(s.viewMenuButton)).toContainText('Containers');
  await expect(folded(page)).toBeVisible();
});

test('a remembered view the document no longer has is dropped without a word', async ({ page }) => {
  await openEditor(page, doc);
  await page.evaluate(() => localStorage.setItem('vgraph.editor.draft-view', 'ghost'));

  await openEditorAt(page, '');

  await expect(page.locator(s.viewMenuButton)).toHaveText('Default view ▾');
  await expect(page.locator(s.status)).not.toContainText('View:');
});

test('the shown view is ticked in the view menu', async ({ page }) => {
  await openEditor(page, doc);
  await createView(page, 'Containers');

  await page.locator(s.viewMenuButton).click();

  await expect(menuItem(page, 'Containers').first()).toHaveText('✓ Containers');
  await expect(menuItem(page, 'Default view')).toHaveText('Default view');
  await expect(menuItem(page, 'Rename view…'), 'management sits in the same panel').toBeVisible();
});
