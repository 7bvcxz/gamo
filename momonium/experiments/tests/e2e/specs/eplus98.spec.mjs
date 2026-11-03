// Step 98: E+'s thirty minutes in the real web build, time-stepped (a
// person's thirty minutes are the owner's): buying Improve Line whenever it
// can pay for 1,800 s of play. No stall, no negative coins, no item delivered
// twice; the eras, the buildings, six lanes and the branch arrive; output
// keeps rising. The next change shows where it will be (a dashed lane); the
// grand alternative buys a bundle; at the last era a phone still reads the
// goods and draws no more than E at its thirty minutes; the tracks page
// shows the thirty-minute table. FUNLAB_SHOTS keeps
// pictures at 10, 20 and 30 minutes.
import { test, expect } from '../lib/lab.mjs';

const fps = (page, ms) => page.evaluate((d) => new Promise((resolve) => {
  let n = 0;
  const t0 = performance.now();
  const tick = () => { n++; if (performance.now() - t0 < d) requestAnimationFrame(tick); else resolve(n / ((performance.now() - t0) / 1000)); };
  requestAnimationFrame(tick);
}), ms);

async function go(lab, url, id) {
  await lab.open(url);
  await expect.poll(async () => (await lab.state()).route, { timeout: 15_000 }).toBe(id);
}

test('thirty minutes of E+ in the web build, time-stepped: it keeps growing', async ({ lab }, info) => {
  test.skip(info.project.name === 'phone', 'p720 and desktop');
  test.setTimeout(900_000);
  await go(lab, './#tycoon-plus', 'tycoon-plus');
  await lab.call('dev_time_scale', 0);
  await lab.call('dev_restart');
  let s;
  let lastLevel = 0;
  const rate = {};
  for (let t = 0; t < 1800; t += 10) {
    s = (await lab.call('dev_advance', 10)).state;
    for (let i = 0; i < 4 && s.host.action.affordable; i++) {
      await lab.call('dev_action');
      s = await lab.state();
    }
    const e = s.host.experiment;
    expect(e.coins, `coins never negative (t ${t})`).toBeGreaterThanOrEqual(0);
    expect(e.level, `the line only grows (t ${t})`).toBeGreaterThanOrEqual(lastLevel);
    lastLevel = e.level;
    if ([300, 900, 1790].includes(t)) rate[t] = e.deliveries_per_min;
    if (t === 600 || t === 1200) await lab.shot(`eplus98_${t / 60}min`);
  }
  const e = s.host.experiment;
  const sum = s.host.session;
  console.log(`eplus98 ${info.project.name}: 30 min time-stepped: Lv${e.level} ${e.name}, ${e.lanes} lanes, ${e.decor.length} buildings, eras ${e.eras.join(' / ')}, ${e.delivered} delivered, deliveries a minute ${rate[300]} -> ${rate[900]} -> ${rate[1790]}`);
  expect(e.unique_deliveries, 'no item delivered twice').toBe(true);
  expect(e.level, 'past the last era').toBeGreaterThanOrEqual(30);
  expect(e.eras.length, 'four eras').toBe(4);
  expect(e.decor.length, 'five buildings').toBe(5);
  expect(e.lanes).toBe(6);
  expect(e.branch, 'two crates').toBe(true);
  expect(rate[900], 'more at 15 min than at 5').toBeGreaterThan(rate[300]);
  expect(rate[1790], 'more at 30 than at 15').toBeGreaterThan(rate[900]);
  for (const k of ['at_3min', 'at_15min', 'at_30min']) expect(sum[k], `${k} recorded`).not.toBeNull();
  const ups = sum.upgrades.map((u) => u.t_s);
  for (let w = 0; w < 1800; w += 180) expect(ups.some((x) => x > w && x <= w + 180), `an upgrade between ${w} and ${w + 180} s`).toBe(true);
  await lab.shot('eplus98_30min');
});

test('the next change shows where it will be; the grand alternative buys a bundle', async ({ lab }, info) => {
  test.skip(info.project.name === 'p720', 'phone and desktop');
  await go(lab, './#tycoon-plus', 'tycoon-plus');
  await lab.call('dev_level', 11);
  await lab.page.waitForTimeout(1500);
  let e = (await lab.state()).host.experiment;
  expect(e.next_show, 'the next level is a lane').toBe('lane');
  expect(e.ghost, 'shown as a dashed lane').toBe('lane');
  await lab.shot('eplus98_ghost_lane');
  await lab.call('dev_level', 17);
  await lab.page.waitForTimeout(1500);
  e = (await lab.state()).host.experiment;
  expect(e.ghost, 'the wind turbine shows where it will stand').toBe('decor');
  await lab.shot('eplus98_ghost_decor');
  await go(lab, './?dev=1&alt=grand#tycoon', 'tycoon');
  await go(lab, './?dev=1&alt=grand#tycoon-plus', 'tycoon-plus');
  let s = await lab.state();
  expect(s.host.experiment.target, 'the first press buys up to level 3').toBe(3);
  await lab.call('dev_time_scale', 0);
  await lab.call('dev_coins', 72);
  await lab.call('dev_action');
  s = await lab.state();
  expect(s.host.experiment.level, 'three levels at once').toBe(3);
  expect(s.host.session.variant).toBe('grand');
});

test('the last era on a phone: legible, and no heavier to draw than E at its thirty minutes', async ({ lab }, info) => {
  test.skip(info.project.name === 'p720', 'phone portrait and desktop');
  test.setTimeout(240_000);
  // E at its thirty-minute level (Lv22, tools/e_runs.gd) against E+ at its
  // last era (Lv30, six lanes), the same way on the same page: jump there,
  // let the jump's own celebrations fade (four eras' worth of rings and
  // names), then sample. Render objects are the steady load measure; frame
  // rate under this machine's load is noisy, so it is a median of three and
  // only a guard against collapse.
  const measure = async (id, lv) => {
    await go(lab, `./#${id}`, id);
    await lab.call('dev_level', lv);
    await lab.call('dev_advance', 30);
    await lab.page.waitForTimeout(4000);
    let most = 0;
    for (let i = 0; i < 6; i++) {
      await lab.page.waitForTimeout(300);
      most = Math.max(most, (await lab.call('dev_render_info')).objects);
    }
    const f = [await fps(lab.page, 1500), await fps(lab.page, 1500), await fps(lab.page, 1500)].sort((x, y) => x - y)[1];
    return { objects: most, fps: f, e: (await lab.state()).host.experiment };
  };
  const base = await measure('tycoon', 22);
  const plus = await measure('tycoon-plus', 30);
  await lab.shot('eplus98_lv30');
  console.log(`eplus98 ${info.project.name}: render objects E Lv22 ${base.objects} / E+ Lv30 ${plus.objects}; fps ${base.fps.toFixed(1)} / ${plus.fps.toFixed(1)}; E+ product ${plus.e.item_px} px, ${plus.e.orientation}, ${plus.e.lanes} lanes`);
  expect(plus.e.level).toBe(30);
  expect(plus.objects, 'six lanes, five buildings, the arch and two crates draw no more than E at its thirty minutes (x1.25)').toBeLessThanOrEqual(base.objects * 1.25);
  expect(plus.fps, 'no collapse in frame rate').toBeGreaterThanOrEqual(base.fps * 0.6);
  expect(plus.e.item_px, 'a product still reads at six lanes').toBeGreaterThanOrEqual(info.project.name === 'desktop' ? 40 : 30);
  expect(plus.e.item_px, 'and bigger than E draws it').toBeGreaterThan(info.project.name === 'desktop' ? 19 : 24);
});

test('the tracks page: the E thirty-minute table and the grand link', async ({ page }, info) => {
  test.skip(info.project.name === 'p720', 'phone and desktop are enough for a static page');
  await page.goto('./tracks.html');
  await expect.poll(async () => page.locator('#eRunsTable tr').count(), { timeout: 10_000 }).toBe(4);
  await expect(page.locator('#eRunsTable')).toContainText('E+ grand');
  const alts = await page.locator('.card[data-id="tycoon-plus"] a.btn.ghost').evaluateAll((as) => as.map((a) => a.getAttribute('href')));
  expect(alts).toContain('./?dev=1&alt=grand#tycoon-plus');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1), 'no sideways scrolling').toBe(true);
});
