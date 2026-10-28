// Step 74: the loading screen tells the truth. On a throttled first load the
// percentage comes from the loader's real bytes, phase by phase (the engine,
// then the island), never goes back within a phase and never says 100% while
// the game is still busy; when the island has drawn, a small note says how
// long it took -- the same time the test measured -- the splash is gone and
// the game takes taps at once. A cached reload is faster and says so. A
// failed engine download says it failed and offers to try again. The
// splash's own rules (no size, bytes going back, the next phase) are checked
// on its markup alone.
import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const SHELL = readFileSync(path.resolve(here, '../../../web/shell.html'), 'utf8');

const splashState = (page) => page.evaluate(() => (window.MomoSplash ? {
  state: window.MomoSplash.state, stage: window.MomoSplash.stage, label: window.MomoSplash.label, percent: window.MomoSplash.percent,
} : null));

// Loads the game (with the bridge on) and follows it to ready: the splash's
// own record, and the test's own clock from the navigation to ready.
async function load(page, info, name) {
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
  const t0 = Date.now();
  await page.goto('./');
  const shots = [];
  let ready = false;
  while (!ready && Date.now() - t0 < 120000) {
    const s = await splashState(page).catch(() => null);
    if (s && s.state === 'loading' && shots.length < 6 && (s.percent >= 0 || shots.length === 0)) {
      const key = s.label.replace(/\d+%/, '%');
      if (!shots.includes(key)) {
        shots.push(key);
        await page.screenshot({ path: info.outputPath(`${name}-${shots.length}.png`) });
      }
    }
    ready = await page.evaluate(() => Boolean(window.momonium && window.momonium.ready)).catch(() => false);
    if (!ready) await page.waitForTimeout(120);
  }
  const measured = Date.now() - t0;
  expect(ready, 'the game became ready').toBe(true);
  await page.waitForFunction(() => window.MomoSplash && window.MomoSplash.timings.total_ms > 0, null, { timeout: 15000 });
  await page.screenshot({ path: info.outputPath(`${name}-loaded.png`) });
  const out = await page.evaluate(() => ({ history: window.MomoSplash.history, timings: window.MomoSplash.timings, note: window.MomoSplash.note }));
  return { ...out, measured };
}

test('a throttled first load: real percentages, then how long it took', async ({ page, context }, info) => {
  test.setTimeout(240000);
  const cdp = await context.newCDPSession(page);
  await cdp.send('Network.enable');
  await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
  await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 60, downloadThroughput: 40 * 1024 * 1024 / 8, uploadThroughput: 4 * 1024 * 1024 / 8 });
  const r = await load(page, info, 'throttled');
  console.log('TIMINGS', JSON.stringify(r.timings), 'NOTE', r.note, 'MEASURED', r.measured);
  console.log('HISTORY', JSON.stringify(r.history));
  const numbered = r.history.filter(([, , p]) => p >= 0);
  expect(numbered.length, 'percentages were shown').toBeGreaterThan(5);
  expect(r.history.some(([, , p]) => p === 100), 'never 100% while busy').toBe(false);
  // Per phase (by its label's wording), the number never goes back.
  const byPhase = {};
  for (const [, label, p] of numbered) {
    const phase = label.replace(/\d+%/, '');
    if (byPhase[phase] !== undefined) expect(p, `${label} after ${byPhase[phase]}%`).toBeGreaterThanOrEqual(byPhase[phase]);
    byPhase[phase] = p;
  }
  expect(Object.keys(byPhase).some((k) => k.includes('engine')), 'the engine download counted').toBe(true);
  expect(Object.keys(byPhase).some((k) => k.includes('island')), 'and the island download').toBe(true);
  expect(r.history.some(([, label, p]) => p < 0 && label.startsWith('Preparing')), 'downloaded but busy: said so, no number').toBe(true);
  // The phases the runner reported, with their download times.
  expect(r.timings.phases.map((p) => p.phase)).toEqual(['engine', 'island', 'start']);
  expect(r.timings.phases[0].download_ms, 'the engine took real time to arrive').toBeGreaterThan(500);
  // How long it took: what the note says is what the test measured.
  expect(r.timings.from_first_page, 'timed from the first page').toBe(true);
  const said = Number(/([\d.]+)/.exec(r.note)[1]) * 1000;
  expect(r.note).toMatch(/^Loaded in \d+\.\d s$/);
  expect(Math.abs(said - r.timings.total_ms), 'the note says the measured total').toBeLessThan(60);
  expect(Math.abs(r.timings.total_ms - r.measured), `${r.timings.total_ms} ms against the test's ${r.measured} ms`).toBeLessThan(2500);
  // The splash is gone and the game takes a tap at once, under the note.
  await page.waitForFunction(() => !document.getElementById('momo-splash'), null, { timeout: 5000 });
  expect(await page.evaluate(() => Boolean(document.getElementById('momo-loaded'))), 'the note is up').toBe(true);
  const hud = await page.evaluate(() => window.momonium.call('hud'));
  const box = await page.locator('canvas').boundingBox();
  const b = hud.buttons.research;
  const x = box.x + (b[0] + b[2] / 2) * (box.width / hud.window[0]);
  const y = box.y + (b[1] + b[3] / 2) * (box.height / hud.window[1]);
  if (info.project.use.hasTouch) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
  await page.waitForTimeout(400);
  expect((await page.evaluate(() => window.momonium.call('research'))).open, 'a tap reaches the game').toBe(true);
  await page.waitForTimeout(2600);
  expect(await page.evaluate(() => Boolean(document.getElementById('momo-loaded'))), 'and the note has gone by itself').toBe(false);

  // A reload from the cache: quicker, and said truthfully.
  await cdp.send('Network.setCacheDisabled', { cacheDisabled: false });
  await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
  const again = await context.newPage();
  const r2 = await load(again, info, 'reload');
  console.log('RELOAD', JSON.stringify(r2.timings), r2.note, r2.measured);
  expect(r2.timings.total_ms, 'a reload is quicker').toBeLessThan(r.timings.total_ms);
  expect(Math.abs(r2.timings.total_ms - r2.measured)).toBeLessThan(2500);
  expect(r2.note).toMatch(/^Loaded in \d+\.\d s$/);
});

test('a failed engine download says so and offers to try again', async ({ page }) => {
  await page.route(/engine-[0-9a-f]+\.wasm/, (route) => route.abort());
  await page.goto('./');
  await page.waitForFunction(() => window.MomoSplash && window.MomoSplash.state === 'failed', null, { timeout: 60000 });
  const s = await page.evaluate(() => ({
    failed: document.getElementById('momo-splash').classList.contains('failed'),
    retry: getComputedStyle(document.querySelector('#momo-splash .retry')).display !== 'none',
    bar: getComputedStyle(document.querySelector('#momo-splash .bar')).display,
    why: document.querySelector('#momo-splash .why').textContent,
  }));
  expect(s.failed).toBe(true);
  expect(s.retry, 'a button to try again').toBe(true);
  expect(s.bar, 'no bar left turning').toBe('none');
  expect(s.why).toContain('could not open');
});

test("the splash's own rules: no size, bytes going back, the next phase", async ({ page }) => {
  const markup = /<!--splash:begin-->([\s\S]*?)<!--splash:end-->/.exec(SHELL)[1];
  const body = /<!--splash-markup:begin-->([\s\S]*?)<!--splash-markup:end-->/.exec(SHELL)[1];
  await page.setContent(`<!doctype html><html><head>${markup}</head><body>${body}</body></html>`);
  const at = (fn) => page.evaluate(fn);
  expect(await at(() => [window.MomoSplash.label, window.MomoSplash.percent])).toEqual(['Getting the island ready', -1]);
  await at(() => { window.MomoSplash.step(1); window.MomoSplash.progress(1000, 0); });
  expect(await at(() => [window.MomoSplash.label, window.MomoSplash.percent]), 'no size: the phase, no number').toEqual(['Preparing the engine', -1]);
  await at(() => window.MomoSplash.progress(25, 100));
  expect(await at(() => [window.MomoSplash.label, window.MomoSplash.percent])).toEqual(['Loading the engine 25%', 25]);
  await at(() => window.MomoSplash.progress(10, 100));
  expect(await at(() => window.MomoSplash.percent), 'never back within a phase').toBe(25);
  await at(() => window.MomoSplash.progress(99.9, 100));
  expect(await at(() => window.MomoSplash.percent), 'never 100 before done').toBe(99);
  await at(() => window.MomoSplash.progress(100, 100));
  expect(await at(() => [window.MomoSplash.label, window.MomoSplash.percent]), 'done downloading, busy: no number').toEqual(['Preparing the engine', -1]);
  await at(() => { window.MomoSplash.step(2); window.MomoSplash.progress(150, 300); });
  expect(await at(() => [window.MomoSplash.label, window.MomoSplash.percent]), "the island's own bytes: 50 of 200").toEqual(['Loading the island 25%', 25]);
  await at(() => window.MomoSplash.step(3));
  expect(await at(() => [window.MomoSplash.label, window.MomoSplash.percent])).toEqual(['Waking the Momo', -1]);
  await at(() => window.MomoSplash.progress(300, 300));
  expect(await at(() => window.MomoSplash.label), 'starting: no download number').toBe('Waking the Momo');
  const phases = await at(() => window.MomoSplash.timings.phases.map((p) => p.phase));
  expect(phases).toEqual(['engine', 'island', 'start']);
});
