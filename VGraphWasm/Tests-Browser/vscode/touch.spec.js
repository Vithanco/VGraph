// Zoom under fingers, on a phone-sized WebKit page: the shared zoom.ts as the
// Obsidian plugin runs it on an iPhone. Playwright can only tap, and WebKit (as
// on iOS) will not construct a Touch, so a finger's touch events are plain
// events carrying the `touches` list the handler reads.

import { test, expect } from '@playwright/test';
import { wide, block, label, rect, openPreview } from './helpers.js';

// Dispatched where the gesture started, as a real touch event is; returns
// whether the page's own handling (scroll, zoom) was cancelled.
function touch(page, type, at, fingers) {
  return page.evaluate(({ type, at, fingers }) => {
    const target = document.elementFromPoint(at.x, at.y);
    const event = new Event(type, { bubbles: true, cancelable: true });
    const touches = fingers.map((f, i) => ({ identifier: i, target, clientX: f.x, clientY: f.y }));
    Object.defineProperty(event, 'touches', { value: touches });
    target.dispatchEvent(event);
    return event.defaultPrevented;
  }, { type, at, fingers });
}

// Two fingers on a horizontal line through `centre`, `from` then `to` apart.
async function pinch(page, centre, from, to) {
  const fingers = (gap) => [{ x: centre.x - gap / 2, y: centre.y }, { x: centre.x + gap / 2, y: centre.y }];
  await touch(page, 'touchstart', centre, fingers(from).slice(0, 1));
  await touch(page, 'touchstart', centre, fingers(from));
  const cancelled = [];
  for (let step = 1; step <= 4; step++) {
    cancelled.push(await touch(page, 'touchmove', centre, fingers(from + ((to - from) * step) / 4)));
  }
  await touch(page, 'touchend', centre, fingers(to).slice(0, 1));
  await touch(page, 'touchend', centre, []);
  return cancelled;
}

const centreOf = (r) => ({ x: r.left + r.width * 0.3, y: r.top + r.height / 2 });
const scaleOf = (r) => r.width / 1600;

test('spreading two fingers on a diagram zooms it in around them, and not the page', async ({ page }) => {
  await openPreview(page, [wide]);
  const before = await rect(page);
  const centre = centreOf(before);

  const cancelled = await pinch(page, centre, 60, 180);

  expect(cancelled).toEqual([true, true, true, true]);
  const after = await rect(page);
  expect(scaleOf(after)).toBeCloseTo(scaleOf(before) * 3, 2);
  await expect(label(page)).toHaveText(`${Math.round(scaleOf(after) * 100)}%`);
  const under = (r) => (centre.x - r.left) / r.width;
  expect(under(after)).toBeCloseTo(under(before), 2);
});

test('pinching two fingers together zooms out', async ({ page }) => {
  await openPreview(page, [wide]);
  const centre = centreOf(await rect(page));
  await pinch(page, centre, 60, 180);
  const spread = scaleOf(await rect(page));

  await pinch(page, centreOf(await rect(page)), 180, 90);

  expect(scaleOf(await rect(page))).toBeCloseTo(spread / 2, 2);
});

test('one finger on a diagram is left to scroll the page', async ({ page }) => {
  await openPreview(page, [wide]);
  const centre = centreOf(await rect(page));

  await touch(page, 'touchstart', centre, [centre]);
  const cancelled = await touch(page, 'touchmove', centre, [{ x: centre.x - 40, y: centre.y - 40 }]);
  await touch(page, 'touchend', centre, []);

  expect(cancelled).toBe(false);
  await expect(label(page)).toHaveText('Auto');
});

test('a tap on + zooms in', async ({ page }) => {
  await openPreview(page, [wide]);

  await block(page).locator('.vithanco-zoom-in').tap();

  await expect(label(page)).not.toHaveText('Auto');
});
