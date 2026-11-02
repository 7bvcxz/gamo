// Browser tests for the Fun Lab's web build (docs/momonium-experiments/).
//
//   momonium/experiments/tools/e2e.sh [specs/funlab86.spec.mjs ...]
//
// Served locally from docs/ (the build tools/deploy.sh just wrote), or, with
// FUNLAB_E2E_BASE set, against a deployed build (no local server). Uses the
// game's Playwright install (tools/e2e.sh links its node_modules here).
import { defineConfig } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const docs = path.resolve(here, '../../../../docs');
const port = Number(process.env.FUNLAB_E2E_PORT || 18486);

export default defineConfig({
  testDir: './specs',
  timeout: 180_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list']],
  use: { baseURL: process.env.FUNLAB_E2E_BASE || `http://127.0.0.1:${port}/momonium-experiments/`, acceptDownloads: true },
  webServer: process.env.FUNLAB_E2E_BASE ? undefined : {
    command: `python3 -m http.server ${port} --bind 127.0.0.1 --directory ${docs}`,
    url: `http://127.0.0.1:${port}/momonium-experiments/version.json`,
    reuseExistingServer: false,
    timeout: 20_000,
  },
  projects: [
    { name: 'phone', use: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true } },
    { name: 'p720', use: { viewport: { width: 720, height: 1280 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true } },
    { name: 'desktop', use: { viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 } },
  ],
});
