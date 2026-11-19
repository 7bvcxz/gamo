// Step 45: a player comes back to a complex factory safely -- through a reload, a page
// navigation, a killed renderer, an old build's save, a broken save -- and the saves page
// (web/saves.html) exports, imports, restores and erases (two presses). Real localStorage,
// the real export of the game.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import { execSync } from 'node:child_process';
import { chromium } from '@playwright/test';
import { test, expect, INIT, wrap } from '../lib/pop.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const FIX = path.join(HERE, '..', '..', 'fixtures', 'saves');
const fixture = (name) => fs.readFileSync(path.join(FIX, name), 'utf8');
const PLAN = [['M07', 'kitchen'], ['bagger', 'packing'], ['S03', 'shop'], ['M01', 'kitchen'], ['M07', 'kitchen'], ['S05', 'shop'],
  ['M07', 'kitchen'], ['P07', 'packing'], ['M13', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'], ['S08', 'shop']];

const key = (k) => `popcorn-glory.${k}`;
const store = (page, k) => page.evaluate((n) => localStorage.getItem(n), key(k));

// Puts saves in place before the game's first load only (a reload must not put them back).
async function seed(page, keys) {
  await page.addInitScript((kv) => {
    if (sessionStorage.getItem('seeded45')) return;
    sessionStorage.setItem('seeded45', '1');
    for (const [k, v] of Object.entries(kv)) {
      if (v === null) localStorage.removeItem(k); else localStorage.setItem(k, v);
    }
  }, Object.fromEntries(Object.entries(keys).map(([k, v]) => [key(k), v])));
}

async function factory(pop) {
  await pop.open('./#factory');
  await pop.call('dev_money', 400000);
  const b = await pop.call('dev_build', { plan: PLAN, sign: 6, packer: 3 });
  expect(b.ok, 'built').toBe(true);
  await pop.call('dev_advance', 30000);
  expect((await pop.call('dev_save')).ok, 'saved').toBe(true);
  return pop.state();
}

// A loaded game plays on while the page settles (upkeep, sales): money within this of the save.
const near = (got, want, tol, what) => expect(Math.abs(got - want), `${what}: ${got} vs ${want}`).toBeLessThanOrEqual(tol);
const summary = (s) => ({ machines: s.run.machines.map((m) => `${m.id}:${m.type}@${m.floor}/${m.slot}`).join(','), money: s.run.money,
  made: s.run.stats.made_portions, sold: s.run.stats.sold });

test('a reload and a trip to the stand keep the factory, and the stand keeps its own', async ({ pop }) => {
  await seed(pop.page, { 'stand.v1': fixture('stand_0.43.0.json') });
  const a = await factory(pop);
  const text = await store(pop.page, 'factory.v1');
  expect(text, 'the save has its checksum and the rules last').toMatch(/"sum":"[0-9a-f]{64}","version":"[^"]+","rules":\{/);
  expect(JSON.parse(text).schema, 'schema 1 (old builds still read it)').toBe(1);
  await pop.page.reload();
  await pop.ready();
  let s = await pop.state();
  expect(s.save.from, 'picked up from the save').toBe('main');
  expect(summary(s).machines).toBe(summary(a).machines);
  near(s.run.money, a.run.money, 3000, 'the money as it was (no time passes while away)');
  expect(s.clock_ms - a.clock_ms, 'the clock went on from the save, not from the wall').toBeLessThan(15000);
  expect(s.run.portions_everywhere).toBe(s.run.stats.made_portions);
  // To the stand and back through the address.
  const stand0 = await store(pop.page, 'stand.v1');
  await pop.page.evaluate(() => { location.hash = '#stand'; });
  await expect.poll(async () => (await pop.state()).exp).toBe('stand');
  s = await pop.state();
  expect(s.save.from, 'the stand from its own save').toBe('main');
  expect(s.run.level, "the stand's level from its save").toBe(JSON.parse(fixture('stand_0.43.0.json')).rules.level);
  await pop.page.evaluate(() => { location.hash = '#factory'; });
  await expect.poll(async () => (await pop.state()).exp).toBe('factory');
  s = await pop.state();
  expect(summary(s).machines, 'the factory again').toBe(summary(a).machines);
  expect(JSON.parse(await store(pop.page, 'stand.v1')).rules.level, 'the factory never wrote the stand').toBe(JSON.parse(stand0).rules.level);
  for (const id of ['click', 'perfect', 'explosion']) expect(await store(pop.page, `${id}.v1`), `${id} keeps nothing`).toBeNull();
});

// Process termination: a throwaway Chromium with its own profile on disk, every one of its
// processes killed with SIGKILL (no unload, no pagehide, no last save), then a new Chromium on
// the same profile. CDP Page.crash was tried first and takes the whole Playwright context with
// it (no page can open after it), so it measured the harness, not the save.
test('a killed browser loses seconds, never goods: nothing sold twice, every machine there', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'one browser kill is enough; the save path is the same on every screen');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pop45-kill-'));
  const base = testInfo.project.use.baseURL;
  const launch = () => chromium.launchPersistentContext(dir, { baseURL: base, viewport: { width: 1280, height: 800 } });
  let ctx = await launch();
  let page = ctx.pages()[0] || await ctx.newPage();
  await page.addInitScript(INIT);
  let p1 = wrap(page, testInfo);
  const a = await factory(p1);
  await page.waitForTimeout(7000);   // real play: the save every 5 s of it
  const b = await p1.state();
  // Every process of this browser (it alone has this profile directory on its command line).
  const pids = execSync(`pgrep -f -- "--user-data-dir=${dir}" || true`).toString().split(/\s+/).filter(Boolean).map(Number);
  expect(pids.length, 'found the browser to kill').toBeGreaterThan(0);
  for (const pid of pids) { try { process.kill(pid, 'SIGKILL'); } catch (e) { /* already gone */ } }
  await ctx.close().catch(() => {});
  ctx = await launch();
  page = ctx.pages()[0] || await ctx.newPage();
  await page.addInitScript(INIT);
  // What the killed browser left on disk, read before the game opens and saves again.
  await page.goto('./saves.html');
  const leftText = await store(page, 'factory.v1');
  const left = leftText ? JSON.parse(leftText) : null;
  const p2 = wrap(page, testInfo);
  await p2.open('./#factory');
  const c = await p2.state();
  testInfo.annotations.push({ type: 'kill', description: JSON.stringify({ pids: pids.length, built_clock: a.clock_ms, before_kill_clock: b.clock_ms,
    saved_clock: left && left.active_ms, sold: [b.run.stats.sold, left && left.rules.stats.sold, c.run.stats.sold], from: c.save.from }) });
  expect(left, 'a save survived the kill').not.toBeNull();
  expect(c.save.from, 'picked up from the save').toBe('main');
  expect(summary(c).machines, 'every paid machine').toBe(summary(a).machines);
  expect(left.active_ms, 'at most a little more than one save interval lost').toBeGreaterThan(b.clock_ms - 8000);
  expect(left.active_ms).toBeLessThanOrEqual(b.clock_ms + 1500);
  expect(left.rules.stats.sold, 'no sale counted that the saved factory did not make').toBeLessThanOrEqual(b.run.stats.sold + 2);
  expect(c.run.portions_everywhere, 'every portion somewhere').toBe(c.run.stats.made_portions);
  expect(p1.errors.concat(p2.errors)).toEqual([]);
  await ctx.close();
  fs.rmSync(dir, { recursive: true, force: true });
});

test("old builds' saves open: a 0.12.2 stand and a 0.43.0 forty-four-machine factory", async ({ pop }) => {
  const stand = fixture('stand_0.12.2.json');
  const old = fixture('factory_0.43.0_forty.json');
  await seed(pop.page, { 'stand.v1': stand, 'factory.v1': old, 'factory.v1.bak': null, 'stand.v1.bak': null });
  await pop.open('./#stand');
  let s = await pop.state();
  expect(s.save.from).toBe('main');
  expect(s.run.level, 'the 0.12.2 stand at its level').toBe(9);
  near(s.run.money, JSON.parse(stand).rules.money, 2000, 'the stand\'s money');
  await pop.page.evaluate(() => { location.hash = '#factory'; });
  await expect.poll(async () => (await pop.state()).exp).toBe('factory');
  s = await pop.state();
  const want = JSON.parse(old).rules;
  expect(s.save.from).toBe('main');
  expect(s.run.machines.length, "the 0.43.0 factory's machines").toBe(44);
  near(s.run.money, want.money, 20000, 'the factory\'s money');
  expect(await store(pop.page, 'factory.v1.bak'), 'the save the player came back to is the backup').toBe(old);
  expect((await pop.call('dev_save')).ok).toBe(true);
  expect(await store(pop.page, 'factory.v1'), 'the next save is in the new envelope').toMatch(/"sum":"[0-9a-f]{64}"/);
  await pop.shot('save45_old_forty');
});

test('a broken save is set aside, the backup comes back, and the saves page shows both', async ({ pop }) => {
  const old = fixture('factory_0.43.0_forty.json');
  const broken = old.slice(0, old.length - 200);
  await seed(pop.page, { 'factory.v1': broken, 'factory.v1.bak': old, 'factory.v1.rejected': null });
  await pop.open('./#factory');
  let s = await pop.state();
  expect(s.save.from, 'picked up from the backup').toBe('backup');
  expect(s.save.rejected).toBe('not_json');
  expect(s.run.machines.length).toBe(44);
  expect(await store(pop.page, 'factory.v1.rejected'), 'set aside whole').toBe(broken);
  expect(s.rects.recover, 'the set-aside icon').toBeTruthy();
  expect(Math.min(s.rects.recover[2], s.rects.recover[3]), 'a finger-sized target').toBeGreaterThanOrEqual(24);
  // It covers nothing else a finger can press (its first place covered the shop floor's badge).
  const ov = (a, b) => a[0] < b[0] + b[2] - 0.5 && b[0] < a[0] + a[2] - 0.5 && a[1] < b[1] + b[3] - 0.5 && b[1] < a[1] + a[3] - 0.5;
  for (const [k, r] of Object.entries(s.rects)) {
    if (k === 'recover' || k === 'play' || !Array.isArray(r) || r.length !== 4 || k.startsWith('floor_')) continue;
    expect(ov(s.rects.recover, r), `the set-aside icon does not cover ${k}`).toBe(false);
  }
  await pop.shot('save45_recover_icon');
  // The saves page.
  const page = pop.page;
  await page.goto('./saves.html');
  const rows = page.locator('#slots .row');
  await expect(rows.filter({ hasText: '따로 둔 저장' })).toHaveCount(1);
  await expect(rows.filter({ hasText: '따로 둔 저장' })).toContainText('읽을 수 없음');
  await expect(rows.filter({ hasText: '백업' }).first()).toContainText('온전함');
  await expect(rows.filter({ hasText: '백업' }).first()).toContainText('기계 44대');
  await pop.shot('save45_saves_page');
  // Erase takes two presses.
  const erase = page.locator('[data-key="factory.v1"] button[data-act="erase"]');
  await erase.click();
  expect(await store(page, 'factory.v1'), 'one press erases nothing').not.toBeNull();
  await erase.click();
  await expect.poll(() => store(page, 'factory.v1')).toBeNull();
  expect(await store(page, 'factory.v1.bak'), 'nor the backup').toBeNull();
});

test('the saves page exports and imports, and the factory comes back from the file', async ({ pop }, testInfo) => {
  const a = await factory(pop);
  const page = pop.page;
  await page.goto('./saves.html');
  const [download] = await Promise.all([page.waitForEvent('download'), page.click('#export')]);
  const file = testInfo.outputPath('saves45.json');
  await download.saveAs(file);
  const bundle = JSON.parse(fs.readFileSync(file, 'utf8'));
  expect(bundle['popcorn-glory-saves']).toBe(1);
  expect(Object.keys(bundle.keys)).toContain('factory.v1');
  await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
  await page.reload();
  await page.setInputFiles('#import', file);
  await expect(page.locator('#msg')).toContainText('가져왔습니다');
  await pop.open('./#factory');
  const s = await pop.state();
  expect(s.save.from).toBe('main');
  expect(summary(s).machines, 'the imported factory').toBe(summary(a).machines);
  near(s.run.money, a.run.money, 3000, 'the imported money');
  // A file that is not a save is refused, and nothing is written.
  await page.goto('./saves.html');
  const junk = testInfo.outputPath('junk.json');
  fs.writeFileSync(junk, JSON.stringify({ game: 'popcorn-glory', exp: 'factory', schema: 1, sum: '00', rules: { money: 1 } }).replace('"rules"', '"x":0,"rules"'));
  const before = await store(page, 'factory.v1');
  await page.setInputFiles('#import', junk);
  await expect(page.locator('#msg')).toContainText('가져오지 않았습니다');
  expect(await store(page, 'factory.v1')).toBe(before);
});

test("restart takes two taps and the old factory waits in the backup", async ({ pop }) => {
  const a = await factory(pop);
  const saved = await store(pop.page, 'factory.v1');
  expect((await pop.state()).armed_restart).toBe(true);
  await pop.tap('restart');
  await pop.page.waitForTimeout(400);
  let s = await pop.state();
  expect(s.run.machines.length, 'one tap: still the factory').toBe(a.run.machines.length);
  await pop.shot('save45_restart_armed');
  await pop.tap('restart');
  await expect.poll(async () => (await pop.state()).run.machines.length, { message: 'two taps: a new factory' }).toBe(0);
  expect(await store(pop.page, 'factory.v1.bak'), 'the old factory in the backup').toBe(saved);
});
