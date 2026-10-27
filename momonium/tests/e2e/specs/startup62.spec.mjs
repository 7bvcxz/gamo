// Step 62: the loading screen. From the first paint -- the index page, then
// the runner -- Momonium's own screen (Momo on the sea, the wordmark, a line
// in the player's language), never Godot's bare status text; its bar moves by
// real stages (engine, game files, starting) or stays neutral; it fades into
// the island only once the island has drawn, and leaves the canvas focused
// and tappable. A failed engine says so with a Try again; reduced motion
// stills it; a cached reload shows it again; nothing is fetched from a third
// host. Not the shared fixture: these tests watch the load itself.
import { test, expect } from '@playwright/test';

async function throttle(page, mbps) {
  const s = await page.context().newCDPSession(page);
  await s.send('Network.enable');
  await s.send('Network.emulateNetworkConditions', { offline: false, latency: 80, downloadThroughput: (mbps * 1024 * 1024) / 8, uploadThroughput: 1024 * 1024 });
  return s;
}

const splash = (page) => page.evaluate(() => {
  const el = document.getElementById('momo-splash');
  if (!el) return null;
  const r = el.getBoundingClientRect();
  return { shown: getComputedStyle(el).display !== 'none' && Number(getComputedStyle(el).opacity) > 0.5, w: r.width, h: r.height,
    word: el.querySelector('.word').textContent, line: el.querySelector('.text').textContent,
    stage: window.MomoSplash ? window.MomoSplash.stage : -1, state: window.MomoSplash ? window.MomoSplash.state : '',
    bar: el.querySelector('.bar').getAttribute('aria-valuenow'), unknown: el.querySelector('.bar').classList.contains('unknown'),
    page: location.pathname + location.search };
});

test('the splash from the first paint until the island draws', async ({ page }, info) => {
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
  const hosts = new Set();
  page.on('request', (r) => hosts.add(new URL(r.url()).host));
  await throttle(page, 48);
  await page.goto('./', { waitUntil: 'commit' });
  await page.waitForSelector('#momo-splash', { timeout: 10_000 });
  let s = await splash(page);
  expect(s.shown, 'the loading screen at once').toBe(true);
  expect(s.word).toBe('momonium');
  expect(s.line.length, 'a line in words').toBeGreaterThan(3);
  await page.screenshot({ path: info.outputPath('0-first.png') });
  // While loading: stages counted by the runner; Godot's own status text hidden under it.
  const seen = new Set();
  let shotMid = false;
  for (let i = 0; i < 400; i++) {
    s = await splash(page);
    if (!s) break;
    seen.add(s.stage);
    if (!shotMid && s.stage >= 1 && s.state === 'loading') {
      await page.screenshot({ path: info.outputPath('1-loading.png') });
      shotMid = true;
      const covered = await page.evaluate(() => {
        const texts = [...document.body.querySelectorAll('div')].filter((d) => /내려받는|Loading/.test(d.textContent || '') && d.id !== 'momo-splash' && !d.closest('#momo-splash'));
        return texts.every((d) => { const r = d.getBoundingClientRect(); const top = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2); return !top || top.closest('#momo-splash'); });
      });
      expect(covered, 'no raw engine status text in sight').toBe(true);
    }
    if (s.state === 'done') break;
    await page.waitForTimeout(100);
  }
  expect([...seen].some((n) => n >= 1), `real stages were reported (${[...seen]})`).toBe(true);
  // Gone only after the island is ready, and fully gone.
  await page.waitForFunction(() => window.momonium && window.momonium.ready, null, { timeout: 90_000 });
  await page.waitForFunction(() => !document.getElementById('momo-splash'), null, { timeout: 5_000 });
  await page.waitForTimeout(300);
  await page.screenshot({ path: info.outputPath('2-island.png') });
  expect(await page.evaluate(() => document.activeElement && document.activeElement.id), 'the canvas has the focus').toBe('canvas');
  // And the island takes a real tap.
  const h = await page.evaluate(() => window.momonium.call('hud'));
  const box = await page.locator('canvas').boundingBox();
  const r = h.buttons.status;
  const x = box.x + (r[0] + r[2] / 2) * (box.width / h.window[0]);
  const y = box.y + (r[1] + r[3] / 2) * (box.height / h.window[1]);
  if (info.project.use.hasTouch) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
  await expect.poll(async () => (await page.evaluate(() => window.momonium.call('hud'))).actions.slice(-1)[0], { timeout: 3_000 }).toBe('status');
  const own = new URL(page.url()).host;
  expect([...hosts].every((host) => host === own), `no third-party requests: ${[...hosts]}`).toBe(true);
});

test('an engine that fails says so, with Try again', async ({ page }) => {
  await page.route(/engine-[0-9a-f]+\.wasm$/, (route) => route.abort());
  await page.goto('./');
  await page.waitForFunction(() => window.MomoSplash && window.MomoSplash.state === 'failed', null, { timeout: 30_000 });
  const t = await page.evaluate(() => ({ text: document.querySelector('#momo-splash .why').textContent, retry: document.querySelector('#momo-splash .retry').textContent,
    visible: getComputedStyle(document.querySelector('#momo-splash .notice')).display }));
  expect(t.visible).toBe('block');
  expect(t.text.length, `says what happened: ${t.text}`).toBeGreaterThan(10);
  expect(t.retry.length).toBeGreaterThan(2);
});

test('reduced motion: the screen stands still', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('./', { waitUntil: 'commit' });
  await page.waitForSelector('#momo-splash');
  const anim = await page.evaluate(() => ['.momo', '.ripple', '.sea', '.bar i'].map((q) => getComputedStyle(document.querySelector('#momo-splash ' + q)).animationName));
  expect(anim.every((a) => a === 'none'), anim.join(',')).toBe(true);
});

test('a cached reload shows it again and still fades into the island', async ({ page }) => {
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && !document.getElementById('momo-splash'), null, { timeout: 90_000 });
  const t0 = Date.now();
  await page.goto('./', { waitUntil: 'commit' });
  await page.waitForSelector('#momo-splash', { timeout: 10_000 });
  await page.waitForFunction(() => window.momonium && window.momonium.ready && !document.getElementById('momo-splash'), null, { timeout: 90_000 });
  expect(Date.now() - t0).toBeLessThan(60_000);
});
