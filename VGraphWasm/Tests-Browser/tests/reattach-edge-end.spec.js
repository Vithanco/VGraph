// Drag one end of an existing edge onto a different node (ADR-0021). Mirrors
// drag-to-connect.spec.js's shape: this is the second gesture told apart by
// what was *grabbed* rather than by where it lands, and ADR-0012's own warning
// — that the threshold, the hit test and the modifier timing are only
// observable in a real browser — applies here too.

import { test, expect } from '@playwright/test';
import {
  s, sel, openEditor, vglText, canUndo, centreOf, edgePathPoint, dragEdgeEndOver, dragEdgeEndOnto,
} from '../helpers/editor.js';

// Concept → Relation is declared both ways; Relation → Relation is not, so `r2`
// is a source the notation refuses wherever `r` is the fixed end. One edge only,
// so `s.anyEdge` addresses it without ambiguity.
const reattachable = `vgraph demo: ConceptMap "Demo" {
  node a: Concept "A";
  node b: Concept "B";
  node r2: Relation "R2";
  node r: Relation "leads to";
  edge a -> r;
}`;

// CLD declares Stock → Stock, so dragging an end onto the edge's *other* end
// makes a legal self-loop — unlike `connect`, which excludes the node just
// grabbed outright.
const causalLoop = `vgraph cld: CLD "Demo" {
  node s1: Stock "Price";
  node s2: Stock "Demand";
  edge s1 -> s2;
}`;

test.describe('grabbing the handle', () => {
  test('is invisible and inert until the edge is hovered', async ({ page }) => {
    await openEditor(page, reattachable);

    const opacity = await page.locator(sel.edgeEndOn(s.anyEdge, 'to')).evaluate(
      (el) => getComputedStyle(el).opacity,
    );
    const events = await page.locator(sel.edgeEndOn(s.anyEdge, 'to')).evaluate(
      (el) => getComputedStyle(el).pointerEvents,
    );
    expect(opacity).toBe('0');
    expect(events).toBe('none');
  });

  test('becomes visible once its edge is hovered', async ({ page }) => {
    await openEditor(page, reattachable);
    const mid = await edgePathPoint(page, s.anyEdge, 0.5);
    await page.mouse.move(mid.x, mid.y);

    const opacity = await page.locator(sel.edgeEndOn(s.anyEdge, 'to')).evaluate(
      (el) => getComputedStyle(el).opacity,
    );
    expect(opacity).toBe('1');
  });
});

test.describe('the drop', () => {
  test('a legal drop moves the end, keeping the edge id', async ({ page }) => {
    await openEditor(page, reattachable);
    await dragEdgeEndOnto(page, s.anyEdge, 'from', sel.node('b'));

    await expect(page.locator(s.textarea)).toHaveValue(/edge b -> r/);
    await expect(page.locator(s.textarea)).not.toHaveValue(/edge a -> r/);
    expect(await canUndo(page)).toBe(true);
  });

  test('a drop the notation forbids changes nothing', async ({ page }) => {
    await openEditor(page, reattachable);
    const before = await vglText(page);

    await dragEdgeEndOnto(page, s.anyEdge, 'from', sel.node('r2'));

    expect(await vglText(page)).toBe(before);
    expect(await canUndo(page)).toBe(false);
  });

  test('dropping back on the end\'s own node does nothing', async ({ page }) => {
    await openEditor(page, reattachable);
    const before = await vglText(page);

    await dragEdgeEndOnto(page, s.anyEdge, 'from', sel.node('a'));

    expect(await vglText(page)).toBe(before);
  });

  // Diverges from `connect`, which excludes the node just grabbed outright:
  // here the drag begins at a handle on the *far* node's rim, not on the node
  // being dropped onto, so the slip argument does not carry over. CLD carries
  // two relationship types between any Stock pair, self-loop included, so the
  // drop opens the same choice a cross-node drop would.
  test('a self-loop is offered where the notation declares one', async ({ page }) => {
    await openEditor(page, causalLoop);
    await dragEdgeEndOnto(page, s.anyEdge, 'to', sel.node('s1'));

    await expect(page.locator(s.menu)).toBeVisible();
    await expect(page.locator(s.menuHead)).toHaveText('Price → Price');
    await page.locator(s.menuItem, { hasText: 'more → more' }).click();

    await expect(page.locator(s.textarea)).toHaveValue(/edge s1 -> s1/);
  });

  test('a drop lands in history as one undo step', async ({ page }) => {
    await openEditor(page, reattachable);
    await dragEdgeEndOnto(page, s.anyEdge, 'from', sel.node('b'));
    await expect(page.locator(s.textarea)).toHaveValue(/edge b -> r/);

    await page.locator(s.textarea).press('ControlOrMeta+z');
    await expect(page.locator(s.textarea)).toHaveValue(/edge a -> r/);

    await page.locator(s.textarea).press('ControlOrMeta+Shift+z');
    await expect(page.locator(s.textarea)).toHaveValue(/edge b -> r/);
  });
});

test.describe('while dragging', () => {
  test('the edge in hand is dimmed', async ({ page }) => {
    await openEditor(page, reattachable);
    const to = await centreOf(page, sel.node('b'));
    await dragEdgeEndOver(page, s.anyEdge, 'from', to);

    await expect(page.locator(s.anyEdge)).toHaveClass(/vg-reattaching/);
    await page.mouse.up();
  });

  test('the dim clears once the drag ends', async ({ page }) => {
    await openEditor(page, reattachable);
    await dragEdgeEndOnto(page, s.anyEdge, 'from', sel.node('b'));

    await expect(page.locator(s.anyEdge)).not.toHaveClass(/vg-reattaching/);
  });

  // ⌥ is the escape hatch here exactly as it is for `connect`: it always mints
  // the break, even over a pair the notation would have joined happily.
  test('⌥ mints an unknown type even over a legal pair', async ({ page }) => {
    await openEditor(page, reattachable);
    const to = await centreOf(page, sel.node('b'));
    await dragEdgeEndOver(page, s.anyEdge, 'from', to);
    await page.keyboard.down('Alt');
    await page.mouse.move(to.x + 1, to.y);
    await page.mouse.up();
    await page.keyboard.up('Alt');

    const vgl = await vglText(page);
    expect(vgl).toMatch(/edge b -> r: __UNKNOWN_EDGE_TYPE__/);

    // And it survives the only thing that reparses. This line used to carry
    // `:Concept->Relation`, which the parser refuses — so the diagram was lost
    // on the next keystroke (ADR-0024).
    await page.locator(s.textarea).click();
    await page.keyboard.press('End');
    await page.keyboard.type(' ');
    await expect(page.locator(s.diagnostics)).not.toContainText('Parsing error');
  });
});

// The handle is mouse/pen-only — it appears on `:hover`, which a finger never
// produces — so a touch drag from an edge falls through to whatever bare drag
// already means there: nothing, since an edge is not draggable at all.
test.describe('touch', () => {
  test('a finger cannot reattach — the edge is not draggable', async ({ page }) => {
    await openEditor(page, reattachable);

    const events = await page.locator(sel.edgeEndOn(s.anyEdge, 'to')).evaluate(
      (el) => getComputedStyle(el).pointerEvents,
    );
    expect(events).toBe('none');
  });
});
