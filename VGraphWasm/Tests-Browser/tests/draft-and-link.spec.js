// Two ways of not losing a diagram: the browser remembers the last one for you,
// and "Copy link" packs it into a URL you can send to someone.
//
// Both are per-browser state, so each test drives one page through a reload
// rather than asserting on a fresh one.

import { test, expect } from '@playwright/test';
import { s, sel, oneConcept, groupedGraph, openEditor, openEditorAt } from '../helpers/editor.js';

const edited = oneConcept.replace('"Idea"', '"Remembered"');

test('a diagram survives closing the page', async ({ page }) => {
  await openEditor(page, oneConcept);
  await page.locator(s.textarea).fill(edited);
  await expect(page.locator(sel.node('idea'))).toHaveText(/Remembered/);

  // No parameters: nothing asked for a document, so the last one comes back.
  await openEditorAt(page, '');

  await expect(page.locator(s.textarea)).toHaveValue(edited);
  await expect(page.locator(s.status)).toContainText('Restored');
});

test('a document in the URL beats the remembered one', async ({ page }) => {
  await openEditor(page, edited);
  await openEditor(page, groupedGraph);

  await expect(page.locator(sel.group('g1')), 'the link, not the draft').toBeVisible();
  await expect(page.locator(s.status)).not.toContainText('Restored');
});

test('a ?src= document beats the remembered one, even while it is still loading', async ({
  page,
}) => {
  await openEditor(page, edited);

  await openEditorAt(page, '?src=/test-fixtures/grouped.vgl');

  await expect(page.locator(sel.group('g1'))).toBeVisible();
  await expect(page.locator(s.textarea)).not.toHaveValue(edited);
});

test('a half-typed diagram is remembered too', async ({ page }) => {
  await openEditor(page, oneConcept);
  // Parses to nothing usable — and is exactly the state worth not losing.
  await page.locator(s.textarea).fill('vgraph broken: ConceptMap "Half" {');
  await expect(page.locator(s.status)).toContainText('Render failed');

  // Not `openEditorAt`: it waits for a rendered diagram, and a document that
  // does not parse has none — on a fresh page there is no previous one to keep
  // either, so the canvas stays empty. The text is what had to survive.
  await page.goto('/index.html');
  await expect(page.locator(s.textarea)).toHaveValue('vgraph broken: ConceptMap "Half" {', {
    timeout: 30_000,
  });
  await expect(page.locator(s.diagnostics), 'and it says why').toContainText(/./);
});

test('#vgl= seeds the editor from the fragment', async ({ page }) => {
  await openEditorAt(page, `#vgl=${encodeURIComponent(groupedGraph)}`);

  await expect(page.locator(s.textarea)).toHaveValue(groupedGraph);
  await expect(page.locator(sel.group('g1'))).toBeVisible();
});

test('Copy link mints a link that carries the whole diagram', async ({ page, context }) => {
  await context.grantPermissions(['clipboard-read', 'clipboard-write']);
  await openEditor(page, groupedGraph);

  await page.locator(s.fileMenuButton).click();
  await page.locator(s.fileMenuItem, { hasText: 'Copy link' }).click();
  await expect(page.locator(s.status)).toContainText('Link copied');

  const link = await page.evaluate(() => navigator.clipboard.readText());
  // The fragment, not the query: it never reaches the server, so it is not
  // capped by the request line and does not land in anyone's logs.
  expect(link).toContain('#vgl=');
  expect(new URL(link).search, 'nothing of the diagram is in the query').toBe('');

  await page.goto(link);
  await expect(page.locator(s.svg)).toBeVisible({ timeout: 30_000 });
  await expect(page.locator(s.textarea)).toHaveValue(groupedGraph);
});
