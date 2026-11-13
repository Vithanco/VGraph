// Not part of `just test-editor`: it needs the cloned extension. Run it with
// `just vscode-preview`.

import { defineConfig, devices } from '@playwright/test';

const viewport = { width: 800, height: 600 };

export default defineConfig({
  testDir: '.',
  reporter: 'list',
  outputDir: '../test-results/vscode',
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'], viewport }, testIgnore: /touch\.spec\.js/ },
    // zoom.ts is shared with the Obsidian plugin, which on iOS runs in WebKit.
    { name: 'webkit', use: { ...devices['Desktop Safari'], viewport }, testIgnore: /touch\.spec\.js/ },
    { name: 'iphone', use: { ...devices['iPhone 13'] }, testMatch: /touch\.spec\.js/ },
  ],
});
