// Step 09: a stall in the middle of B's hold must not shorten the hold the game judges.
// A blind player (round 3b) held 1.98 s by the clock and the game judged 1.16 s ("early"):
// the active clock counted at most 0.25 s for one frame, so a ~1 s hitch of the browser
// vanished from the heat while the finger stayed down -- "it felt like being punished for
// upgrading". Here the page's main thread is blocked for 0.8 s during a hold (the game runs on
// it: single-threaded web build), and the held time the game logs must be the finger's time.
import { test, expect } from '../lib/pop.mjs';

test('B: a 0.8 s stall during a hold still counts toward the heat', async ({ pop }, testInfo) => {
  await pop.open('./#perfect');
  const s = await pop.state();
  const r = s.rects.play;
  const box = await pop.canvas.boundingBox();
  const k = box.width / s.window[0];
  const x = box.x + (r[0] + r[2] / 2) * k;
  const y = box.y + (r[1] + r[3] / 2) * k;
  const touch = testInfo.project.use.hasTouch;
  const cdp = touch ? await pop.cdp() : null;
  const down = () => (touch ? cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] }) : pop.page.mouse.move(x, y).then(() => pop.page.mouse.down()));
  const up = () => (touch ? cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }) : pop.page.mouse.up());

  await down();
  const t0 = Date.now();
  await pop.page.waitForTimeout(250);
  // The hitch: the main thread busy for 0.8 s (no frame can run).
  await pop.page.evaluate(() => { const t = performance.now(); while (performance.now() - t < 800) { /* busy */ } });
  await pop.page.waitForTimeout(Math.max(0, 1550 - (Date.now() - t0)));
  const wall = Date.now() - t0;
  await up();

  await expect.poll(async () => (await pop.call('log')).filter((l) => l.type === 'outcome').length).toBeGreaterThanOrEqual(1);
  const out = (await pop.call('log')).filter((l) => l.type === 'outcome').at(-1).data;
  testInfo.annotations.push({ type: 'hold', description: `finger ${wall} ms, game judged ${out.held_ms} ms (${out.kind})` });
  // The game may judge a little less (input reaches it on its next frame), never the stall's worth less.
  expect(out.held_ms, `finger held ${wall} ms`).toBeGreaterThan(wall - 250);
  expect(pop.errors).toEqual([]);
});
