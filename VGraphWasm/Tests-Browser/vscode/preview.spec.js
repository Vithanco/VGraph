// Zoom in VS Code's Markdown preview, which no test can open (see helpers.js).
// Updates arrive the way the preview sends them: a `vscode.markdown.updateContent`
// event after either a fresh document or the same nodes patched back to the new
// markup (morphdom).

import { test, expect } from '@playwright/test';
import { svgHtml, placeholderHtml, diagram, wide, block, label, press, rect, overflow, openPreview } from './helpers.js';

async function rerender(page, blocks, { inPlace }) {
  await page.evaluate(({ html, inPlace }) => {
    const root = document.querySelector('.markdown-body');
    const fresh = new DOMParser().parseFromString(`<div class="markdown-body">${html}</div>`, 'text/html').body.firstElementChild;
    if (inPlace) {
      // What morphdom leaves of an element whose content did not change: the
      // same node, with the new markup's attributes and text.
      const sync = (from, to) => {
        for (const a of [...from.attributes]) if (!to.hasAttribute(a.name)) from.removeAttribute(a.name);
        for (const a of [...to.attributes]) from.setAttribute(a.name, a.value);
        if (from.children.length === 0) from.textContent = to.textContent;
        [...from.children].forEach((child, i) => sync(child, to.children[i]));
      };
      sync(root, fresh);
    } else {
      root.replaceWith(fresh);
    }
    window.dispatchEvent(new CustomEvent('vscode.markdown.updateContent'));
  }, { html: blocks.join(''), inPlace });
}

test('a diagram wider than the preview starts fitted to it, with no sideways scroll', async ({ page }) => {
  await openPreview(page, [wide]);

  await expect(label(page)).toHaveText('Auto');
  const box = await block(page).boundingBox();
  expect((await rect(page)).width).toBeLessThanOrEqual(box.width);
  expect(await overflow(page)).toBeLessThanOrEqual(0);
});

test('+ steps up from the fitted scale, and a diagram wider than the preview scrolls sideways', async ({ page }) => {
  await openPreview(page, [wide]);
  expect((await rect(page)).width / 1600).toBeLessThan(0.5);

  await press(page, 'in');
  await expect(label(page)).toHaveText('50%');
  expect((await rect(page)).width).toBeCloseTo(800, 0);

  await press(page, 'in');
  await expect(label(page)).toHaveText('67%');
  expect((await rect(page)).width).toBeCloseTo(1072, 0);
  expect(await overflow(page)).toBeGreaterThan(0);
});

test('− steps down, and the label returns the diagram to fit', async ({ page }) => {
  await openPreview(page, [wide]);
  const fitted = (await rect(page)).width;

  await press(page, 'in');
  await press(page, 'in');
  await press(page, 'out');
  await expect(label(page)).toHaveText('50%');

  await press(page, 'reset');
  await expect(label(page)).toHaveText('Auto');
  expect((await rect(page)).width).toBeCloseTo(fitted, 0);
});

test('a pinch (ctrl+wheel) zooms around the pointer and stops the page zooming', async ({ page }) => {
  await openPreview(page, [wide]);
  await press(page, 'in');
  await press(page, 'in');
  const before = await rect(page);
  const pointer = { x: before.left + 500, y: before.top + 100 };

  const prevented = await block(page).locator('.vithanco-zoom-viewport').evaluate((el, { x, y }) => {
    const event = new WheelEvent('wheel', { deltaY: -40, ctrlKey: true, clientX: x, clientY: y, bubbles: true, cancelable: true });
    el.dispatchEvent(event);
    return event.defaultPrevented;
  }, pointer);

  expect(prevented).toBe(true);
  const after = await rect(page);
  expect(after.width).toBeGreaterThan(before.width);
  await expect(label(page)).not.toHaveText('67%');
  const under = (r) => (pointer.x - r.left) / r.width;
  expect(under(after)).toBeCloseTo(under(before), 2);
});

test('a plain wheel scrolls the preview and leaves the zoom alone', async ({ page }) => {
  await openPreview(page, [wide]);

  const prevented = await block(page).locator('.vithanco-zoom-viewport').evaluate((el) => {
    const event = new WheelEvent('wheel', { deltaY: 40, bubbles: true, cancelable: true });
    el.dispatchEvent(event);
    return event.defaultPrevented;
  });

  expect(prevented).toBe(false);
  await expect(label(page)).toHaveText('Auto');
});

for (const inPlace of [false, true]) {
  test(`each diagram keeps its zoom when the preview updates ${inPlace ? 'its nodes in place' : 'to a fresh document'}`, async ({ page }) => {
    const blocks = [wide, svgHtml(diagram(1200, 300))];
    await openPreview(page, blocks);
    await press(page, 'in', 1);
    await press(page, 'in', 1);
    await expect(label(page, 1)).toHaveText('75%');

    await rerender(page, blocks, { inPlace });
    await rerender(page, blocks, { inPlace });

    await expect(label(page, 0)).toHaveText('Auto');
    await expect(label(page, 1)).toHaveText('75%');
    expect((await rect(page, 1)).width).toBeCloseTo(900, 0);

    // Bound once, however many updates: one press is one step.
    await press(page, 'in', 1);
    await expect(label(page, 1)).toHaveText('90%');
  });
}

// VS Code's own double-click handler (markdown.preview.doubleClickToSwitchToEditor)
// sits on the document; this stands in for it.
test('two quick presses on + zoom twice and do not leave the preview', async ({ page }) => {
  await openPreview(page, [wide]);
  await page.evaluate(() => {
    window.leftPreview = false;
    document.addEventListener('dblclick', () => { window.leftPreview = true; });
  });

  await block(page).locator('.vithanco-zoom-in').dblclick();

  await expect(label(page)).toHaveText('67%');
  expect(await page.evaluate(() => window.leftPreview)).toBe(false);
});

test('a block still rendering offers no zoom', async ({ page }) => {
  await openPreview(page, [placeholderHtml('vgraph x: IBIS "x" {}'), wide]);

  await expect(page.locator('.vgraph-loading .vithanco-zoom-bar')).toHaveCount(0);
  await expect(label(page, 0)).toHaveText('Auto');
});
