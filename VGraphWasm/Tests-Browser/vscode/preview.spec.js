// Zoom in VS Code's Markdown preview, through the stand-in in helpers.js.

import { test, expect } from '@playwright/test';
import {
  rendered, rendering, wide, wideScale, longText, block, zoomLabel, press, rect, overflow,
  expectSameSpotUnder, openPreview,
} from './helpers.js';

// The preview's updates (VS Code's media/index.js). After an edit, morphdom
// patches the nodes it has to the new markup by position, without keys: a node
// that already matches is left alone, one of the same tag is patched in place,
// whatever is left over is added or removed. Another note replaces the document.
async function update(page, blocks, { anotherNote = false } = {}) {
  await page.evaluate(({ html, anotherNote }) => {
    const root = document.querySelector('.markdown-body');
    const fresh = new DOMParser().parseFromString(`<div class="markdown-body">${html}</div>`, 'text/html').body.firstElementChild;
    const morph = (from, to) => {
      if (from.isEqualNode(to)) return;
      if (from.nodeName !== to.nodeName) return from.replaceWith(to.cloneNode(true));
      if (from.nodeType !== Node.ELEMENT_NODE) return void (from.nodeValue = to.nodeValue);
      for (const a of [...from.attributes]) if (!to.hasAttribute(a.name)) from.removeAttribute(a.name);
      for (const a of [...to.attributes]) from.setAttribute(a.name, a.value);
      morphChildren(from, to);
    };
    const morphChildren = (from, to) => {
      [...to.childNodes].forEach((child, i) => {
        if (from.childNodes[i]) morph(from.childNodes[i], child);
        else from.appendChild(child.cloneNode(true));
      });
      while (from.childNodes.length > to.childNodes.length) from.lastChild.remove();
    };
    if (anotherNote) root.replaceWith(fresh);
    else morphChildren(root, fresh);
    window.dispatchEvent(new CustomEvent('vscode.markdown.updateContent'));
  }, { html: blocks.join(''), anotherNote });
}

// Returns whether the page's own handling (scroll, zoom) was cancelled.
function wheel(page, init) {
  return block(page).locator('.vithanco-zoom-viewport').evaluate((el, init) => {
    const event = new WheelEvent('wheel', { ...init, bubbles: true, cancelable: true });
    el.dispatchEvent(event);
    return event.defaultPrevented;
  }, init);
}

test('a diagram wider than the preview starts fitted to it, with no sideways scroll', async ({ page }) => {
  await openPreview(page, [wide]);

  await expect(zoomLabel(page)).toHaveText('Auto');
  const box = await block(page).boundingBox();
  expect((await rect(page)).width).toBeLessThanOrEqual(box.width);
  expect(await overflow(page)).toBeLessThanOrEqual(0);
});

test('+ steps up from the fitted scale, and a diagram wider than the preview scrolls sideways', async ({ page }) => {
  await openPreview(page, [wide]);
  expect(wideScale(await rect(page))).toBeLessThan(0.5);

  await press(page, 'in');
  await expect(zoomLabel(page)).toHaveText('50%');
  expect((await rect(page)).width).toBeCloseTo(800, 0);

  await press(page, 'in');
  await expect(zoomLabel(page)).toHaveText('67%');
  expect((await rect(page)).width).toBeCloseTo(1072, 0);
  const viewport = block(page).locator('.vithanco-zoom-viewport');
  const scrolled = () => viewport.evaluate((e) => e.scrollLeft);
  const before = await scrolled();
  await viewport.hover();
  await page.mouse.wheel(200, 0);
  await expect.poll(scrolled).toBeGreaterThan(before);
});

test('− steps down, and the label returns the diagram to fit', async ({ page }) => {
  await openPreview(page, [wide]);
  const fitted = (await rect(page)).width;

  await press(page, 'in');
  await press(page, 'in');
  await press(page, 'out');
  await expect(zoomLabel(page)).toHaveText('50%');

  await press(page, 'reset');
  await expect(zoomLabel(page)).toHaveText('Auto');
  expect((await rect(page)).width).toBeCloseTo(fitted, 0);
});

test('a pinch (ctrl+wheel) zooms around the pointer and stops the page zooming', async ({ page }) => {
  await openPreview(page, [wide, longText]);
  await press(page, 'in');
  await press(page, 'in');
  const before = await rect(page);
  const pointer = { x: before.left + 500, y: before.top + 100 };

  const prevented = await wheel(page, { deltaY: -40, ctrlKey: true, clientX: pointer.x, clientY: pointer.y });

  expect(prevented).toBe(true);
  const after = await rect(page);
  expect(after.width).toBeGreaterThan(before.width);
  await expect(zoomLabel(page)).not.toHaveText('67%');
  expectSameSpotUnder(pointer, before, after);
});

test('a plain wheel scrolls the preview and leaves the zoom alone', async ({ page }) => {
  await openPreview(page, [wide]);

  const prevented = await wheel(page, { deltaY: 40 });

  expect(prevented).toBe(false);
  await expect(zoomLabel(page)).toHaveText('Auto');
});

test('each diagram keeps its zoom when an edit updates the preview', async ({ page }) => {
  const blocks = [wide, rendered('second', 1200, 300)];
  await openPreview(page, blocks);
  await press(page, 'in', 1);
  await press(page, 'in', 1);
  await expect(zoomLabel(page, 1)).toHaveText('75%');

  await update(page, blocks);
  await update(page, blocks);

  await expect(zoomLabel(page, 0)).toHaveText('Auto');
  await expect(zoomLabel(page, 1)).toHaveText('75%');
  expect((await rect(page, 1)).width).toBeCloseTo(900, 0);

  // Bound once, however many updates: one press is one step.
  await press(page, 'in', 1);
  await expect(zoomLabel(page, 1)).toHaveText('90%');
});

test('a diagram keeps its zoom when another is added above it', async ({ page }) => {
  const second = rendered('second', 1200, 300);
  await openPreview(page, [wide, second]);
  await press(page, 'in', 1);
  await press(page, 'in', 1);
  await expect(zoomLabel(page, 1)).toHaveText('75%');

  await update(page, [rendered('added', 800, 200), wide, second]);

  await expect(zoomLabel(page, 0)).toHaveText('Auto');
  await expect(zoomLabel(page, 1)).toHaveText('Auto');
  await expect(zoomLabel(page, 2)).toHaveText('75%');
});

test('a diagram keeps its zoom while an edit to it renders again', async ({ page }) => {
  await openPreview(page, [wide]);
  await press(page, 'in');
  await expect(zoomLabel(page)).toHaveText('50%');

  await update(page, [rendering('wide')]);
  await update(page, [rendered('wide', 1600, 500)]);

  await expect(zoomLabel(page)).toHaveText('50%');
});

test('two diagrams with the same graph id keep a zoom each', async ({ page }) => {
  const blocks = [rendered('same', 1600, 400), rendered('same', 1200, 300)];
  await openPreview(page, blocks);
  await press(page, 'in', 1);
  await press(page, 'in', 1);

  await update(page, blocks);

  await expect(zoomLabel(page, 0)).toHaveText('Auto');
  await expect(zoomLabel(page, 1)).toHaveText('75%');
});

test("another note's diagrams start fitted, whatever their graph ids", async ({ page }) => {
  await openPreview(page, [wide]);
  await press(page, 'in');
  await expect(zoomLabel(page)).toHaveText('50%');

  await update(page, [wide], { anotherNote: true });

  await expect(zoomLabel(page)).toHaveText('Auto');
});

// VS Code's own double-click handler (markdown.preview.doubleClickToSwitchToEditor)
// sits on the document; this stands in for it.
test('two quick presses on + zoom twice and do not leave the preview', async ({ page }) => {
  await openPreview(page, [wide]);
  await page.evaluate(() => {
    window.leftPreview = false;
    document.addEventListener('dblclick', () => { window.leftPreview = true; });
  });

  await block(page).locator('.vithanco-zoom-in').dblclick();

  await expect(zoomLabel(page)).toHaveText('67%');
  expect(await page.evaluate(() => window.leftPreview)).toBe(false);
});

test('a block still rendering offers no zoom', async ({ page }) => {
  await openPreview(page, [rendering('x'), wide]);

  await expect(page.locator('.vgraph-loading .vithanco-zoom-bar')).toHaveCount(0);
  await expect(zoomLabel(page, 0)).toHaveText('Auto');
});
