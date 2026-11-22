#!/usr/bin/env node
// Step 47: the prepared save for the established-factory blind session. A newcomer cannot build
// forty machines in a session, so this one starts from a save that says so (disclosed in the
// report). Made through the published build's own dev bridge (?dev=1) in a fresh profile: a fresh
// factory, the 44-machine plan of perf46 (sign 8, packer 3, $3,000 left), ten model minutes so
// every floor has goods, customers and some wear, then the game's own save -- the same text a
// player's browser would hold (popcorn-glory.factory.v1).
//
//   node prepare_factory.mjs --url 'https://7bvcxz.github.io/gamo/popcorn-glory/' --out /abs/factory44.json
//
// Writes the save text to --out and a description next to it (<out>.about.json).
import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(path.join(here, '../../tests/e2e/package.json'));
const { chromium } = require('playwright');

const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf(`--${n}`); return i >= 0 ? argv[i + 1] : d; };
const base = opt('url', 'https://7bvcxz.github.io/gamo/popcorn-glory/');
const out = path.resolve(opt('out', 'factory44.json'));
const spec = fs.readFileSync(path.join(here, '../../tests/e2e/specs/perf46.spec.mjs'), 'utf8');
const PLAN = JSON.parse(spec.match(/const PLAN = (\[[\s\S]*?\]\]);/)[1].replace(/'/g, '"'));

const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'popcorn-prep-'));
const context = await chromium.launchPersistentContext(profile, { headless: true, viewport: { width: 400, height: 860 }, deviceScaleFactor: 1.5, isMobile: true, hasTouch: true });
const page = context.pages()[0] || (await context.newPage());
await page.goto(new URL('?dev=1#factory', base).href, { waitUntil: 'domcontentloaded', timeout: 120_000 });
await page.waitForFunction(() => window.popcorn && window.popcorn.ready, null, { timeout: 150_000 });
const call = (n, a) => page.evaluate(([x, y]) => window.popcorn.call(x, y), [n, a]);
await call('dev_restart');
const built = await call('dev_build', { plan: PLAN, sign: 8, packer: 3 });
for (let i = 0; i < 120; i++) await call('dev_advance', 5000);   // ten model minutes
await call('dev_save');
const st = await page.evaluate(() => window.popcorn.state());
const text = await page.evaluate(() => localStorage.getItem('popcorn-glory.factory.v1'));
fs.writeFileSync(out, text);
const about = { made: new Date().toISOString(), from: base, version: st.version, key: 'popcorn-glory.factory.v1', bytes: text.length,
  plan_rows: PLAN.length, built, machines: st.run.machines.length, money: st.run.money, level: st.run.level, sign_tier: st.run.sign_tier,
  packer_tier: st.run.packer_tier, sold: st.run.stats?.sold, active_ms: st.clock_ms,
  how: 'dev_restart; dev_build(perf46 PLAN, sign 8, packer 3) leaves $3,000; dev_advance 120 x 5 s; dev_save' };
fs.writeFileSync(out + '.about.json', JSON.stringify(about, null, 2));
await context.close();
fs.rmSync(profile, { recursive: true, force: true });
console.log(JSON.stringify(about));
