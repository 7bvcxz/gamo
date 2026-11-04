// Step 12: the release matrix's browser checks on the real build. Save and resume across a
// page reload (this page's localStorage, popcorn-glory.* only), a hidden tab writes the save,
// the stand's restart takes two taps and clears it, the game keeps playing offline once loaded,
// the system's 'reduce motion' is followed, and (desktop) the first load on a slow connection is
// measured and recorded. Device and browser are recorded with every run.
import { test, expect } from '../lib/pop.mjs';

const KEY = 'popcorn-glory.stand.v1';
const saved = (pop) => pop.page.evaluate((k) => { const v = localStorage.getItem(k); return v ? JSON.parse(v) : null; }, KEY);

test('stand: saved across a reload, written when hidden, two taps to restart', async ({ pop, browserName }, testInfo) => {
  test.setTimeout(150_000);
  await pop.open('./#stand');
  await pop.page.evaluate((k) => localStorage.removeItem(k), KEY);
  await pop.call('dev_level', 6);
  await pop.call('dev_money', 20000);
  await expect.poll(async () => !!(await pop.state()).rects.auto).toBe(true);
  await pop.tap('auto');
  await expect.poll(async () => (await pop.state()).run.motor).toBe(true);
  await pop.tap('recipe_caramel');
  await expect.poll(async () => (await pop.state()).run.recipe).toBe('caramel');
  const before = (await pop.state()).run;
  await expect.poll(async () => (await saved(pop))?.rules?.recipe, { message: 'saved after the recipe' }).toBe('caramel');
  // A reload: the stand comes back.
  await pop.page.reload();
  await pop.ready();
  await expect.poll(async () => (await pop.state()).exp).toBe('stand');
  const after = (await pop.state()).run;
  expect(after.level, 'level after a reload').toBe(before.level);
  expect(after.recipe, 'recipe after a reload').toBe('caramel');
  expect(after.motor, 'motor after a reload').toBe(true);
  expect(after.money, 'money after a reload').toBe(before.money);
  const log = await pop.call('log');
  expect(log.some((l) => l.type === 'restored'), 'the log says restored').toBe(true);
  expect((await pop.call('dev_save')).ok, 'the web store reports a write as done').toBe(true);
  // A hidden tab writes the save first (a phone may kill it).
  await pop.call('dev_money', 777);
  const money = (await pop.state()).run.money;
  await pop.tab(true);
  await expect.poll(async () => (await saved(pop))?.rules?.money, { message: 'written when hidden' }).toBe(money);
  await pop.tab(false);
  // Restart: one tap arms (nothing lost), the second restarts and clears the save.
  await pop.tap('restart');
  await pop.page.waitForTimeout(300);
  expect((await pop.state()).run.level, 'one tap does not restart the stand').toBe(before.level);
  await pop.tap('restart');
  await expect.poll(async () => (await pop.state()).run.level).toBe(0);
  await expect.poll(async () => await saved(pop), { message: 'the save is gone' }).toBe(null);
  const keys = await pop.page.evaluate(() => Object.keys(localStorage));
  expect(keys.filter((k) => !k.startsWith('popcorn-glory.')), 'no storage outside popcorn-glory.*').toEqual([]);
  testInfo.annotations.push({ type: 'device', description: `${testInfo.project.name} ${browserName} ${await pop.page.evaluate(() => navigator.userAgent)}` });
  expect(pop.errors).toEqual([]);
});

test('plays on offline once loaded; follows reduce motion', async ({ pop, browser }, testInfo) => {
  test.skip(testInfo.project.name !== 'p720', 'one project');
  await pop.open('./#stand');
  await pop.page.context().setOffline(true);
  await pop.holdGold();
  await expect.poll(async () => (await pop.state()).run.outcomes.perfect, { message: 'a perfect batch offline' }).toBe(1);
  await pop.page.context().setOffline(false);
  // Reduce motion from the system setting.
  const ctx = await browser.newContext({ reducedMotion: 'reduce', viewport: { width: 720, height: 1280 } });
  const page = await ctx.newPage();
  await page.addInitScript(() => { window.POPCORN_E2E = true; });
  await page.goto(new URL('./#stand', testInfo.project.use.baseURL || pop.page.url()).href);
  await page.waitForFunction(() => window.popcorn && window.popcorn.ready && typeof window.popcorn.state === 'function', null, { timeout: 90_000 });
  await expect.poll(async () => (await page.evaluate(() => window.popcorn.state())).reduced_motion, { message: 'system reduce motion followed' }).toBe(true);
  await ctx.close();
  expect(pop.errors).toEqual([]);
});

test('first load on a slow connection (recorded)', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.use.hasTouch, 'desktop measures');
  // Only against the published build: the local test server sends the 39 MB engine
  // uncompressed (Pages gzips it), so a local number would measure the server.
  test.skip(!process.env.POPCORN_E2E_BASE, 'measured on the published URL');
  test.setTimeout(400_000);
  const cdp = await pop.page.context().newCDPSession(pop.page);
  await cdp.send('Network.enable');
  await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
  // Chrome's 'Fast 3G' profile: 1.44 Mbit/s down, 675 kbit/s up, 562 ms round trip.
  await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 562, downloadThroughput: 1.44e6 / 8, uploadThroughput: 675e3 / 8 });
  const t0 = Date.now();
  await pop.page.goto('./#stand');
  await pop.page.waitForFunction(() => window.popcorn && window.popcorn.ready && typeof window.popcorn.state === 'function', null, { timeout: 300_000 });
  const ms = Date.now() - t0;
  testInfo.annotations.push({ type: 'slow_load', description: `Fast 3G emulation: first drawn frame after ${ms} ms` });
  expect(ms, 'opens on Fast 3G within 5 minutes').toBeLessThan(300_000);
});

test('the about page: links to the game, privacy and licences, nothing loaded from elsewhere', async ({ page, baseURL }, testInfo) => {
  test.skip(testInfo.project.name !== 'p720', 'one project');
  const foreign = [];
  page.on('request', (r) => { if (!r.url().startsWith(new URL(baseURL).origin)) foreign.push(r.url()); });
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.goto('about.html');
  await expect(page.locator('a[href="./#stand"]')).toHaveCount(1);
  await expect(page.locator('body')).toContainText('popcorn-glory.stand.v1');
  await expect(page.locator('pre')).toContainText('Permission is hereby granted');
  await expect(page.locator('#ver'), 'the build version from version.json').toContainText(/\d+\.\d+\.\d+/);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  expect(overflow, 'no sideways scroll').toBeLessThanOrEqual(0);
  expect(foreign).toEqual([]);
  expect(errors).toEqual([]);
});
