// The toolbar: one row, a Display panel, and a way to a bigger editor in an iframe.

import { test, expect } from '@playwright/test';
import { s, openEditor, oneConcept, closeDisplayPanel, vglText } from '../helpers/editor.js';

test.use({ viewport: { width: 1200, height: 700 } });

test('the bar is titled for the product, not the library', async ({ page }) => {
  await openEditor(page, oneConcept);

  await expect(page.locator('.vg-toolbar-title')).toHaveText('Vithanco');
});

test('the bar is one row wide', async ({ page }) => {
  await openEditor(page, oneConcept);

  expect((await page.locator(s.toolbar).boundingBox()).height).toBeLessThan(60);
});

test('the Display panel stays open across zoom steps and closes on an outside press', async ({ page }) => {
  await openEditor(page, oneConcept);
  await page.locator(s.displayButton).click();
  const panel = page.locator(s.displayPanel);

  await panel.locator('button', { hasText: '100%' }).click();
  await panel.locator('button', { hasText: '+' }).click();
  await panel.locator('button', { hasText: '+' }).click();

  await expect(panel).toBeVisible();
  await expect(page.locator(s.displayButton)).toHaveText('150% ▾');

  await closeDisplayPanel(page);
  await expect(panel).toHaveCount(0);
});

test('the Display panel stays inside the window though its button is at the right edge', async ({ page }) => {
  await openEditor(page, oneConcept);

  await page.locator(s.displayButton).click();

  const box = await page.locator(s.displayPanel).boundingBox();
  expect(box.x).toBeGreaterThanOrEqual(0);
  expect(box.x + box.width).toBeLessThanOrEqual(1200);
});

test('the theme row says which theme it switches to', async ({ page }) => {
  await openEditor(page, oneConcept);

  await page.locator(s.displayButton).click();
  await page.locator(`${s.displayPanel} .vg-ctx-item`, { hasText: 'Dark theme' }).click();
  await page.locator(s.displayButton).click();

  await expect(page.locator(`${s.displayPanel} .vg-ctx-item`)).toHaveText('☀ Light theme');
});

test.describe('in an iframe', () => {
  async function embed(page, vgl) {
    await page.route('**/host.html', (route) =>
      route.fulfill({
        contentType: 'text/html',
        body: `<iframe src="/index.html?vgl=${encodeURIComponent(vgl)}" width="900" height="500"></iframe>`,
      }));
    await page.goto('/host.html');
    const frame = page.frameLocator('iframe');
    await expect(frame.locator(s.svg)).toBeVisible({ timeout: 30_000 });
    return { frame, inner: page.frames()[1] };
  }

  // Fullscreen's default permission policy is `self`, so the site's own iframes
  // need no `allow` attribute.
  test('the full-window button takes the editor fullscreen, and takes it back', async ({ page }) => {
    const { frame, inner } = await embed(page, oneConcept);
    const isFullscreen = () => inner.evaluate(() => document.fullscreenElement !== null);

    await frame.locator(s.enlarge).click();
    await expect.poll(isFullscreen).toBe(true);

    await frame.locator(s.enlarge).click();
    await expect.poll(isFullscreen).toBe(false);
  });

  test('where fullscreen is not allowed, it opens the editor on its own page with the document', async ({ page, context }) => {
    // What a cross-origin host that withholds `allow="fullscreen"` looks like.
    await page.addInitScript(() => {
      Object.defineProperty(Document.prototype, 'fullscreenEnabled', { get: () => false });
    });
    const { frame } = await embed(page, oneConcept);

    const [popup] = await Promise.all([
      context.waitForEvent('page'),
      frame.locator(s.enlarge).click(),
    ]);

    await expect(popup).toHaveURL(/index\.html#vgl=/);
    await expect(popup.locator(s.textarea)).toHaveValue(oneConcept, { timeout: 30_000 });
  });
});
