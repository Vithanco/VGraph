// A stand-in for VS Code's Markdown preview: what the extension contributes to
// it — the block markup, the preview script and the styles — in a plain page.

import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const pluginDir = path.resolve(process.env.VSCODE_PLUGIN_DIR ?? path.join(here, '../../../vscode-vithanco'));
export const { svgHtml, placeholderHtml } = await import(path.join(pluginDir, 'src/html.ts'));

// The engine sets width and height to the viewBox's.
export const diagram = (w, h) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">` +
  `<rect width="${w}" height="${h}" fill="#dde"/><circle cx="${w / 2}" cy="${h / 2}" r="${h / 3}" fill="#88a"/></svg>`;
export const wide = svgHtml(diagram(1600, 400));

export const block = (page, n = 0) => page.locator('.vgraph-rendered').nth(n);
export const label = (page, n = 0) => block(page, n).locator('.vithanco-zoom-reset');
export const press = (page, which, n = 0) => block(page, n).locator(`.vithanco-zoom-${which}`).click();
export const rect = (page, n = 0) => block(page, n).locator('svg').evaluate((e) => e.getBoundingClientRect().toJSON());
export const overflow = (page, n = 0) =>
  block(page, n).locator('.vithanco-zoom-viewport').evaluate((e) => e.scrollWidth - e.clientWidth);

export async function openPreview(page, blocks) {
  await page.setContent(`<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body class="vscode-body"><div class="markdown-body">${blocks.join('')}</div></body></html>`);
  await page.addStyleTag({ path: path.join(pluginDir, 'styles.css') });
  await page.addScriptTag({ path: path.join(pluginDir, 'out/preview.js') });
}
