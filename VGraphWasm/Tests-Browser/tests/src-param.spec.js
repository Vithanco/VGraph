// `?src=` — seeding the editor with a *reference* to a document rather than the
// document itself. The fetch lives in the host page, so these are the
// only tests that exercise `website/index.html` as more than a loader.
//
// Same-origin sources are real files under `website/test-fixtures/` rather than
// intercepted routes: fulfilling a same-origin request from the test driver
// while the 79 MB wasm is still streaming stalls the boot. Cross-origin sources
// have no such trouble and are still served by interception, there being no
// second origin to put a file on.

import { test, expect } from '@playwright/test';
import { readFileSync, writeFileSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  s,
  sel,
  oneConcept,
  openEditor,
  openEditorAt,
  serveSrc,
  savedNameOf,
  savedSVG,
  canUndo,
} from '../helpers/editor.js';

const fixturePath = (name) =>
  fileURLToPath(new URL(`../../../website/test-fixtures/${name}`, import.meta.url));
const fixtureText = (name) => readFileSync(fixturePath(name), 'utf8');

test('?src= seeds the editor from a file, and the document takes its name', async ({ page }) => {
  await openEditorAt(page, '?src=/test-fixtures/ibis-example.vgl');

  await expect(page.locator(s.textarea)).toHaveValue(fixtureText('ibis-example.vgl'));
  await expect(page.locator(sel.node('idea'))).toBeVisible();
  // A save is the only place the document's name surfaces — nothing draws it.
  expect(await savedNameOf(page, 'Save VGL')).toBe('ibis-example.vgl');
  expect(await canUndo(page), 'a fetched document is a new document').toBe(false);
});

test('?src= accepts a .vithanco.svg and loads the VGL it carries', async ({ page }) => {
  // Minted by the editor rather than written by hand: the metadata envelope is
  // owned by SVGBuilder precisely so nobody keeps a second copy of its spelling.
  await openEditor(page, fixtureText('grouped.vgl'));
  const name = 'round-trip.generated.vithanco.svg';
  writeFileSync(fixturePath(name), await savedSVG(page), 'utf8');

  try {
    await openEditorAt(page, `?src=/test-fixtures/${name}`);

    await expect(page.locator(sel.group('g1')), 'the graph is back').toBeVisible();
    await expect(page.locator(s.textarea), 'the VGL, not the SVG markup').toHaveValue(
      /^vgraph demo:/
    );
    // Both extensions come off, so a second save does not grow the name.
    expect(await savedNameOf(page, 'Save SVG')).toBe(name);
  } finally {
    rmSync(fixturePath(name), { force: true });
  }
});

test('an SVG carrying no VGL is refused through ?src= as it is through the File menu', async ({
  page,
}) => {
  await openEditorAt(page, '?src=/test-fixtures/elsewhere.svg');

  await expect(page.locator(s.status)).toContainText('carries no VGL');
});

test('a ?src= that 404s says so and leaves a usable editor', async ({ page }) => {
  await openEditorAt(page, '?src=/test-fixtures/not-here.vgl');

  await expect(page.locator(s.status)).toContainText('not-here.vgl');
  await expect(page.locator(sel.node('idea')), 'the default diagram still renders').toBeVisible();
});

test('a cross-origin http: source is refused without being fetched', async ({ page }) => {
  // Matched on the host, not on the URL text: the page's own address carries
  // `example.org` inside the query string.
  const reached = [];
  page.on('request', (r) => {
    if (new URL(r.url()).host === 'example.org') reached.push(r.url());
  });

  await openEditorAt(page, '?src=http://example.org/shared/idea.vgl');

  await expect(page.locator(s.status)).toContainText('https');
  expect(reached, 'refused before the network, not by the browser').toEqual([]);
});

test('a cross-origin https: source loads, and the status says where it came from', async ({
  page,
}) => {
  await serveSrc(page, 'https://example.org/**', oneConcept);

  await openEditorAt(page, '?src=https://example.org/shared/idea.vgl');

  await expect(page.locator(s.textarea)).toHaveValue(oneConcept);
  // Otherwise a stranger's diagram is indistinguishable from one of ours.
  await expect(page.locator(s.status)).toContainText('example.org');
});

test('?src= wins when both parameters are given', async ({ page }) => {
  await openEditorAt(
    page,
    `?vgl=${encodeURIComponent(oneConcept)}&src=/test-fixtures/grouped.vgl`
  );

  await expect(page.locator(sel.group('g1')), 'the file, not the inline text').toBeVisible();
});
