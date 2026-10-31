// Drag one node onto another to create the edge between them (ADR-0012).
//
// This is the gesture the ADR says browser tests carry more of the risk for than
// usual: the threshold, the hit test, the cancel paths and the modifier timing
// are only observable in a real browser.

import { test, expect } from '@playwright/test';
import {
  s, sel, connectable, twoStocks, openEditor, vglText, canUndo, renderNow, rectOf,
} from '../helpers/editor.js';

// The wrapping <g>'s box, which covers the shape and its label — the same box a
// user aims at.
async function centreOf(page, selector) {
  const r = await rectOf(page, selector);
  return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
}

// Press on `fromId` and move over `toId` without releasing. Several steps, not
// one jump: the first must clear the 4px threshold and the rest are what a real
// drag looks like.
async function dragOver(page, fromId, toId) {
  const from = await centreOf(page, sel.node(fromId));
  const to = await centreOf(page, sel.node(toId));
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  await page.mouse.move(from.x + 12, from.y + 12);
  await page.mouse.move(to.x, to.y, { steps: 4 });
  return { from, to };
}

async function dragOnto(page, fromId, toId) {
  await dragOver(page, fromId, toId);
  await page.mouse.up();
}

// Somewhere inside the preview that no graph element occupies. Bottom left, as
// known-defects.spec.js explains.
async function emptyPoint(page) {
  const box = await page.locator(s.preview).boundingBox();
  return { x: box.x + 4, y: box.y + box.height - 6 };
}

test.describe('the drop', () => {
  test('a legal drop creates the edge', async ({ page }) => {
    await openEditor(page, connectable);
    await dragOnto(page, 'idea', 'link');

    await expect(page.locator(s.textarea)).toHaveValue(/edge idea -> link/);
    expect(await canUndo(page)).toBe(true);
    await expect(page.locator(s.svg)).toContainText('Idea');
  });

  // The direction is the direction dragged: Relation → Concept is a declared
  // type, so this must produce that one and not flip back.
  test('the edge runs the way it was dragged', async ({ page }) => {
    await openEditor(page, connectable);
    await dragOnto(page, 'link', 'idea');

    const vgl = await vglText(page);
    expect(vgl).toContain('edge link -> idea');
    expect(vgl).not.toContain('edge idea -> link');
  });

  test('a drop the notation forbids changes nothing', async ({ page }) => {
    await openEditor(page, connectable);
    const before = await vglText(page);

    await dragOnto(page, 'idea', 'other');

    expect(await vglText(page)).toBe(before);
    expect(await canUndo(page)).toBe(false);
  });

  test('dropping back on the node grabbed does nothing', async ({ page }) => {
    await openEditor(page, twoStocks);
    const before = await vglText(page);

    // CLD declares Stock → Stock, so only the self-loop rule stops this.
    await dragOnto(page, 'price', 'price');

    expect(await vglText(page)).toBe(before);
  });

  test('a drop lands in history as one step', async ({ page }) => {
    await openEditor(page, connectable);
    await dragOnto(page, 'idea', 'link');
    await expect(page.locator(s.textarea)).toHaveValue(/edge idea -> link/);

    await page.locator(s.textarea).press('ControlOrMeta+z');
    await expect(page.locator(s.textarea)).not.toHaveValue(/edge idea -> link/);

    await page.locator(s.textarea).press('ControlOrMeta+Shift+z');
    await expect(page.locator(s.textarea)).toHaveValue(/edge idea -> link/);
  });
});

test.describe('the ghost line', () => {
  test('is green over a node the drop would connect', async ({ page }) => {
    await openEditor(page, connectable);
    await dragOver(page, 'idea', 'link');

    await expect(page.locator(s.dragLegal)).toHaveCount(1);
    await expect(page.locator(s.dragIllegal)).toHaveCount(0);

    await page.mouse.up();
  });

  test('is red over a node the drop would not', async ({ page }) => {
    await openEditor(page, connectable);
    await dragOver(page, 'idea', 'other');

    await expect(page.locator(s.dragIllegal)).toHaveCount(1);
    await expect(page.locator(s.dragLegal)).toHaveCount(0);

    await page.mouse.up();
  });

  // Anchored on the node, not on the press: grab well off-centre and the line
  // still leaves from the middle, so it keeps meaning something once the cursor
  // is gone. Also pins the overlay's coordinate space to client coordinates.
  test('leaves from the grabbed node centre, wherever it was pressed', async ({ page }) => {
    await openEditor(page, connectable);
    const node = await rectOf(page, sel.node('idea'));
    const press = { x: node.left + 3, y: node.top + 3 };
    const to = await centreOf(page, sel.node('link'));

    await page.mouse.move(press.x, press.y);
    await page.mouse.down();
    await page.mouse.move(press.x + 12, press.y + 12);
    await page.mouse.move(to.x, to.y, { steps: 4 });

    const line = await page.locator(s.dragLine).evaluate((el) => ({
      x1: +el.getAttribute('x1'), y1: +el.getAttribute('y1'),
    }));
    expect(Math.abs(line.x1 - (node.left + node.width / 2))).toBeLessThan(2);
    expect(Math.abs(line.y1 - (node.top + node.height / 2))).toBeLessThan(2);
    expect(Math.abs(line.x1 - press.x)).toBeGreaterThan(4);

    await page.mouse.up();
  });

  // `pointer-events:none` on the overlay. Without it the line, which by now spans
  // the viewport, would answer every hit test and no drop could ever be found.
  test('does not intercept the hit test it is drawn over', async ({ page }) => {
    await openEditor(page, connectable);
    const { to } = await dragOver(page, 'idea', 'link');

    const hit = await page.evaluate(
      ({ x, y }) => {
        const el = document.elementFromPoint(x, y);
        return { inOverlay: !!el.closest('#vg-drag-overlay'), inNode: !!el.closest('#node-link') };
      },
      { x: to.x, y: to.y },
    );
    expect(hit.inOverlay).toBe(false);
    expect(hit.inNode).toBe(true);

    await page.mouse.up();
  });

  // `mouseleave`, not `mouseout` — the latter bubbles on every hop between the
  // SVG's own shapes, so a drag across the diagram would cancel itself.
  test('crossing other elements mid-drag does not cancel', async ({ page }) => {
    await openEditor(page, connectable);
    await dragOver(page, 'idea', 'other');
    await expect(page.locator(s.dragLine)).toHaveCount(1);

    const link = await centreOf(page, sel.node('link'));
    await page.mouse.move(link.x, link.y, { steps: 6 });

    await expect(page.locator(s.dragLegal)).toHaveCount(1);
    await page.mouse.up();
    expect(await vglText(page)).toContain('edge idea -> link');
  });

  // Nothing is computed or painted until the pointer is over something, and the
  // 4px threshold is jitter tolerance rather than a rule about what a drag is.
  test('does not appear until the pointer has actually moved', async ({ page }) => {
    await openEditor(page, connectable);
    const from = await centreOf(page, sel.node('idea'));
    await page.mouse.move(from.x, from.y);
    await page.mouse.down();
    await page.mouse.move(from.x + 1, from.y + 1);

    await expect(page.locator(s.dragLine)).toHaveCount(0);

    await page.mouse.up();
  });

  // Was "leaves the line red rather than ending the drag". Empty canvas is the
  // [[Root group]], and since ADR-0019 a release there *moves* — so red would
  // now say "illegal" about a legal drop. The drag still does not end; the
  // feedback changes hands, and the canvas washes only when the move would do
  // something. `idea` is already at the top level here, so it would not.
  test('leaving the diagram hands the feedback over without ending the drag', async ({ page }) => {
    await openEditor(page, connectable);
    const { from } = await dragOver(page, 'idea', 'link');
    await expect(page.locator(s.dragLegal)).toHaveCount(1);

    const empty = await emptyPoint(page);
    await page.mouse.move(empty.x, empty.y, { steps: 3 });

    await expect(page.locator(s.dragLine), 'the line gives way').toHaveCount(0);
    expect(from).toBeTruthy();

    // Still armed: coming back over a node restores the line.
    const to = await centreOf(page, sel.node('link'));
    await page.mouse.move(to.x, to.y, { steps: 3 });
    await expect(page.locator(s.dragLegal)).toHaveCount(1);

    await page.mouse.up();
  });
});

test.describe('cancelling', () => {
  test('a drop on empty canvas cancels', async ({ page }) => {
    await openEditor(page, connectable);
    const before = await vglText(page);
    await dragOver(page, 'idea', 'link');
    const empty = await emptyPoint(page);
    await page.mouse.move(empty.x, empty.y, { steps: 3 });
    await page.mouse.up();

    await expect(page.locator(s.dragLine)).toHaveCount(0);
    expect(await vglText(page)).toBe(before);
  });

  test('Escape cancels mid-drag', async ({ page }) => {
    await openEditor(page, connectable);
    const before = await vglText(page);
    await dragOver(page, 'idea', 'link');
    await expect(page.locator(s.dragLine)).toHaveCount(1);

    await page.keyboard.press('Escape');
    await expect(page.locator(s.dragLine)).toHaveCount(0);

    // The release that follows a cancel is not a drop.
    await page.mouse.up();
    expect(await vglText(page)).toBe(before);
  });

  // The realistic trigger is the debounced live preview landing mid-drag: the
  // grabbed element is about to be replaced, so the drag cannot outlive it.
  test('a render cancels the drag', async ({ page }) => {
    await openEditor(page, connectable);
    const before = await vglText(page);
    await dragOver(page, 'idea', 'link');
    await expect(page.locator(s.dragLine)).toHaveCount(1);

    await renderNow(page);
    await expect(page.locator(s.dragLine)).toHaveCount(0);

    await page.mouse.up();
    expect(await vglText(page)).toBe(before);
  });
});

test.describe('choosing a relationship', () => {
  test('two applicable types ask which, at the drop', async ({ page }) => {
    await openEditor(page, twoStocks);
    const { to } = await dragOver(page, 'price', 'demand');
    await page.mouse.up();

    await expect(page.locator(s.menu)).toBeVisible();
    await expect(page.locator(s.menuHead)).toHaveText('Price → Demand');
    // The notation names these for the menu; the ids stay `same`/`opposite`,
    // which is what the resulting VGL below still asserts.
    await expect(page.locator(s.menuItem)).toHaveText([
      '+  more → more',
      '−  more → less',
    ]);

    // At the mouseup position, not at the node the drag started on.
    const menu = await rectOf(page, s.menu);
    expect(Math.abs(menu.left - to.x)).toBeLessThan(4);

    await page.locator(s.menuItem, { hasText: 'more → less' }).click();
    await expect(page.locator(s.menu)).toHaveCount(0);
    expect(await vglText(page)).toContain('edge price -> demand: opposite');
  });

  test('abandoning the choice leaves the graph alone', async ({ page }) => {
    await openEditor(page, twoStocks);
    const before = await vglText(page);
    await dragOnto(page, 'price', 'demand');
    await expect(page.locator(s.menu)).toBeVisible();

    await page.mouse.click(5, 5);

    await expect(page.locator(s.menu)).toHaveCount(0);
    expect(await vglText(page)).toBe(before);
  });
});

test.describe('the notation break', () => {
  // Under a stationary pointer, which is the case only the keydown/keyup seam
  // can answer — no mousemove is coming to self-heal it.
  test('⌥ turns a red line green without the pointer moving', async ({ page }) => {
    await openEditor(page, connectable);
    await dragOver(page, 'idea', 'other');
    await expect(page.locator(s.dragIllegal)).toHaveCount(1);

    await page.keyboard.down('Alt');
    await expect(page.locator(s.dragLegal)).toHaveCount(1);

    // …and releasing it turns it back. Read continuously, never latched.
    await page.keyboard.up('Alt');
    await expect(page.locator(s.dragIllegal)).toHaveCount(1);

    await page.mouse.up();
  });

  // The break can never be silent: an unknown edge type renders bold red and the
  // diagnostics box says so.
  test('⌥ connects a pair the notation never joins', async ({ page }) => {
    await openEditor(page, connectable);
    const from = await centreOf(page, sel.node('idea'));
    const to = await centreOf(page, sel.node('other'));

    await page.keyboard.down('Alt');
    await page.mouse.move(from.x, from.y);
    await page.mouse.down();
    await page.mouse.move(from.x + 12, from.y + 12);
    await page.mouse.move(to.x, to.y, { steps: 4 });
    await page.mouse.up();
    await page.keyboard.up('Alt');

    expect(await vglText(page)).toContain('edge idea -> other');
    await expect(page.locator(s.diagnostics)).toContainText('invalid edge type');
  });

  // What the break costs now: nothing. It used to write a line the parser
  // refuses, so the diagram was gone on the next keystroke (ADR-0024).
  test('a break survives a keystroke in the text pane', async ({ page }) => {
    await openEditor(page, connectable);
    const from = await centreOf(page, sel.node('idea'));
    // The pair ConceptMap *does* join — the case that wrote the unreadable line.
    const to = await centreOf(page, sel.node('link'));

    await page.keyboard.down('Alt');
    await page.mouse.move(from.x, from.y);
    await page.mouse.down();
    await page.mouse.move(from.x + 12, from.y + 12);
    await page.mouse.move(to.x, to.y, { steps: 4 });
    await page.mouse.up();
    await page.keyboard.up('Alt');

    await page.locator(s.textarea).click();
    await page.keyboard.press('End');
    await page.keyboard.type(' ');

    await expect(page.locator(s.diagnostics)).not.toContainText('Parsing error');
    await expect(page.locator(s.diagnostics)).toContainText('invalid edge type');
  });
});
