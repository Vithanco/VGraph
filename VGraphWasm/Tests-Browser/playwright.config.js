// Runs against the deployed build in `website/`, so `./build-wasm.sh` must have
// run first. See README.md for why this is a real browser and not jsdom.

import { defineConfig, devices } from '@playwright/test';

const PORT = 8733;

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',

  // The debug wasm is ~68 MB and instantiates per page load.
  timeout: 60_000,
  expect: { timeout: 10_000 },

  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    trace: 'retain-on-failure',
  },

  projects: [
    // The regression proof that moving to pointer events left the mouse
    // gestures alone.
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
      testIgnore: /touch\.spec\.js/,
    },
    // Tablet viewport with `hasTouch`, so `touch-action` and the mobile layout
    // are real. The touch *events* are dispatched by hand (see `finger` in
    // helpers/editor.js) — Playwright's own input is either mouse or a bare tap.
    {
      name: 'ipad',
      use: { ...devices['iPad Pro 11'] },
      testMatch: /touch\.spec\.js/,
    },
  ],

  webServer: {
    // Not `python3 -m http.server`: that inherits socketserver's listen backlog
    // of 5, and parallel workers each opening several connections overflow the
    // accept queue — the kernel then resets the excess, the page fails to fetch
    // `Package/index.js`, and the editor never boots. It surfaced as scattered
    // 30 s boot timeouts in whichever specs happened to race, which reads like
    // product flakiness and is not.
    command: `python3 -c "${[
      'import functools',
      'from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler',
      'ThreadingHTTPServer.request_queue_size = 128',
      "h = functools.partial(SimpleHTTPRequestHandler, directory='../../website')",
      `ThreadingHTTPServer(('127.0.0.1', ${PORT}), h).serve_forever()`,
    ].join('; ')}"`,
    url: `http://127.0.0.1:${PORT}/index.html`,
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
