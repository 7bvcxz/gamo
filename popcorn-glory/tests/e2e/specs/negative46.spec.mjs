// Step 46: pathological cases in the real browser -- the game pack failing to download, a
// jittery finger on the kettle, a reload in the middle of a pack, a hold across a hidden tab.
// (Already covered elsewhere and run with the full suite: a stalled render inside the gold
// window -- stall09; overlaps on seven screens -- ui44, responsive07; split ticks and caps --
// unit/test_negative46; a contest paid once -- contests38 and unit/test_coverage46.)
import { test, expect } from '../lib/pop.mjs';

const PLAN = [['M07', 'kitchen'], ['bagger', 'packing'], ['S03', 'shop'], ['M01', 'kitchen'], ['M07', 'kitchen'], ['S05', 'shop'],
  ['M07', 'kitchen'], ['P07', 'packing'], ['M13', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'], ['S08', 'shop']];

test('a game pack that fails to download says so -- no endless blank page', async ({ pop }, testInfo) => {
  const page = pop.page;
  let aborted = 0;
  await page.route('**/*.pck', (route) => { aborted++; return route.abort('failed'); });
  await page.goto('./#factory');
  // The runner's own notice (displayFailureNotice) -- text a person can read -- within 60 s.
  await expect(page.locator('#status-notice')).toBeVisible({ timeout: 60_000 });
  const text = (await page.locator('#status-notice').innerText()).trim();
  testInfo.annotations.push({ type: 'pack_failure', description: JSON.stringify({ aborted, notice: text.slice(0, 160) }) });
  expect(aborted, 'the pack was asked for').toBeGreaterThan(0);
  expect(text.length, 'the notice says something').toBeGreaterThan(5);
  await pop.shot('negative46_pack_failed');
  // The failure is logged to the console on purpose (the runner's console.error); nothing else.
  pop.errors.length = 0;
});

test('a jittery finger on the kettle: one press a press, nothing stuck, nothing burnt by the jitter', async ({ pop }, testInfo) => {
  await pop.open('./#factory');
  let s = await pop.state();
  const r = s.rects.ring;
  const box = await pop.canvas.boundingBox();
  const k = box.width / s.window[0];
  const cx = box.x + (r[0] + r[2] / 2) * k;
  const cy = box.y + (r[1] + r[3] / 2) * k;
  const touch = !!testInfo.project.use.hasTouch;
  const cdp = touch ? await pop.cdp() : null;
  const presses0 = s.run.presses;
  let taps = 0;
  for (let i = 0; i < 24; i++) {
    // A finger that lands, trembles 2-4 px for 30-90 ms and lifts -- twenty-four times, fast.
    const dx = (i % 5) - 2;
    if (touch) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: cx, y: cy }] });
      for (let j = 0; j < 3; j++) await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: cx + dx + j, y: cy - j }] });
      await pop.page.waitForTimeout(30 + (i % 4) * 20);
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    } else {
      await pop.page.mouse.move(cx, cy);
      await pop.page.mouse.down();
      for (let j = 0; j < 3; j++) await pop.page.mouse.move(cx + dx + j, cy - j);
      await pop.page.waitForTimeout(30 + (i % 4) * 20);
      await pop.page.mouse.up();
    }
    taps++;
    await pop.page.waitForTimeout(25);
  }
  await pop.page.waitForTimeout(1500);
  s = await pop.state();
  const presses = s.run.presses - presses0;
  testInfo.annotations.push({ type: 'jitter', description: JSON.stringify({ taps, presses, heating: s.run.heating, outcomes: s.run.outcomes }) });
  expect(presses, 'never more presses than fingers').toBeLessThanOrEqual(taps);
  expect(s.run.heating, 'the kettle is not left heating after the finger lifted').toBe(false);
  expect(s.run.outcomes.burnt || 0, 'no batch burnt by a stuck press').toBe(0);
  expect(s.run.portions_everywhere).toBe(s.run.stats.made_portions);
  // And the kettle still answers a calm, real hold into the gold.
  if (!s.run.heating && Object.keys(s.run.glass).length === 0 && s.run.cooldown_left <= 0) {
    const lots = s.run.stats.lots;
    await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
    await expect.poll(async () => (await pop.state()).run.stats.lots, { message: 'a calm hold still pops' }).toBeGreaterThan(lots);
  }
});

test('a reload in the middle of a pack: every portion and every coin where it was', async ({ pop }, testInfo) => {
  await pop.open('./#factory');
  await pop.call('dev_money', 400000);
  expect((await pop.call('dev_build', { plan: PLAN, sign: 6, packer: 3 })).ok).toBe(true);
  // Wait for the worst moment: lots on the lift, portions in the bin, a serve on its way to a
  // customer (with baggers the station's own list stays empty), then reload at once.
  let s;
  const t0 = Date.now();
  do {
    await pop.call('dev_advance', 250);
    s = await pop.state();
  } while (!((s.run.lift > 0 || s.run.bin_portions > 0) && s.run.serves.length > 0) && Date.now() - t0 < 90_000);
  expect((s.run.lift > 0 || s.run.bin_portions > 0) && s.run.serves.length > 0, 'goods between floors and a serve on its way').toBe(true);
  await pop.page.reload();   // (the hide/unload path saves this moment)
  await pop.ready();
  const r = await pop.state();
  testInfo.annotations.push({ type: 'mid_pack', description: JSON.stringify({ before: { sold: s.run.stats.sold, money: s.run.money, made: s.run.stats.made_portions, lift: s.run.lift, serves: s.run.serves.length }, after: { sold: r.run.stats.sold, money: r.run.money, made: r.run.stats.made_portions, from: r.save.from } }) });
  expect(r.save.from).toBe('main');
  expect(r.run.machines.length).toBe(s.run.machines.length);
  expect(r.run.portions_everywhere, 'every portion somewhere after the reload').toBe(r.run.stats.made_portions);
  expect(Math.abs(r.run.stats.sold - s.run.stats.sold), 'no sale lost or counted twice (a frame or two of play either side)').toBeLessThanOrEqual(3);
  // A minute more: the restored factory goes on, conserved.
  await pop.call('dev_advance', 60000);
  const g = await pop.state();
  expect(g.run.stats.sold).toBeGreaterThan(r.run.stats.sold);
  expect(g.run.portions_everywhere).toBe(g.run.stats.made_portions);
});

test('a hold across a hidden tab ends the press: nothing heats while nobody looks', async ({ pop }) => {
  await pop.open('./#factory');
  let s = await pop.state();
  const r = s.rects.ring;
  const box = await pop.canvas.boundingBox();
  const k = box.width / s.window[0];
  const x = box.x + (r[0] + r[2] / 2) * k;
  const y = box.y + (r[1] + r[3] / 2) * k;
  await pop.page.mouse.move(x, y);
  await pop.page.mouse.down();
  await expect.poll(async () => (await pop.state()).run.heating, { message: 'the press heats' }).toBe(true);
  await pop.tab(true);
  await pop.page.waitForTimeout(4000);
  await pop.tab(false);
  await pop.page.mouse.up();
  await pop.page.waitForTimeout(800);
  s = await pop.state();
  expect(s.run.heating, 'not heating after the tab came back').toBe(false);
  expect(s.run.outcomes.burnt || 0, 'the hidden seconds did not burn the batch').toBe(0);
});
