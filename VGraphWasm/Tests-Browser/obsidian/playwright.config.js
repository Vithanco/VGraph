// Not part of `just test-editor`: it needs a desktop Obsidian install and the
// cloned plugin, and it opens a window. Run it with `just obsidian-smoke`.

import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  workers: 1,
  reporter: 'list',
  outputDir: '../test-results/obsidian',
  timeout: 180_000,
  expect: { timeout: 30_000 },
});
