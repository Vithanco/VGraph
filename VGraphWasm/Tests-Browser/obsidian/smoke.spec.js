// The plugin inside a real Obsidian: a throwaway vault in a second instance
// with its own --user-data-dir, so the maintainer's open Obsidian is untouched.
//
// Playwright's `_electron.launch` cannot drive Obsidian (its builds disable the
// Node inspector), so the app is spawned with a remote-debugging port and
// reached over CDP.

import { test, expect, chromium } from '@playwright/test';
import { spawn, execFileSync } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const pluginDir = path.resolve(process.env.OBSIDIAN_PLUGIN_DIR ?? path.join(here, '../../../obsidian-vithanco'));
const obsidianBin = process.env.OBSIDIAN_BIN ?? '/Applications/Obsidian.app/Contents/MacOS/Obsidian';
const NOTE = 'Vithanco smoke.md';
const PLAIN_NOTE = 'No diagrams.md';

// The installer's bundled app.asar lags the version users run; Obsidian loads
// the newest obsidian-<ver>.asar it finds in its user-data dir.
function newestInstalledAsar() {
  if (process.env.OBSIDIAN_ASAR !== undefined) return process.env.OBSIDIAN_ASAR || null;
  const dir = path.join(os.homedir(), 'Library/Application Support/obsidian');
  const version = (f) => f.slice('obsidian-'.length, -'.asar'.length).split('.').map(Number);
  const newer = (a, b) => { for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i] - b[i]; return 0; };
  const asars = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => /^obsidian-\d+\.\d+\.\d+\.asar$/.test(f)) : [];
  asars.sort((a, b) => newer(version(b), version(a)));
  return asars.length ? path.join(dir, asars[0]) : null;
}

function freePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer().listen(0, '127.0.0.1', () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    }).on('error', reject);
  });
}

function writeVault(workDir) {
  const userData = path.join(workDir, 'userdata');
  const vault = path.join(workDir, 'vault');
  const installed = path.join(vault, '.obsidian/plugins/vithanco');
  fs.mkdirSync(userData, { recursive: true });
  fs.mkdirSync(installed, { recursive: true });
  for (const f of ['main.js', 'manifest.json', 'styles.css']) {
    fs.copyFileSync(path.join(pluginDir, f), path.join(installed, f));
  }
  const asar = newestInstalledAsar();
  if (asar) fs.copyFileSync(asar, path.join(userData, path.basename(asar)));
  fs.writeFileSync(path.join(userData, 'obsidian.json'), JSON.stringify({
    vaults: { smoke000000000001: { path: vault, ts: Date.now(), open: true } },
    updateDisabled: true,
  }));
  fs.writeFileSync(path.join(vault, NOTE), [
    '```vgl',
    'vgraph decision: IBIS "Should we ship the plugin?" {',
    '  node q1: Question "Should we ship?";',
    '  node a1: Answer "Yes, soon";',
    '  edge q1 -> a1;',
    '}',
    '```',
    '',
    '```vgl',
    'vgraph broken: IBIS "x" { node q1: Question "?"',
    '```',
    '',
  ].join('\n'));
  fs.writeFileSync(path.join(vault, PLAIN_NOTE), 'Just text.\n');
  return userData;
}

// Every Obsidian process (main and helpers) carries --user-data-dir, so this
// reaches exactly the test instance and never the maintainer's.
function killInstance(userData) {
  try { execFileSync('pkill', ['-f', `user-data-dir=${userData}`]); } catch { /* none left */ }
}

async function connect(port) {
  for (let i = 0; i < 120; i++) {
    try { return await chromium.connectOverCDP(`http://127.0.0.1:${port}`); } catch { await new Promise((r) => setTimeout(r, 500)); }
  }
  throw new Error('Obsidian did not open its debugging port');
}

async function obsidianWindow(browser) {
  for (let i = 0; i < 120; i++) {
    const page = browser.contexts().flatMap((c) => c.pages()).find((p) => p.url().startsWith('app://'));
    if (page) return page;
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error('No Obsidian window appeared');
}

test.describe.configure({ mode: 'serial' });

let workDir, userData, child, page;
const pageErrors = [];

test.beforeAll(async () => {
  workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'vithanco-obsidian-smoke-'));
  userData = writeVault(workDir);
  const port = await freePort();
  child = spawn(obsidianBin, [`--user-data-dir=${userData}`, `--remote-debugging-port=${port}`], { stdio: 'ignore' });
  const browser = await connect(port);
  page = await obsidianWindow(browser);
  page.on('pageerror', (e) => pageErrors.push(e.message));
  await page.waitForFunction(() => window.app?.workspace?.layoutReady, null, { timeout: 60_000 });

  // A new vault that ships plugins asks before running them.
  const trust = page.getByRole('button', { name: 'Trust author and enable plugins' });
  await trust.click({ timeout: 10_000 }).catch(() => {});
  await enablePlugin();
});

async function enablePlugin() {
  await page.evaluate(async () => {
    await app.plugins.setEnable(true);
    await app.plugins.loadManifests();
    await app.plugins.enablePluginAndSave('vithanco');
  });
}

// `browser.close()` over CDP can hang; killing the app drops the connection.
test.afterAll(async () => {
  child?.kill('SIGTERM');
  if (userData) killInstance(userData);
  if (workDir) fs.rmSync(workDir, { recursive: true, force: true });
});

async function renderIn(theme) {
  await page.evaluate(async ({ theme, note }) => {
    app.changeTheme(theme);
    const leaf = app.workspace.getLeaf(false);
    await leaf.openFile(app.vault.getAbstractFileByPath(note), { state: { mode: 'preview' } });
    leaf.view.previewMode.rerender(true);
  }, { theme, note: NOTE });
  const view = page.locator('.markdown-reading-view');
  const svg = view.locator('.vithanco-container svg').first();
  await expect(svg).toBeVisible();
  await expect(view.locator('.vithanco-error-block')).toBeVisible();
  return page.evaluate(() => {
    const view = document.querySelector('.markdown-reading-view');
    const svg = view.querySelector('.vithanco-container svg');
    const box = svg.getBoundingClientRect();
    return {
      dark: document.body.classList.contains('theme-dark'),
      size: [box.width, box.height],
      labels: [...svg.querySelectorAll('text')].map((t) => t.textContent),
      fills: [...new Set([...svg.querySelectorAll('[fill]')].map((e) => e.getAttribute('fill')))].sort(),
      error: view.querySelector('.vithanco-error-block').textContent,
    };
  });
}

test('the plugin loads at the version in its manifest', async () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(pluginDir, 'manifest.json'), 'utf8'));
  const loaded = await page.evaluate(() => app.plugins.plugins.vithanco?.manifest.version ?? null);
  expect(loaded).toBe(manifest.version);
  const obsidian = await page.evaluate(() => require('electron').ipcRenderer.sendSync('version'));
  test.info().annotations.push({ type: 'obsidian', description: obsidian });
  console.log(`Obsidian ${obsidian}, plugin ${loaded}`);
});

let light;

test('a vgl block renders an SVG in the light theme, and a broken one shows the error block', async () => {
  light = await renderIn('moonstone');
  expect(light.dark).toBe(false);
  expect(light.size[0]).toBeGreaterThan(0);
  expect(light.size[1]).toBeGreaterThan(0);
  expect(light.labels).toContain('Should we ship?');
  expect(light.labels.join(' ')).toContain('Yes,');
  expect(light.error).toMatch(/error/i);
});

test('the same blocks render in the dark theme, in dark colours', async () => {
  const dark = await renderIn('obsidian');
  expect(dark.dark).toBe(true);
  expect(dark.size[0]).toBeGreaterThan(0);
  expect(dark.labels).toContain('Should we ship?');
  expect(dark.error).toMatch(/error/i);
  expect(dark.fills).not.toEqual(light.fills);
});

// The zoom's behaviour is the shared src/zoom.ts, tested in depth by
// vscode/preview.spec.js; this is that it is wired up in Obsidian, with
// Obsidian's styles.
const diagramBlock = () => page.locator('.markdown-reading-view .vithanco-container').first();
const zoomLabel = () => diagramBlock().locator('.vithanco-zoom-reset');
const svgWidth = () => diagramBlock().locator('svg').evaluate((e) => e.getBoundingClientRect().width);

test('+ enlarges a rendered diagram, and its label fits it again', async () => {
  await renderIn('moonstone');
  const fitted = await svgWidth();

  await diagramBlock().hover();
  await diagramBlock().locator('.vithanco-zoom-in').click();
  await expect(zoomLabel()).toHaveText(/^\d+%$/);
  await expect.poll(svgWidth).toBeGreaterThan(fitted * 1.1);

  await zoomLabel().click();
  await expect(zoomLabel()).toHaveText('Auto');
  await expect.poll(svgWidth).toBeCloseTo(fitted, 0);
});

test('a diagram zoomed wider than the note scrolls sideways inside its block', async () => {
  await renderIn('moonstone');
  const blockWidth = (await diagramBlock().boundingBox()).width;

  await diagramBlock().hover();
  for (let press = 0; press < 12 && (await zoomLabel().textContent()) !== '400%'; press++) {
    await diagramBlock().locator('.vithanco-zoom-in').click();
  }

  await expect(zoomLabel()).toHaveText('400%');
  expect(await svgWidth()).toBeGreaterThan(blockWidth);
  const viewport = diagramBlock().locator('.vithanco-zoom-viewport');
  const scrolled = () => viewport.evaluate((e) => e.scrollLeft);
  const before = await scrolled();
  await viewport.hover();
  await page.mouse.wheel(200, 0);
  await expect.poll(scrolled).toBeGreaterThan(before);
  expect((await diagramBlock().boundingBox()).width).toBeCloseTo(blockWidth, 0);
});

test('a zoom is gone when the note is opened again', async () => {
  await renderIn('moonstone');
  await diagramBlock().hover();
  await diagramBlock().locator('.vithanco-zoom-in').click();
  await expect(zoomLabel()).not.toHaveText('Auto');

  await showOnly(PLAIN_NOTE);
  await showOnly(NOTE);

  await expect(diagramBlock().locator('svg')).toBeVisible();
  await expect(zoomLabel()).toHaveText('Auto');
});

// Switching layout reloads the window, which may destroy the context mid-call,
// and comes back with the throwaway vault's plugins off.
async function emulateMobile(on) {
  await page.evaluate((on) => app.emulateMobile(on), on).catch((e) => {
    if (!/context was destroyed|app is not defined/.test(e.message)) throw e;
  });
  await page.waitForFunction((on) => window.app?.workspace?.layoutReady
    && document.body.classList.contains('is-mobile') === on, on, { timeout: 60_000 });
  await enablePlugin();
}

// A phone cannot hover, and an iPad with a trackpad says it can, so the mobile
// layout itself shows the controls. emulateMobile is Chromium, not WebKit.
test('in the mobile layout the zoom controls show without hovering, at finger size', async () => {
  await emulateMobile(true);
  try {
    await renderIn('moonstone');
    await page.evaluate(() => activeDocument.activeElement?.blur());
    await page.mouse.move(0, 0);
    const controls = page.locator('.markdown-reading-view .vithanco-container .vithanco-zoom-bar').first();
    await expect(controls).toHaveCSS('opacity', '1');
    const heights = await controls.locator('button').evaluateAll((bs) => bs.map((b) => b.getBoundingClientRect().height));
    expect(Math.min(...heights)).toBeGreaterThanOrEqual(32);
  } finally {
    await emulateMobile(false);
  }
});

async function showOnly(note) {
  await page.evaluate(async (note) => {
    const file = app.vault.getAbstractFileByPath(note);
    for (const leaf of new Set([app.workspace.getLeaf(false), ...app.workspace.getLeavesOfType('markdown')])) {
      await leaf.openFile(file, { state: { mode: 'preview' } });
    }
  }, note);
}

// Obsidian evaluates main.js afresh on enable, so this starts from no engine.
async function restartPlugin() {
  await page.evaluate(() => app.plugins.disablePlugin('vithanco'));
  await enablePlugin();
}

// Most launches show no diagram, and on a phone each launch would pay for it.
// A start unpacks the engine first, synchronously, so one begun in onload has
// already counted by the time the plugin is enabled.
test('the engine starts with the first diagram shown, and only once', async () => {
  await showOnly(PLAIN_NOTE);
  await page.evaluate(() => {
    const Unpack = window.DecompressionStream;
    window.vithancoStarts = 0;
    window.DecompressionStream = class extends Unpack {
      constructor(...args) { super(...args); window.vithancoStarts++; }
    };
    window.vithancoRestoreUnpack = () => { window.DecompressionStream = Unpack; };
  });
  try {
    await restartPlugin();
    expect(await page.evaluate(() => window.vithancoStarts)).toBe(0);

    await renderIn('moonstone');
    expect(await page.evaluate(() => window.vithancoStarts)).toBe(1);
  } finally {
    await page.evaluate(() => window.vithancoRestoreUnpack());
  }
});

// A phone has no developer console to send anyone to.
for (const [missing, reason] of [
  ['DecompressionStream', /iOS or iPadOS 16\.4 or newer/],
  ['WebAssembly', /Lockdown Mode/],
]) {
  test(`without ${missing}, each block says why the engine cannot start`, async () => {
    await showOnly(PLAIN_NOTE);
    await page.evaluate((name) => { window.vithancoStash = window[name]; delete window[name]; }, missing);
    try {
      await restartPlugin();
      await showOnly(NOTE);
      const errors = page.locator('.markdown-reading-view .vithanco-error-block');
      await expect(errors).toHaveCount(2);
      for (const error of await errors.all()) {
        await expect(error).toContainText(reason);
        await expect(error).not.toContainText(/console/i);
      }
    } finally {
      await page.evaluate((name) => { window[name] = window.vithancoStash; }, missing);
      await restartPlugin();
    }
  });
}

// Obsidian 1.13+ indexes `settingItems` for its settings search and renders the
// tab from the same definitions; a tab that only implements display() has neither.
test('the settings tab is declared, so settings search can find it', async () => {
  const entries = ['Syntax guide', 'Notations gallery', 'Sponsor on GitHub'];
  await page.evaluate(() => {
    app.setting.open();
    app.setting.openTabById('vithanco');
  });
  const read = () => page.evaluate(() => {
    const t = app.setting.pluginTabs.find((p) => p.id === 'vithanco');
    const names = (items) => items.flatMap((i) => [i.name, ...names(i.items ?? [])]).filter(Boolean);
    return {
      indexed: names(t?.settingItems ?? []),
      rendered: [...(t?.containerEl.querySelectorAll('.setting-item-name') ?? [])].map((e) => e.textContent),
    };
  });
  try {
    await expect.poll(async () => (await read()).indexed).toEqual(expect.arrayContaining(entries));
    await expect.poll(async () => (await read()).rendered).toEqual(expect.arrayContaining(entries));
  } finally {
    await page.evaluate(() => app.setting.close());
  }
});

// Obsidian asks plugins not to log; the engine's debug output and Graphviz's
// warnings belong to neither the user nor the developer console.
test('rendering writes nothing to the console', async () => {
  const logged = [];
  const listen = (m) => logged.push(`${m.type()}: ${m.text()}`);
  page.on('console', listen);
  try {
    await renderIn('moonstone');
    await renderIn('obsidian');
  } finally {
    page.off('console', listen);
  }
  expect(logged).toEqual([]);
});

test('no uncaught errors in the window', async () => {
  expect(pageErrors).toEqual([]);
});
