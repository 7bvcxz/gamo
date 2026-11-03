// Browser tests for Windup's web build (docs/windup/).
//
//   windup/tools/e2e.sh [specs/boot02.spec.mjs ...] [--project desktop]
//
// Served locally from docs/ (the build deploy-web.sh just wrote), or, with
// WINDUP_E2E_BASE set, against a deployed build (no local server).
import { defineConfig } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const docs = path.resolve(here, '../../../docs');
const port = Number(process.env.WINDUP_E2E_PORT || 18494);

export default defineConfig({
  testDir: './specs',
  timeout: 240_000,
  expect: { timeout: 20_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list']],
  use: { baseURL: process.env.WINDUP_E2E_BASE || `http://127.0.0.1:${port}/windup/`, screenshot: 'only-on-failure' },
  webServer: process.env.WINDUP_E2E_BASE ? undefined : {
    command: `python3 -m http.server ${port} --bind 127.0.0.1 --directory ${docs}`,
    url: `http://127.0.0.1:${port}/windup/version.json`,
    reuseExistingServer: false,
    timeout: 20_000,
  },
  projects: [
    { name: 'desktop', use: { viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 } },
    { name: 'phone', use: { viewport: { width: 844, height: 390 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true } },
  ],
});
