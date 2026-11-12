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
  await page.evaluate(async () => {
    await app.plugins.setEnable(true);
    await app.plugins.loadManifests();
    await app.plugins.enablePluginAndSave('vithanco');
  });
});

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

// Obsidian 1.13+ indexes `settingItems` for its settings search and renders the
// tab from the same definitions; a tab that only implements display() has neither.
test('the settings tab is declared, so settings search can find it', async () => {
  const tab = await page.evaluate(async () => {
    app.setting.open();
    app.setting.openTabById('vithanco');
    await new Promise((r) => setTimeout(r, 300));
    const t = app.setting.pluginTabs.find((p) => p.id === 'vithanco');
    const names = (items) => items.flatMap((i) => [i.name, ...names(i.items ?? [])]).filter(Boolean);
    const result = {
      indexed: names(t?.settingItems ?? []),
      rendered: [...t.containerEl.querySelectorAll('.setting-item-name')].map((e) => e.textContent),
    };
    app.setting.close();
    return result;
  });
  expect(tab.indexed).toEqual(expect.arrayContaining(['Syntax guide', 'Notations gallery', 'Sponsor on GitHub']));
  expect(tab.rendered).toEqual(expect.arrayContaining(['Syntax guide', 'Notations gallery', 'Sponsor on GitHub']));
});

test('no uncaught errors in the window', async () => {
  expect(pageErrors).toEqual([]);
});
