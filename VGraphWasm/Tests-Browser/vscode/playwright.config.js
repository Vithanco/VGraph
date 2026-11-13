// Not part of `just test-editor`: it needs the cloned extension. Run it with
// `just vscode-preview`.

import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  reporter: 'list',
  outputDir: '../test-results/vscode',
  use: { ...devices['Desktop Chrome'], viewport: { width: 800, height: 600 } },
});
