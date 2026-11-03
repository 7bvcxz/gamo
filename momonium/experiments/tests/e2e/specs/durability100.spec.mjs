// Step 100: the 30-minute durability checkpoint in the real web build.
//
// Each of C, C+, E and E+ is played by real input for its first three
// minutes of play (taps on the rock and presses of the button through the
// canvas, in real time), then time-stepped by a scripted player to thirty
// minutes. At 3, 10, 15, 20 and 30 minutes it records the level, the last
// major visual reveal, actions and idle time, reward spacing and the frame
// rate (real frames, a median of three windows). The books must balance
// (coins = earned - spent) at every mark and no checkpoint may be missing.
// The scripted part is accelerated: it is technical and pacing evidence and
// never claims thirty minutes of real-time human play.
//
// Then the frame around the tracks: a direct link, rotation (the rock and the
// line stay in the play area), restart, a hidden tab, reduced motion, the
// sound toggle, a double click on the button and input blocking (pressing
// the button or the counter never hits the rock), and only funlab.* keys in
// this browser's storage.
import { test, expect } from '../lib/lab.mjs';

const fps = (page, ms) => page.evaluate((d) => new Promise((resolve) => {
  let n = 0;
  const t0 = performance.now();
  const tick = () => { n++; if (performance.now() - t0 < d) requestAnimationFrame(tick); else resolve(n / ((performance.now() - t0) / 1000)); };
  requestAnimationFrame(tick);
}), ms);
const median3 = async (page) => [await fps(page, 1000), await fps(page, 1000), await fps(page, 1000)].sort((a, b) => a - b)[1];
const MARKS = [180, 600, 900, 1200, 1800];

// The last thing newly seen (as tools/runs30.gd counts it), from the run's own record.
function lastReveal(sum, e) {
  const found = [];
  const isE = 'delivered' in e;
  const plus = 'kind' in e;
  for (const u of sum.upgrades) {
    if (isE ? u.show !== 'sparkle' : (!plus || u.milestone)) found.push([u.t_s, isE ? u.name : (u.tier || `pickaxe ${u.level}`)]);
  }
  for (const m of sum.milestones) {
    if (m.name === 'era') found.push([m.t_s, m.era]);
    if (m.name === 'break' && ((plus && m.big) || (!plus && m.rock < 10))) found.push([m.t_s, `broke rock ${m.rock}`]);
  }
  found.sort((a, b) => a[0] - b[0]);
  return found.length ? { t_s: found[found.length - 1][0], what: found[found.length - 1][1] } : null;
}
function balanced(sum, e) {
  const spent = sum.upgrades.reduce((a, u) => a + u.cost, 0);
  return Number.isInteger(e.coins) && Number.isInteger(e.earned) && e.coins === e.earned - spent;
}

for (const id of ['rock', 'rock-plus', 'tycoon', 'tycoon-plus']) {
  test(`${id}: three minutes by real input, then accelerated to thirty`, async ({ lab, page }, info) => {
    test.skip(info.project.name === 'p720', 'a narrow portrait phone and desktop');
    test.skip(info.project.name === 'desktop' && !id.endsWith('-plus'), 'desktop: the improved tracks');
    test.setTimeout(900_000);
    await lab.open(`./?t15=1#${id}`);
    await expect.poll(async () => (await lab.state()).route, { timeout: 15_000 }).toBe(id);
    const isC = id.startsWith('rock');
    let s = await lab.state();
    // Real input, real time, until three minutes of play.
    let presses = 0;
    let taps = 0;
    while (s.host.session.active_seconds < 180) {
      if (isC) {
        await lab.tapRect(s.host.experiment.rock_rect);
        taps++;
      } else {
        await page.waitForTimeout(1500);
      }
      s = await lab.state();
      if (s.host.action.affordable && s.host.rects.action && (!isC || taps % 6 === 0)) {
        await lab.tapRect(s.host.rects.action);
        presses++;
        s = await lab.state();
      }
    }
    if (isC) expect(s.host.experiment.taps, `${id}: real taps landed`).toBeGreaterThanOrEqual(Math.floor(taps * 0.9));
    expect(s.host.session.upgrades.length, `${id}: real presses bought`).toBeGreaterThanOrEqual(isC ? 2 : 4);
    const marks = {};
    const record = async (m) => {
      const fr = await median3(page);
      s = await lab.state();
      const e = s.host.experiment;
      const sum = s.host.session;
      expect(balanced(sum, e), `${id} at ${m / 60} min: coins = earned - spent, whole numbers`).toBe(true);
      expect(e.coins, `${id} at ${m / 60} min: never negative`).toBeGreaterThanOrEqual(0);
      marks[m / 60] = { level: e.level ?? e.pick, last_reveal: lastReveal(sum, e), actions: sum.actions, idle_s: sum.idle_seconds, rewards: sum.rewards, fps: Math.round(fr * 10) / 10,
        breaks: e.breaks, delivered: e.delivered, deliveries_per_min: e.deliveries_per_min };
    };
    await lab.call('dev_time_scale', 0);
    await record(180);
    await lab.shot(`durability100_${id}_3min`);
    for (const m of MARKS.slice(1)) {
      for (let guard = 0; guard < 200 && s.host.session.active_seconds < m; guard++) {
        if (isC) await lab.call('dev_hits', 25);
        s = (await lab.call('dev_advance', Math.min(10, m - s.host.session.active_seconds + 0.05))).state;
        for (let i = 0; i < 4 && s.host.action.affordable; i++) {
          await lab.call('dev_action');
          s = await lab.state();
        }
      }
      await lab.call('dev_time_scale', 1);
      await page.waitForTimeout(400);
      await record(m);
      await lab.call('dev_time_scale', 0);
    }
    await lab.shot(`durability100_${id}_30min`);
    const sum = s.host.session;
    for (const k of ['at_3min', 'at_10min', 'at_15min', 'at_20min', 'at_30min']) expect(sum[k], `${id}: ${k}`).not.toBeNull();
    expect(s.host.experiment.unique_deliveries ?? true, `${id}: nothing delivered twice`).toBe(true);
    console.log(`durability100 ${info.project.name} ${id}: real input ${isC ? `${taps} taps, ` : ''}${presses} presses in the first 3 min; ${JSON.stringify(marks)}`);
    if (info.project.name === 'phone') expect(marks[30].fps, `${id}: no collapse in frame rate by thirty minutes on a narrow phone`).toBeGreaterThanOrEqual(marks[3].fps * 0.5);
  });
}

test('around the tracks: direct link, rotation, restart, hidden tab, reduced motion, sound, double click, input blocking, storage', async ({ lab, page }, info) => {
  test.skip(info.project.name === 'p720', 'a narrow portrait phone and desktop');
  test.setTimeout(300_000);
  const size = page.viewportSize();
  // A direct link opens the experiment itself.
  await lab.open('./#rock-plus');
  await expect.poll(async () => (await lab.state()).route, { timeout: 15_000 }).toBe('rock-plus');
  await lab.call('dev_time_scale', 0);
  let s = await lab.state();
  // Input blocking: the button and the counter never reach the rock.
  const taps0 = s.host.experiment.taps;
  await lab.tapRect(s.host.rects.action);
  await lab.tapRect(s.host.rects.resource);
  s = await lab.state();
  expect(s.host.experiment.taps, 'pressing the button or the counter is not a tap on the rock').toBe(taps0);
  // A double click on the button is two presses at most: with coins for one,
  // one is bought and one refused; nothing reaches the rock.
  await lab.call('dev_coins', s.host.action.cost);
  s = await lab.state();
  const r = s.host.rects.action;
  const box = await page.locator('canvas').boundingBox();
  const k = box.width / s.window[0];
  const ups0 = s.host.session.upgrades.length;
  if (info.project.use.hasTouch) {
    await page.touchscreen.tap(box.x + (r[0] + r[2] / 2) * k, box.y + (r[1] + r[3] / 2) * k);
    await page.touchscreen.tap(box.x + (r[0] + r[2] / 2) * k, box.y + (r[1] + r[3] / 2) * k);
  } else {
    await page.mouse.dblclick(box.x + (r[0] + r[2] / 2) * k, box.y + (r[1] + r[3] / 2) * k);
  }
  await page.waitForTimeout(400);
  s = await lab.state();
  expect(s.host.session.upgrades.length - ups0, 'one bought with coins for one').toBe(1);
  expect(s.host.session.actions_by_kind.button_refused ?? 0, 'and the second press refused, not lost into the rock').toBeGreaterThanOrEqual(1);
  expect(s.host.experiment.taps, 'still no tap on the rock').toBe(taps0);
  // Rotation: the rock stays in the window; back again.
  await page.setViewportSize({ width: size.height, height: size.width });
  await page.waitForTimeout(1200);
  s = await lab.state();
  let rr = s.host.experiment.rock_rect;
  expect(rr[0] >= 0 && rr[1] >= 0 && rr[0] + rr[2] <= s.window[0] && rr[1] + rr[3] <= s.window[1], `the rock in the window after turning (${rr} in ${s.window})`).toBe(true);
  await lab.shot('durability100_rotated_rock');
  await page.setViewportSize(size);
  await page.waitForTimeout(1200);
  s = await lab.state();
  rr = s.host.experiment.rock_rect;
  expect(rr[0] + rr[2] <= s.window[0] && rr[1] + rr[3] <= s.window[1], 'and after turning back').toBe(true);
  // Restart: a new run from nothing.
  await lab.tapRect(s.host.rects.restart);
  s = await lab.state();
  expect(s.host.runs, 'a new run').toBe(2);
  expect(s.host.experiment.coins).toBe(0);
  // The sound toggle.
  const muted = s.host.muted;
  await lab.tapRect(s.host.rects.sound);
  expect((await lab.state()).host.muted, 'the sound toggles').toBe(!muted);
  await lab.tapRect((await lab.state()).host.rects.sound);
  expect((await lab.state()).host.muted, 'and back').toBe(muted);
  // E+: rotation keeps the line in the play area; a hidden tab stops play.
  await lab.open('./#tycoon-plus');
  await expect.poll(async () => (await lab.state()).route, { timeout: 15_000 }).toBe('tycoon-plus');
  await lab.call('dev_level', 12);
  await lab.call('dev_advance', 20);
  for (const vp of [{ width: size.height, height: size.width }, size]) {
    await page.setViewportSize(vp);
    await page.waitForTimeout(1500);
    s = await lab.state();
    const e = s.host.experiment;
    const [lx, ly, lw, lh] = e.line_rect;
    const [px, py, pw, ph] = e.play_rect;
    expect(lx >= px - 2 && ly >= py - 2 && lx + lw <= px + pw + 2 && ly + lh <= py + ph + 2, `the line inside the play area at ${vp.width}x${vp.height} (${e.orientation})`).toBe(true);
    if (vp.width > vp.height) await lab.shot('durability100_rotated_line');
  }
  await lab.call('dev_time_scale', 1);
  await page.waitForTimeout(500);
  await lab.tab(true);
  s = await lab.state();
  const t0 = s.host.session.active_seconds;
  await page.waitForTimeout(2000);
  s = await lab.state();
  await lab.tab(false);
  expect(s.host.session.active_seconds, 'a hidden tab adds no play time').toBe(t0);
  // Reduced motion: it says so and still plays.
  await lab.open('./?motion=reduce#rock-plus');
  await expect.poll(async () => (await lab.state()).route, { timeout: 15_000 }).toBe('rock-plus');
  s = await lab.state();
  expect(s.host.reduced_motion, 'reduced motion on').toBe(true);
  await lab.call('dev_hits', 40);
  expect((await lab.state()).host.experiment.breaks, 'and the rock still breaks').toBeGreaterThanOrEqual(1);
  // Storage: only the Lab's own keys.
  const keys = await page.evaluate(() => Object.keys(localStorage));
  expect(keys.filter((x) => !x.startsWith('funlab.')), 'only funlab.* keys').toEqual([]);
});
