// Milestone E2E suite for the Momonium web build.
//
// Runs against docs/ served locally -- i.e. the build ./deploy-web.sh momonium
// just produced, not the public site. Full runs happen at Steps 10, 20, 30 and
// 40 only; a new spec may be run on its own while it is being written:
//   npx playwright test specs/boot.spec.mjs
import { defineConfig } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const docs = path.resolve(here, '../../../docs');
const port = Number(process.env.MOMONIUM_E2E_PORT || 18432);

export default defineConfig({
  testDir: './specs',
  timeout: 120_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list']],
  // MOMONIUM_E2E_BASE points one spec at a deployed build instead (the
  // public acceptance check), and then no local server is started.
  use: { baseURL: process.env.MOMONIUM_E2E_BASE || `http://127.0.0.1:${port}/momonium/` },
  webServer: process.env.MOMONIUM_E2E_BASE ? undefined : {
    command: `python3 -m http.server ${port} --bind 127.0.0.1 --directory ${docs}`,
    url: `http://127.0.0.1:${port}/momonium/version.json`,
    reuseExistingServer: false,
    timeout: 20_000,
  },
  projects: [
    { name: 'phone', use: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true } },
    { name: 'desktop', use: { viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 } },
  ],
});
