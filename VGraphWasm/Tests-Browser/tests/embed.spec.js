// The drop-in embed, `embed.js`, on a page that is not ours. The host page and
// the engine sit on two other origins, as a third-party page and a CDN would,
// and the page carries nothing but the script tag: no import map. The CDN
// serves only the two files the embed ships as, so a bare import or a fetch of
// the unbundled glue fails here as it would on jsDelivr.

import { test, expect } from '@playwright/test';
import { createReadStream } from 'node:fs';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';

const PACKAGE = fileURLToPath(new URL('../../../website/Package/', import.meta.url));
const CDN_PATH = '/npm/@vithanco/vgraph@1/';
const SHIPPED = { 'embed.js': 'text/javascript', 'VGraphWasm.wasm': 'application/wasm' };

// A real server rather than route.fulfill: fulfill sends the body to the
// browser in one protocol message, and CI's ~120 MB debug wasm closes the page.
// It serves the page too, on localhost while the CDN is on 127.0.0.1: two
// origins, and Chrome only lets a page it got from the network load off loopback.
const pages = new Map();
let server;
let CDN;
let PAGE;
test.beforeAll(async () => {
  server = createServer((req, res) => {
    const path = new URL(req.url, 'http://local').pathname;
    if (pages.has(path)) return res.writeHead(200, { 'content-type': 'text/html' }).end(pages.get(path));
    const name = path.startsWith(CDN_PATH) ? path.slice(CDN_PATH.length) : '';
    if (!(name in SHIPPED)) return res.writeHead(404).end('not shipped');
    res.writeHead(200, { 'content-type': SHIPPED[name], 'access-control-allow-origin': '*' });
    createReadStream(PACKAGE + name).pipe(res);
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  CDN = `http://127.0.0.1:${port}${CDN_PATH}`;
  PAGE = `http://localhost:${port}`;
});
test.afterAll(() => new Promise((resolve) => server.close(resolve)));

const concept = (label) => `vgraph demo: ConceptMap "Demo" {
  node idea: Concept "${label}";
}`;

async function hostPage(page, body, { query = '' } = {}) {
  const path = `/page/${pages.size}`;
  pages.set(
    path,
    `<!doctype html><html><head><meta charset="utf-8"></head><body>
${body}
<script type="module" src="${CDN}embed.js${query}"></script>
</body></html>`,
  );
  const requests = [];
  page.on('request', (r) => requests.push(r.url()));
  const local = [PAGE, new URL(CDN).origin];
  await page.route('**/*', (route) =>
    local.includes(new URL(route.request().url()).origin) ? route.continue() : route.abort(),
  );
  await page.goto(PAGE + path);
  return requests;
}

const wasmRequests = (requests) => requests.filter((u) => u.endsWith('/VGraphWasm.wasm'));

const svgMarkup = (page, selector) =>
  page.evaluate((q) => document.querySelector(q).shadowRoot.querySelector('svg')?.outerHTML, selector);

test('two diagrams sharing a node id render apart, each in a shadow root, and the page keeps its styles', async ({
  page,
}) => {
  await hostPage(
    page,
    `<style>p { color: rgb(1, 2, 3); }</style>
<p class="vgraph-node" id="decoy">A host element that happens to share the engine's class.</p>
<pre class="vgl">${concept('First')}</pre>
<pre class="vgl">${concept('Second')}</pre>`
  );

  await expect(page.locator('vgl-diagram svg')).toHaveCount(2);
  await expect(page.locator('vgl-diagram').first()).toContainText('First');
  await expect(page.locator('vgl-diagram').last()).toContainText('Second');

  const dom = await page.evaluate(() => {
    const hosts = [...document.querySelectorAll('vgl-diagram')];
    const decoy = getComputedStyle(document.getElementById('decoy'));
    return {
      pre: document.querySelectorAll('pre').length,
      lightSvg: document.querySelectorAll('svg').length,
      lightStyles: document.querySelectorAll('style').length,
      lightNode: document.getElementById('node-idea'),
      inShadow: hosts.map((h) => h.shadowRoot?.querySelectorAll('#node-idea').length),
      // `<use href="#icon-concept">` resolves inside its own tree, or draws nothing.
      iconWidth: hosts.map((h) => h.shadowRoot.querySelector('use[href^="#icon-"]').getBBox().width),
      decoy: { cursor: decoy.cursor, transition: decoy.transitionProperty, color: decoy.color },
    };
  });

  expect(dom.pre, 'each pre.vgl is replaced').toBe(0);
  expect(dom.lightSvg, 'no SVG in the page itself').toBe(0);
  expect(dom.lightStyles, 'only the host page’s own <style>').toBe(1);
  expect(dom.lightNode, 'the ids stay out of the page').toBeNull();
  expect(dom.inShadow).toEqual([1, 1]);
  expect(dom.iconWidth.every((w) => w > 0), `icon widths ${dom.iconWidth}`).toBe(true);
  expect(dom.decoy).toEqual({ cursor: 'auto', transition: 'all', color: 'rgb(1, 2, 3)' });
});

test('an invalid block shows the error in its place, and the valid one still renders', async ({ page }) => {
  await hostPage(
    page,
    `<pre class="vgl">not vgl at all {{{</pre>
<pre class="vgl">${concept('Fine')}</pre>`
  );

  const [broken, fine] = [page.locator('vgl-diagram').first(), page.locator('vgl-diagram').last()];
  await expect(fine.locator('svg')).toHaveCount(1);
  await expect(broken.getByRole('alert')).toContainText("Expected 'vgraph'");
  await expect(broken.locator('svg')).toHaveCount(0);
});

test('a page without a diagram never loads the engine; diagrams added later load it once', async ({
  page,
}) => {
  const requests = await hostPage(page, `<p>No diagrams yet.</p>`);
  await page.waitForLoadState('networkidle');
  expect(requests.some((u) => u.endsWith('/embed.js')), 'the script itself loads').toBe(true);
  expect(wasmRequests(requests)).toEqual([]);

  await page.evaluate((vgl) => {
    const pre = document.createElement('pre');
    pre.className = 'vgl';
    pre.textContent = vgl.replace('LABEL', 'Pre');
    const codePre = document.createElement('pre');
    codePre.innerHTML = '<code class="language-vgl"></code>';
    codePre.firstChild.textContent = vgl.replace('LABEL', 'Code');
    const element = document.createElement('vgl-diagram');
    element.textContent = vgl.replace('LABEL', 'Element');
    document.body.append(pre, codePre, element);
  }, concept('LABEL'));

  await expect(page.locator('vgl-diagram svg')).toHaveCount(3);
  for (const label of ['Pre', 'Code', 'Element']) {
    await expect(page.locator('vgl-diagram', { hasText: label }).locator('svg')).toHaveCount(1);
  }
  expect(await page.locator('pre').count(), 'a code block’s <pre> goes too').toBe(0);
  expect(wasmRequests(requests)).toHaveLength(1);
});

test('diagrams follow prefers-color-scheme unless data-theme pins them', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light' });
  const vgl = concept('Theme');
  await hostPage(
    page,
    `<pre class="vgl" id="auto">${vgl}</pre>
<pre class="vgl" id="light" data-theme="light">${vgl}</pre>
<pre class="vgl" id="dark" data-theme="dark">${vgl}</pre>`
  );
  await expect(page.locator('vgl-diagram svg')).toHaveCount(3);

  const light = await svgMarkup(page, '#light');
  const dark = await svgMarkup(page, '#dark');
  expect(light, 'the two themes render differently').not.toBe(dark);
  expect(await svgMarkup(page, '#auto')).toBe(light);

  await page.emulateMedia({ colorScheme: 'dark' });
  await expect.poll(() => svgMarkup(page, '#auto')).toBe(dark);
  expect(await svgMarkup(page, '#light'), 'pinned light stays light').toBe(light);
});

test('the web font loads once into the page, where a shadow root can use it', async ({
  page,
}) => {
  const requests = await hostPage(page, `<pre class="vgl">${concept('A')}</pre><pre class="vgl">${concept('B')}</pre>`);
  await expect(page.locator('vgl-diagram svg')).toHaveCount(2);

  const fonts = await page.evaluate(() => ({
    links: document.head.querySelectorAll('link[rel="stylesheet"][href^="https://fonts.googleapis.com/"]').length,
    imports: [...document.querySelectorAll('vgl-diagram')].filter((h) =>
      [...h.shadowRoot.querySelectorAll('style')].some((st) => st.textContent.includes('@import'))
    ).length,
  }));
  expect(fonts).toEqual({ links: 1, imports: 0 });
  expect(requests.filter((u) => u.startsWith('https://fonts.googleapis.com/'))).toHaveLength(1);
});

test('?fonts=none keeps the page off Google Fonts', async ({ page }) => {
  const requests = await hostPage(page, `<pre class="vgl">${concept('A')}</pre>`, { query: '?fonts=none' });
  await expect(page.locator('vgl-diagram svg')).toHaveCount(1);
  await page.waitForLoadState('networkidle');

  expect(requests.filter((u) => u.includes('fonts.g'))).toEqual([]);
  expect(await page.locator('link[href*="fonts.googleapis.com"]').count()).toBe(0);
});
