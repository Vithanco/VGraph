// Adding a node from the UI — the wiring ADR-0016 describes: blank canvas is the
// root group, a group's menu adds into that group, and the toolbar button asks
// with no pointer at all.
//
// The domain half is covered by AddNodeTest in AppTests. What only a browser can
// show is the three entry points reaching it, and the inline editor opening on
// what was created.

import { test, expect } from '@playwright/test';
import {
  s, sel, oneConcept, causalLoop, groupedGraph, openEditor, vglText, canUndo, emptyCanvas,
} from '../helpers/editor.js';

const item = (page, name) => page.locator(s.menuItem, { hasText: name });
// "Concept" is a prefix of "EmphasizedConcept", so the type list needs an exact
// match where the command names do not.
const typeItem = (page, name) =>
  page.locator(s.menuItem).filter({ hasText: new RegExp(`^${name}$`) });
const toolbarButton = (page, name) =>
  page.locator(s.toolbar).locator('button').filter({ hasText: name });

const rightClickCanvas = async (page) =>
  page.locator(s.preview).click({ button: 'right', position: await emptyCanvas(page) });

const foldedGroup = `vgraph demo: ConceptMap "Folded" {
  folded group g1 "Cluster" {
    node a: Concept "A";
  }
}`;

test('the canvas menu offers Add node and greys everything else', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickCanvas(page);

  await expect(page.locator(s.menu)).toBeVisible();
  await expect(page.locator(s.menuItem)).toHaveText([
    'Add node…', 'Fold group', 'Change type', 'Rename', 'Open URL', 'Add URL…', 'Remove URL',
    'Ungroup', 'Delete', 'Layout direction…',
  ]);

  // Two live rows: adding, and the layout direction, a setting of the whole
  // diagram. The rest are things a diagram as a whole cannot be, and they are
  // disabled rather than absent because the group menu is shared.
  const enabled = page.locator(`${s.menuItem}:not(.vg-ctx-disabled)`);
  await expect(enabled).toHaveText(['Add node…', 'Layout direction…']);
});

test('adding from the canvas creates a node at the top level and opens its editor', async ({
  page,
}) => {
  await openEditor(page, oneConcept);
  await rightClickCanvas(page);
  await item(page, 'Add node…').click();

  // A plain node-type list: no candidates, because there is no edge for the
  // notation to decide, and no "Other type…" because nothing here breaks it.
  await expect(page.locator(s.menuItem)).toHaveText([
    'Concept', 'EmphasizedConcept', 'Relation',
  ]);
  await typeItem(page, 'EmphasizedConcept').click();

  expect(await vglText(page)).toContain(
    'node emphasizedconcept_1: EmphasizedConcept "Change Me"');
  await expect(page.locator(s.inlineEdit)).toHaveValue('Change Me');
  expect(await canUndo(page)).toBe(true);
});

test('adding from a group menu puts the node in that group', async ({ page }) => {
  await openEditor(page, groupedGraph);
  await page.locator(`${sel.group('g1')} rect`).click({ button: 'right', position: { x: 4, y: 30 } });
  await item(page, 'Add node…').click();
  await typeItem(page, 'Concept').click();

  // Inside the braces, which is the whole claim: `[^}]*` cannot cross the
  // group's closing brace, so a node that landed at the top level fails this
  // even though the exporter emits top-level nodes first.
  //
  // `concept_3`: ids count how many of that type exist, and `idea` and `detail`
  // are both Concepts.
  const vgl = await vglText(page);
  expect(vgl).toMatch(/group g1 "My Group" \{[^}]*node concept_3: Concept "Change Me"[^}]*\}/);
});

test('the toolbar button adds at the top level with no pointer', async ({ page }) => {
  await openEditor(page, oneConcept);

  await toolbarButton(page, 'Node').click();
  await typeItem(page, 'Concept').click();

  expect(await vglText(page)).toContain('node concept_2: Concept "Change Me"');
  await expect(page.locator(s.inlineEdit)).toHaveValue('Change Me');
});

test('a notation with one node type asks nothing', async ({ page }) => {
  await openEditor(page, causalLoop);
  await rightClickCanvas(page);
  await item(page, 'Add node…').click();

  // Straight to the node — a dialog with a single button is not a question.
  await expect(page.locator(s.menu)).toHaveCount(0);
  expect(await vglText(page)).toContain('node stock_2: Stock "Change Me"');
});

test('adding into a folded group leaves it folded, and one undo takes the node back', async ({
  page,
}) => {
  await openEditor(page, foldedGroup);
  const before = await vglText(page);

  // A folded group's box is stamped as the group it represents (ADR-0027).
  await page.locator(sel.group('g1')).click({ button: 'right' });
  await item(page, 'Add node…').click();
  await typeItem(page, 'Concept').click();

  const after = await vglText(page);
  expect(after).toContain('node concept_2');
  expect(after, 'folding is the author\'s alone').toContain('folded group g1');

  await page.locator(s.undo).click();
  await expect(page.locator(s.textarea)).toHaveValue(before);
});
