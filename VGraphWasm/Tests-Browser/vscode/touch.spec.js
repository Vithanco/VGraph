// Zoom under fingers: the shared zoom.ts on a phone-sized WebKit page, the engine
// the Obsidian plugin runs in on iOS. Playwright can only tap, and WebKit (as on
// iOS) will not construct a Touch, so a finger's touch events are plain events
// carrying the `touches` list the handler reads.

import { test, expect } from '@playwright/test';
import { wide, wideScale, longText, block, zoomLabel, press, rect, expectSameSpotUnder, openPreview } from './helpers.js';

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

// Off the middle both ways, where zooming around the fingers and around the
// diagram's middle or top part ways.
const offMiddle = (r) => ({ x: r.left + r.width * 0.3, y: r.top + r.height * 0.6 });

test('spreading two fingers on a diagram zooms it in around them, and not the page', async ({ page }) => {
  await openPreview(page, [wide, longText]);
  const before = await rect(page);
  const fingers = offMiddle(before);

  const cancelled = await pinch(page, fingers, 60, 180);

  expect(cancelled).toEqual([true, true, true, true]);
  const after = await rect(page);
  expect(wideScale(after)).toBeCloseTo(wideScale(before) * 3, 2);
  await expect(zoomLabel(page)).toHaveText(`${Math.round(wideScale(after) * 100)}%`);
  expectSameSpotUnder(fingers, before, after);
});

test('pinching two fingers together zooms out', async ({ page }) => {
  await openPreview(page, [wide]);
  await pinch(page, offMiddle(await rect(page)), 60, 180);
  const spread = wideScale(await rect(page));

  await pinch(page, offMiddle(await rect(page)), 180, 90);

  expect(wideScale(await rect(page))).toBeCloseTo(spread / 2, 2);
});

for (const zoomedIn of [false, true]) {
  test(`one finger on a ${zoomedIn ? 'zoomed-in' : 'fitted'} diagram is left to scroll`, async ({ page }) => {
    await openPreview(page, [wide]);
    if (zoomedIn) await press(page, 'in');
    const shown = await zoomLabel(page).textContent();
    const finger = offMiddle(await rect(page));

    await touch(page, 'touchstart', finger, [finger]);
    const cancelled = await touch(page, 'touchmove', finger, [{ x: finger.x - 40, y: finger.y - 40 }]);
    await touch(page, 'touchend', finger, []);

    expect(cancelled).toBe(false);
    await expect(zoomLabel(page)).toHaveText(shown);
  });
}

test('a tap on + zooms in', async ({ page }) => {
  await openPreview(page, [wide]);

  await block(page).locator('.vithanco-zoom-in').tap();

  await expect(zoomLabel(page)).not.toHaveText('Auto');
});
