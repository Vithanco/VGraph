// Gathering several elements and making a group of them. See ADR-0018.
//
// Everything here is pointer behaviour, which is the half of this feature the
// Swift tests cannot reach: the 4px threshold, the containment test, and which
// of two gestures a mousedown arms are only observable in a real browser.

import { test, expect } from '@playwright/test';
import { s, sel, openEditor, vglText, emptyCanvas, rectOf } from '../helpers/editor.js';

const item = (page, text) => page.locator(s.menuItem).filter({ hasText: text });

// Two nodes outside a boundary and two inside it, so that "everything" and "all
// of one group" are different sets — on a smaller graph they coincide and the
// promotion rules cannot be told apart.
const boxed = `vgraph demo: ConceptMap "Demo" {
  node outside: Concept "Outside";
  node spare: Concept "Spare";
  group box "Box" {
    node one: Concept "One";
    node two: Concept "Two";
  }
}`;

const selectedIds = (page) =>
  page.evaluate(() => [...document.querySelectorAll('.vg-selected')].map((e) => e.id));

const groupEnabled = (page) =>
  page.evaluate(() => {
    const b = [...document.querySelectorAll('button')].find((x) => x.textContent.includes('Group'));
    return getComputedStyle(b).opacity === '1';
  });

// A rubber band has to *start* somewhere the connect drag does not claim, and
// move past the 4px threshold in steps — a single jump is not a drag.
async function band(page, from, to) {
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  await page.mouse.move(to.x, to.y, { steps: 10 });
  await page.mouse.up();
}

test('clicking a node selects it and nothing else', async ({ page }) => {
  await openEditor(page, boxed);
  await page.locator(sel.node('one')).click();

  expect(await selectedIds(page)).toEqual(['node-one']);
  expect(await groupEnabled(page)).toBe(true);
});

test('Shift-click extends, and the same Shift-click takes it back', async ({ page }) => {
  await openEditor(page, boxed);
  await page.locator(sel.node('one')).click();
  await page.locator(sel.node('outside')).click({ modifiers: ['Shift'] });

  expect(await selectedIds(page)).toEqual(['node-one', 'node-outside']);

  await page.locator(sel.node('outside')).click({ modifiers: ['Shift'] });
  expect(await selectedIds(page)).toEqual(['node-one']);
});

// The rule the design turns on: promotion is derived, so the toggle that caused
// it undoes it. Stored instead, the second Shift-click would have nothing to
// remove and the group could not be let go of.
test('selecting every member of a boundary promotes to the boundary, reversibly', async ({
  page,
}) => {
  await openEditor(page, boxed);
  await page.locator(sel.node('one')).click();
  await page.locator(sel.node('two')).click({ modifiers: ['Shift'] });

  expect(await selectedIds(page)).toEqual(['group-box']);

  await page.locator(sel.node('two')).click({ modifiers: ['Shift'] });
  expect(await selectedIds(page)).toEqual(['node-one']);
});

// Promotion stops below the root: it is the one group that cannot be pointed
// at, so it has no business in a set assembled by pointing.
test('selecting everything does not collapse to the diagram', async ({ page }) => {
  await openEditor(page, boxed);
  await page.locator(sel.node('outside')).click();
  await page.locator(sel.node('spare')).click({ modifiers: ['Shift'] });
  await page.locator(sel.node('one')).click({ modifiers: ['Shift'] });
  await page.locator(sel.node('two')).click({ modifiers: ['Shift'] });

  expect(await selectedIds(page)).toEqual(['group-box', 'node-outside', 'node-spare']);
  expect(await groupEnabled(page)).toBe(true);
});

test('clicking blank canvas clears, and so does Escape', async ({ page }) => {
  await openEditor(page, boxed);
  await page.locator(sel.node('one')).click();

  const empty = await emptyCanvas(page);
  await page.locator(s.preview).click({ position: empty });
  expect(await selectedIds(page)).toEqual([]);

  await page.locator(sel.node('one')).click();
  await page.locator(s.root).press('Escape');
  expect(await selectedIds(page)).toEqual([]);
});

test('a rubber band takes what it wholly encloses', async ({ page }) => {
  await openEditor(page, boxed);
  const svg = await rectOf(page, s.svg);
  const one = await rectOf(page, sel.node('one'));

  // From above-left of the diagram down to just past `one`'s bottom-right, so
  // it is contained and its neighbours are not.
  await band(
    page,
    { x: svg.left - 2, y: svg.top - 2 },
    { x: one.right + 3, y: one.bottom + 3 },
  );

  expect(await selectedIds(page)).toEqual(['node-one']);
});

// Containment, not touch: a band that clips a node without enclosing it takes
// nothing, which is the whole difference from the Figma-style rule.
test('a band that only clips a node leaves it alone', async ({ page }) => {
  await openEditor(page, boxed);
  const one = await rectOf(page, sel.node('one'));

  await band(
    page,
    { x: one.left - 12, y: one.top - 12 },
    { x: one.left + one.width / 2, y: one.top + one.height / 2 },
  );

  expect(await selectedIds(page)).toEqual([]);
});

test('the toolbar Group button makes a group of the selection', async ({ page }) => {
  await openEditor(page, boxed);
  await page.locator(sel.node('outside')).click();
  await page.locator(sel.node('spare')).click({ modifiers: ['Shift'] });

  await page.locator('button', { hasText: 'Group' }).click();

  const vgl = await vglText(page);
  expect(vgl).toContain('group group_2 "Change Me"');
  expect(vgl).toContain('node outside');
  // Named straight away, as a created node is (ADR-0016, ADR-0009).
  await expect(page.locator(s.inlineEdit)).toHaveValue('Change Me');
});

// The row says what it would cost, because that is the only warning offered —
// the command is one undo step, so it needs no dialog.
test('grouping across a boundary says how much it would move', async ({ page }) => {
  await openEditor(page, boxed);
  await page.locator(sel.node('one')).click();
  await page.locator(sel.node('outside')).click({ modifiers: ['Shift'] });
  await page.locator(sel.node('one')).click({ button: 'right' });

  await expect(page.locator(s.menuItem)).toHaveText([
    'Group (moves 1 out of their boundaries)',
    'Delete',
  ]);
});

test('right-clicking inside the selection keeps it', async ({ page }) => {
  await openEditor(page, boxed);
  await page.locator(sel.node('one')).click();
  await page.locator(sel.node('two')).click({ modifiers: ['Shift'] });
  // Promoted to the boundary; right-clicking a member must not undo that.
  await page.locator(sel.node('one')).click({ button: 'right' });

  expect(await selectedIds(page)).toEqual(['group-box']);
});

test('right-clicking outside the selection replaces it', async ({ page }) => {
  await openEditor(page, boxed);
  await page.locator(sel.node('one')).click();
  await page.locator(sel.node('outside')).click({ button: 'right' });

  expect(await selectedIds(page)).toEqual(['node-outside']);
});

// Regression: an edge cannot be selected, and routing the right-click through
// the selection left it with an empty set and so no menu at all.
test('an edge still has its own menu', async ({ page }) => {
  await openEditor(
    page,
    `vgraph demo: ConceptMap "Demo" {
  node idea: Concept "Idea";
  node link: Relation "leads to";
  edge idea -> link;
}`,
  );
  await page.locator(s.anyEdge).first().click({ button: 'right' });

  await expect(page.locator(s.menu)).toBeVisible();
  await expect(item(page, 'Change direction')).toBeVisible();
  await expect(item(page, 'Group'), 'an edge is not groupable').toHaveCount(0);
});

// Regression: with one node in the diagram, promoting to the root turned a
// right-click on that node into the canvas menu.
test('the only node in a diagram still gets the node menu', async ({ page }) => {
  await openEditor(page, `vgraph demo: ConceptMap "Demo" {\n  node idea: Concept "Idea";\n}`);
  await page.locator(sel.node('idea')).click({ button: 'right' });

  await expect(item(page, 'Add successor')).toBeVisible();
  await expect(item(page, 'Add node…'), 'that is the canvas menu').toHaveCount(0);
});

test('deleting a selection is one undo step', async ({ page }) => {
  await openEditor(page, boxed);
  await page.locator(sel.node('outside')).click();
  await page.locator(sel.node('spare')).click({ modifiers: ['Shift'] });
  await page.locator(sel.node('outside')).click({ button: 'right' });
  await item(page, 'Delete').click();

  await expect(page.locator(sel.node('outside'))).toHaveCount(0);
  await expect(page.locator(sel.node('spare'))).toHaveCount(0);

  await page.locator(s.textarea).press('ControlOrMeta+z');
  await expect(page.locator(sel.node('outside'))).toBeVisible();
  await expect(page.locator(sel.node('spare'))).toBeVisible();
});
