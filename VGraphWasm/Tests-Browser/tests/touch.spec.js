// The editor driven by a finger. See ADR-0018.
//
// Input is Pointer Events, so these gestures reach the same handlers the mouse
// specs exercise — what is new here is the half a mouse cannot produce: a
// `pointerType: "touch"` press, the press-and-hold that stands in for a
// right-click, and the `touch-action` split that decides whether a finger drags
// the graph or pans the pane.

import { test, expect } from '@playwright/test';
import {
  s, sel, connectable, boxedGraph, openEditor, vglText, centreOf,
  fingerTap, fingerDrag, fingerLongPress, finger,
} from '../helpers/editor.js';

const item = (page, text) => page.locator(s.menuItem).filter({ hasText: text });

const selectedIds = (page) =>
  page.evaluate(() => [...document.querySelectorAll('.vg-selected')].map((e) => e.id));

// Somewhere inside the preview that no graph element occupies. Bottom left, as
// known-defects.spec.js explains.
async function emptyPoint(page) {
  const box = await page.locator(s.preview).boundingBox();
  return { x: box.x + 4, y: box.y + box.height - 6 };
}

test('a tap selects the node under it', async ({ page }) => {
  await openEditor(page, connectable);
  await fingerTap(page, await centreOf(page, sel.node('idea')));

  expect(await selectedIds(page)).toEqual(['node-idea']);
});

test('a tap on blank canvas clears the selection', async ({ page }) => {
  await openEditor(page, connectable);
  await fingerTap(page, await centreOf(page, sel.node('idea')));
  await fingerTap(page, await emptyPoint(page));

  expect(await selectedIds(page)).toEqual([]);
});

test('a finger drag from node to node creates the edge', async ({ page }) => {
  await openEditor(page, connectable);
  await fingerDrag(
    page,
    await centreOf(page, sel.node('idea')),
    await centreOf(page, sel.node('link')),
  );

  expect(await vglText(page)).toContain('edge idea -> link');
});

test.describe('press and hold', () => {
  test('opens the node menu', async ({ page }) => {
    await openEditor(page, connectable);
    await fingerLongPress(page, await centreOf(page, sel.node('idea')));

    await expect(page.locator(s.menu)).toBeVisible();
    await expect(item(page, 'Rename')).toBeVisible();
  });

  test('opens the canvas menu on blank space', async ({ page }) => {
    await openEditor(page, connectable);
    await fingerLongPress(page, await emptyPoint(page));

    await expect(page.locator(s.menu)).toBeVisible();
    await expect(item(page, 'Add node…')).toBeVisible();
  });

  // The 4px tolerance decides here exactly as it decides a drag from a click, so
  // "moved" keeps meaning one thing in this editor (ADR-0012).
  test('a press that travels is a drag, not a menu', async ({ page }) => {
    await openEditor(page, connectable);
    await fingerDrag(
      page,
      await centreOf(page, sel.node('idea')),
      await centreOf(page, sel.node('link')),
    );

    await expect(page.locator(s.menu)).toHaveCount(0);
  });

  // Regression guard for the flag in `handleDragEnd`: without it the finger
  // lifting runs `clickSelect` over the open menu and collapses the very
  // selection the menu was built from.
  test('the release does not collapse the selection behind the menu', async ({ page }) => {
    await openEditor(page, boxedGraph);
    // Built with the mouse — a finger has no ⇧ — which is also the real iPad
    // case of a trackpad plus a touchscreen.
    await page.locator(sel.node('one')).click();
    await page.locator(sel.node('two')).click({ modifiers: ['Shift'] });
    expect(await selectedIds(page)).toEqual(['group-box']);

    await fingerLongPress(page, await centreOf(page, sel.node('one')));

    await expect(page.locator(s.menu)).toBeVisible();
    expect(await selectedIds(page)).toEqual(['group-box']);
  });

  // A pointer the browser takes away — a touch promoted to a scroll — must not
  // leave a menu arriving half a second later over whatever is on screen then.
  test('a cancelled pointer arms nothing', async ({ page }) => {
    await openEditor(page, connectable);
    const idea = await centreOf(page, sel.node('idea'));
    await finger(page, 'pointerdown', idea.x, idea.y);
    await finger(page, 'pointercancel', idea.x, idea.y);
    await page.waitForTimeout(700);

    await expect(page.locator(s.menu)).toHaveCount(0);
  });
});

// `preventDefault()` on pointerdown does not stop a finger scrolling — only
// `touch-action` does — so this split *is* the behaviour, and asserting the
// computed value is the honest test. A synthetic pointer event cannot make the
// browser scroll, so there is nothing else here to observe.
test.describe('touch-action', () => {
  const touchAction = (page, selector) =>
    page.evaluate((q) => getComputedStyle(document.querySelector(q)).touchAction, selector);

  test('the preview pans, so a big diagram can be reached', async ({ page }) => {
    await openEditor(page, connectable);
    expect(await touchAction(page, s.preview)).toBe('pan-x pan-y');
  });

  test('a node does not, so a press on one drags it', async ({ page }) => {
    await openEditor(page, connectable);
    expect(await touchAction(page, sel.node('idea'))).toBe('none');
  });

  test('a group label does not either', async ({ page }) => {
    await openEditor(page, boxedGraph);
    expect(await touchAction(page, s.groupLabel)).toBe('none');
  });

  test('the splitter does not, so a finger on it resizes rather than scrolls', async ({ page }) => {
    await openEditor(page, connectable);
    expect(await touchAction(page, s.splitter)).toBe('none');
  });
});

// Pinch is not available (the preview is pan-only, above), so the buttons are
// the way to zoom with a finger.
test.describe('zoom', () => {
  test('the Display panel works under a finger', async ({ page }) => {
    await openEditor(page, connectable);

    await page.locator(s.displayButton).tap();
    await page.locator(`${s.displayPanel} button`, { hasText: '100%' }).tap();
    await page.locator(`${s.displayPanel} button`, { hasText: '+' }).tap();

    await expect(page.locator(s.displayButton)).toHaveText('125% ▾');
  });

  test('the toolbar fits on one row', async ({ page }) => {
    await openEditor(page, connectable);

    const height = (await page.locator(s.toolbar).boundingBox()).height;
    expect(height, 'one row of buttons, not two').toBeLessThan(60);
  });
});
