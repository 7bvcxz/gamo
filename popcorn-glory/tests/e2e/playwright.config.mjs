// Browser tests for the Popcorn web build (docs/popcorn-glory/).
//
//   popcorn-glory/tools/e2e.sh [specs/stub03.spec.mjs ...] [--project phone]
//
// Served locally from docs/ -- the server root has to be docs/, not the game
// folder: the page loads the shared engine from ../engine/ (AGENTS.md,
// 2026-08-10). With POPCORN_E2E_BASE set, runs against a deployed build.
import { defineConfig } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const docs = path.resolve(here, '../../../docs');
const port = Number(process.env.POPCORN_E2E_PORT || 18530);

export default defineConfig({
  testDir: './specs',
  timeout: 180_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list']],
  use: { baseURL: process.env.POPCORN_E2E_BASE || `http://127.0.0.1:${port}/popcorn-glory/` },
  webServer: process.env.POPCORN_E2E_BASE ? undefined : {
    command: `python3 -m http.server ${port} --bind 127.0.0.1 --directory ${docs}`,
    url: `http://127.0.0.1:${port}/popcorn-glory/version.json`,
    reuseExistingServer: false,
    timeout: 20_000,
  },
  projects: [
    { name: 'p720', use: { viewport: { width: 720, height: 1280 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true } },
    { name: 'phone', use: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true } },
    { name: 'desktop', use: { viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 } },
  ],
});
