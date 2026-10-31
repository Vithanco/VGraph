import { test, expect } from '@playwright/test';
import {
  s, sel, oneConcept, causalLoop, groupedGraph, proposition, openEditor, vglText,
} from '../helpers/editor.js';

const item = (page, name) => page.locator(s.menuItem, { hasText: name });
const rightClickNode = (page, id) => page.locator(`${sel.node(id)} text`).last().click({ button: 'right' });
// The wrapping <g>, not its path: a straight edge's path has a zero-width
// bounding box, which Playwright reads as "not visible". The group's box also
// covers the arrow decoration, so the click lands on something paintable.
const rightClickEdge = (page, modifiers = []) =>
  page.locator(s.anyEdge).first().click({ button: 'right', modifiers });

test('right-clicking a node offers the commands that apply to it', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickNode(page, 'idea');

  await expect(page.locator(s.menu)).toBeVisible();
  await expect(page.locator(s.menuItem)).toHaveText([
    'Add successor', 'Add predecessor', 'Change type', 'Rename',
    'Open URL', 'Add URL…', 'Remove URL', 'Delete',
    // Appended to every menu built from a [[Selection]], which a right-click on
    // a selectable element always is now (ADR-0018).
    'Group',
  ]);
  await expect(item(page, 'Fold group'), 'folding is a group command').toHaveCount(0);
});

test('the dismiss layer closes the menu without touching the graph', async ({ page }) => {
  await openEditor(page, oneConcept);
  const before = await vglText(page);
  await rightClickNode(page, 'idea');
  await expect(page.locator(s.menu)).toBeVisible();

  await page.mouse.click(5, 5);

  await expect(page.locator(s.menu)).toHaveCount(0);
  expect(await vglText(page)).toBe(before);
});

test('the menu retargets at the next element right-clicked', async ({ page }) => {
  await openEditor(page, groupedGraph);
  await rightClickNode(page, 'detail');
  await expect(item(page, 'Fold group')).toHaveCount(0);

  // Through the dismiss layer, which is what the user's first click lands on.
  await page.mouse.click(5, 5);
  await expect(page.locator(s.menu)).toHaveCount(0);
  await page.locator(s.groupLabel).click({ button: 'right' });

  await expect(page.locator(s.menu)).toBeVisible();
  await expect(item(page, 'Fold group')).toBeVisible();
  await expect(item(page, 'Add successor')).toHaveCount(0);
});

test('a single candidate skips the menu and creates directly', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickNode(page, 'idea');
  await item(page, 'Add successor').click();

  await expect(page.locator(s.menu)).toHaveCount(0);
  const vgl = await vglText(page);
  expect(vgl).toContain('node relation_1: Relation');
  expect(vgl).toContain('edge idea -> relation_1');
});

test('the created node opens for naming, after the render', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickNode(page, 'idea');
  await item(page, 'Add successor').click();

  await expect(page.locator(sel.inlineEdit)).toHaveValue('Change Me');
  await expect(
    page.locator(sel.node('relation_1')),
    'the anchor only exists after the render, so opening first would cancel itself',
  ).toBeVisible();

  await page.locator(sel.inlineEdit).fill('depends on');
  await page.keyboard.press('Enter');
  await expect(page.locator(sel.textarea)).toHaveValue(/"depends on"/);
});

test('Option forces the candidate list open', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickNode(page, 'idea');
  await item(page, 'Add successor').click({ modifiers: ['Alt'] });

  await expect(page.locator(s.menu)).toBeVisible();
  await expect(page.locator(s.menuHead)).toHaveText('Add successor');
  await expect(page.locator(s.menuItem)).toHaveText(['Relation', 'Other type…']);
  expect(await vglText(page), 'still a conversation').not.toContain('relation_1');
});

test('two candidates are a genuine choice and are always shown', async ({ page }) => {
  await openEditor(page, causalLoop);
  await rightClickNode(page, 'stock');
  await item(page, 'Add successor').click();

  await expect(page.locator(s.menu)).toBeVisible();
  await expect(page.locator(s.menuItem)).toHaveText([
    'Stock (same)', 'Stock (opposite)', 'Other type…',
  ]);
});

test('the node-type list behind "Other type…" is never auto-picked', async ({ page }) => {
  await openEditor(page, causalLoop);
  await rightClickNode(page, 'stock');
  await item(page, 'Add successor').click();
  await item(page, 'Other type…').click();

  await expect(page.locator(s.menu)).toBeVisible();
  await expect(page.locator(s.menuHead)).toHaveText('Node type (breaks notation)');
  await expect(
    page.locator(s.menuItem),
    'a single entry is still shown, so a notation break is always seen',
  ).toHaveText(['Stock']);
  expect(await vglText(page)).not.toContain('stock_1');
});

test('Change type offers the substitutions the notation allows', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickNode(page, 'idea');
  await item(page, 'Change type').click();

  await expect(page.locator(s.menuHead)).toHaveText('Change type');
  // Nothing hangs off this node yet, so every other type is still reachable.
  await expect(page.locator(s.menuItem)).toHaveText(['EmphasizedConcept', 'Relation']);

  await item(page, 'EmphasizedConcept').click();
  await expect(page.locator(s.menu)).toHaveCount(0);
  expect(await vglText(page)).toContain('node idea: EmphasizedConcept "Idea"');
});

// Only a Concept may point at a Relation, so a Relation has nothing else it
// could be until Option says the notation may break.
test('Option enables a substitution the notation forbids', async ({ page }) => {
  await openEditor(page, proposition);
  await rightClickNode(page, 'link');
  await expect(item(page, 'Change type (breaks notation)')).toHaveClass(/vg-ctx-disabled/);

  await page.mouse.click(5, 5);
  await page.locator(`${sel.node('link')} text`).last().click({ button: 'right', modifiers: ['Alt'] });
  await item(page, 'Change type (breaks notation)').click({ modifiers: ['Alt'] });

  await expect(page.locator(s.menuItem)).toHaveText(['Other type…']);
  await item(page, 'Other type…').click();
  await expect(page.locator(s.menuHead)).toHaveText('Node type (breaks notation)');
  // Exact: "Concept" is a substring of "EmphasizedConcept".
  await page.locator(s.menuItem, { hasText: /^Concept$/ }).click();

  expect(await vglText(page)).toContain('node link: Concept');
});

test('Rename from the menu opens the same inline editor a double-click does', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickNode(page, 'idea');
  await item(page, 'Rename').click();

  await expect(page.locator(s.menu)).toHaveCount(0);
  await expect(page.locator(sel.inlineEdit)).toHaveValue('Idea');
});

test('Delete removes the element and is undoable', async ({ page }) => {
  await openEditor(page, groupedGraph);
  await rightClickNode(page, 'detail');
  await item(page, 'Delete').click();

  await expect(page.locator(sel.node('detail'))).toHaveCount(0);
  await page.locator(s.textarea).press('ControlOrMeta+z');
  await expect(page.locator(sel.node('detail'))).toBeVisible();
});

test('right-clicking an edge offers the commands that reshape it', async ({ page }) => {
  await openEditor(page, proposition);
  await rightClickEdge(page);

  await expect(page.locator(s.menu)).toBeVisible();
  await expect(page.locator(s.menuItem)).toHaveText([
    'Change direction', 'Change type', 'Split (breaks notation)', 'Rename',
    'Open URL', 'Add URL…', 'Remove URL', 'Delete',
  ]);
  await expect(
    item(page, 'Change type'),
    'ConceptMap declares one type for this pair, and there is no break to reach',
  ).toHaveClass(/vg-ctx-disabled/);
  await expect(
    item(page, 'Split (breaks notation)'),
    'nothing may sit between a Concept and a Relation',
  ).toHaveClass(/vg-ctx-disabled/);
});

test('changing direction flips the edge onto the opposite edge type', async ({ page }) => {
  await openEditor(page, proposition);
  await rightClickEdge(page);
  await item(page, 'Change direction').click();

  await expect(page.locator(s.menu)).toHaveCount(0);
  expect(await vglText(page)).toContain('edge link -> idea');
});

// The notation has no Concept → Concept type, so the flip stays greyed until
// Option says it may break.
test('Option enables a flip the notation forbids', async ({ page }) => {
  await openEditor(page, groupedGraph);
  await rightClickEdge(page);
  await expect(item(page, 'Change direction (breaks notation)')).toHaveClass(/vg-ctx-disabled/);

  await page.mouse.click(5, 5);
  await rightClickEdge(page, ['Alt']);
  await expect(item(page, 'Change direction (breaks notation)')).not.toHaveClass(/vg-ctx-disabled/);

  await item(page, 'Change direction (breaks notation)').click({ modifiers: ['Alt'] });
  expect(await vglText(page)).toContain('edge detail -> idea');
});

test('Split inserts the only node type the notation allows between the ends', async ({ page }) => {
  await openEditor(page, groupedGraph);
  await rightClickEdge(page);
  await item(page, 'Split').click();

  await expect(page.locator(s.menu)).toHaveCount(0);
  const vgl = await vglText(page);
  expect(vgl).toContain('node relation_1: Relation');
  expect(vgl).toContain('edge idea -> relation_1');
  expect(vgl).toContain('edge relation_1 -> detail');
  await expect(page.locator(sel.inlineEdit)).toHaveValue('Change Me');
});

// Stubbed rather than caught as a real popup: the assertion is about what the
// editor hands the browser, and a live `window.open` would go to the network.
const captureOpens = (page) => page.evaluate(() => {
  window.__opened = [];
  window.open = (...args) => { window.__opened.push(args); return null; };
});
const opened = (page) => page.evaluate(() => window.__opened);

test('a URL is typed into the menu and lands in the document', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickNode(page, 'idea');
  await item(page, 'Add URL…').click();

  await expect(page.locator(s.menuHead)).toHaveText('URL');
  await page.locator(s.ctxInput).fill('vithanco.com/docs');
  await page.keyboard.press('Enter');

  await expect(page.locator(s.menu)).toHaveCount(0);
  expect(await vglText(page), 'a bare host is completed to https')
    .toContain('url: "https://vithanco.com/docs"');
});

test('Open URL hands the stored link to the browser', async ({ page }) => {
  await openEditor(page, oneConcept);
  await captureOpens(page);
  await rightClickNode(page, 'idea');
  await item(page, 'Add URL…').click();
  await page.locator(s.ctxInput).fill('https://vithanco.com');
  await page.keyboard.press('Enter');

  const before = await vglText(page);
  await rightClickNode(page, 'idea');
  await item(page, 'Open URL').click();

  expect(await opened(page)).toEqual([['https://vithanco.com', '_blank', 'noopener,noreferrer']]);
  expect(await vglText(page), 'opening is not an edit').toBe(before);
  await expect(page.locator(s.menu)).toHaveCount(0);
});

test('opening and removing stay greyed out until there is a link', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickNode(page, 'idea');

  await expect(item(page, 'Open URL')).toHaveClass(/vg-ctx-disabled/);
  await expect(item(page, 'Remove URL')).toHaveClass(/vg-ctx-disabled/);

  await item(page, 'Add URL…').click();
  await page.locator(s.ctxInput).fill('https://vithanco.com');
  await page.keyboard.press('Enter');
  await rightClickNode(page, 'idea');

  await expect(item(page, 'Open URL')).not.toHaveClass(/vg-ctx-disabled/);
  await expect(item(page, 'Change URL…'), 'add became change').toBeVisible();

  await item(page, 'Remove URL').click();
  expect(await vglText(page)).not.toContain('url:');
});

// The field is seeded from the graph, and a re-ask keeps what was typed rather
// than throwing it away — the same contract as the inline editor.
test('a link that is not one is asked for again, not reported as an error', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickNode(page, 'idea');
  await item(page, 'Add URL…').click();
  await page.locator(s.ctxInput).fill('javascript:alert(1)');
  await page.keyboard.press('Enter');

  await expect(page.locator(s.ctxInput)).toHaveValue('javascript:alert(1)');
  expect(await vglText(page)).not.toContain('url:');

  await page.locator(s.ctxInput).fill('https://vithanco.com');
  await page.keyboard.press('Enter');
  expect(await vglText(page)).toContain('url: "https://vithanco.com"');
});

// The badge is a real SVG <a>, so following it needs no editor code — which is
// also what makes an exported SVG keep its links.
test('a linked element wears a badge that is a real anchor', async ({ page }) => {
  await openEditor(page, oneConcept);
  await expect(page.locator(s.urlBadge)).toHaveCount(0);

  await rightClickNode(page, 'idea');
  await item(page, 'Add URL…').click();
  await page.locator(s.ctxInput).fill('https://vithanco.com');
  await page.keyboard.press('Enter');

  const badge = page.locator(`${sel.node('idea')} ${s.urlBadge}`);
  await expect(badge).toHaveCount(1);
  await expect(badge).toHaveAttribute('href', 'https://vithanco.com');
  await expect(badge).toHaveAttribute('target', '_blank');
  await expect(badge, 'the destination is readable before the click')
    .toContainText('https://vithanco.com');
});

test('a single click on the badge follows the link', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickNode(page, 'idea');
  await item(page, 'Add URL…').click();
  await page.locator(s.ctxInput).fill('https://vithanco.com');
  await page.keyboard.press('Enter');

  // Served locally: the assertion is that the click navigates somewhere, and a
  // test that needs the real internet to prove it would be a flake.
  await page.context().route('https://vithanco.com/**', (route) =>
    route.fulfill({ contentType: 'text/html', body: '<p>followed</p>' }));

  // The anchor is native, so the new tab is a real popup rather than a stubbed
  // window.open call.
  const popup = page.context().waitForEvent('page');
  await page.locator(s.urlBadge).click();

  const opened = await popup;
  await opened.waitForLoadState();
  expect(opened.url()).toContain('vithanco.com');
  await expect(opened.locator('p')).toHaveText('followed');
});

// The first click has already opened the tab, so a second must not leave a
// rename editor open behind a page the user has just navigated to.
test('double-clicking the badge does not open a rename', async ({ page }) => {
  await openEditor(page, oneConcept);
  await page.context().route('https://vithanco.com/**', (route) =>
    route.fulfill({ contentType: 'text/html', body: 'ok' }));
  await rightClickNode(page, 'idea');
  await item(page, 'Add URL…').click();
  await page.locator(s.ctxInput).fill('https://vithanco.com');
  await page.keyboard.press('Enter');

  await page.locator(s.urlBadge).dblclick();

  await expect(page.locator(sel.inlineEdit)).toHaveCount(0);
});

test('the badge goes away with the link', async ({ page }) => {
  await openEditor(page, oneConcept);
  await rightClickNode(page, 'idea');
  await item(page, 'Add URL…').click();
  await page.locator(s.ctxInput).fill('https://vithanco.com');
  await page.keyboard.press('Enter');
  await expect(page.locator(s.urlBadge)).toHaveCount(1);

  await rightClickNode(page, 'idea');
  await item(page, 'Remove URL').click();

  await expect(page.locator(s.urlBadge)).toHaveCount(0);
});

test('folding a group redraws it as a single node', async ({ page }) => {
  await openEditor(page, groupedGraph);
  await page.locator(s.groupLabel).click({ button: 'right' });
  await item(page, 'Fold group').click();

  // Still `group-g1`: the box represents the group (ADR-0027).
  await expect(page.locator(`${sel.group('g1')}.vgraph-folded-group`)).toBeVisible();
  await expect(page.locator('.vgraph-group-label')).toHaveCount(0);
});

// Double-click is rename everywhere else, and the box is the group.
test('double-clicking a folded group renames it', async ({ page }) => {
  await openEditor(page, `vgraph demo: ConceptMap "Demo" {
  folded group box "Box" {
    node one: Concept "One";
  }
}`);

  await page.locator(`${sel.group('box')} text`).first().dblclick();

  await expect(page.locator(s.inlineEdit)).toBeVisible();
  await expect(page.locator(s.inlineEdit)).toHaveValue('Box');
});
