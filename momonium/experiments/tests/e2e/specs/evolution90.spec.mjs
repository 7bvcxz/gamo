// Step 90: experiment B, Momo Evolution, in the real web build. Tile B says
// PLAY and opens it; three minutes of play with a real tap on Upgrade Momo
// whenever it can pay change the one Momo's tool and motion and what it
// wears, from one camera that never moves (the Momo's place and size fixed);
// the coins are exactly the finished passes' pay less what was spent; taps on
// the world do nothing; the frame rate late in the run is not lower than
// early; a reload of the direct link starts again; a hidden tab works nothing.
// FUNLAB_SHOTS=<dir> keeps early, mid and late frames.
import { test, expect } from '../lib/lab.mjs';

// Frames a second over `ms`, counted in the page.
const fps = (page, ms) => page.evaluate((d) => new Promise((resolve) => {
  let n = 0;
  const t0 = performance.now();
  const tick = () => { n++; if (performance.now() - t0 < d) requestAnimationFrame(tick); else resolve(n / ((performance.now() - t0) / 1000)); };
  requestAnimationFrame(tick);
}), ms);

test('three minutes of Momo Evolution, tapping Upgrade Momo when it can pay', async ({ lab }, info) => {
  await lab.open('./');
  let s = await lab.state();
  expect(s.playable, 'tile B says PLAY').toContain('evolution');
  await lab.tapRect(s.tiles.evolution);
  s = await lab.state();
  expect(s.route).toBe('evolution');
  const first = s.host.experiment;
  await lab.page.waitForTimeout(500);
  const fpsEarly = await fps(lab.page, 2000);
  // Taps on the world (the sea, the Momo) do nothing.
  const box = await lab.canvas.boundingBox();
  const k = box.width / s.window[0];
  for (const p of [[60, 700], first.foot]) {
    const x = box.x + p[0] * k;
    const y = box.y + (p[1] - 60) * k;
    if (info.project.use.hasTouch) await lab.page.touchscreen.tap(x, y); else await lab.page.mouse.click(x, y);
  }
  await lab.page.waitForTimeout(300);
  s = await lab.state();
  expect(s.host.session.actions, 'taps on the world are not actions').toBe(0);
  expect(s.host.experiment.level, 'and buy nothing').toBe(0);

  const shots = [[25, 'early'], [100, 'mid'], [178, 'late']];
  let spent = 0;
  const poses = new Set([s.host.experiment.pose]);
  while (s.host.session.active_seconds < 180) {
    s = (await lab.call('dev_advance', 1)).state;
    if (s.host.action.affordable) {
      const before = s.host.experiment;
      await lab.tapRect(s.host.rects.action);
      s = await lab.state();
      expect(s.host.experiment.level, 'one tap, one upgrade').toBe(before.level + 1);
      spent += before.next_cost;
      poses.add(s.host.experiment.pose);
    }
    const e = s.host.experiment;
    expect(e.foot, 'the Momo keeps its place').toEqual(first.foot);
    expect(Math.abs(e.momo_height - first.momo_height), 'and its size').toBeLessThan(0.01);
    if (shots.length && s.host.session.active_seconds >= shots[0][0]) {
      const [, label] = shots.shift();
      await lab.page.waitForTimeout(400);
      await lab.shot(`evolution90_${label}`);
      s = await lab.state();
    }
  }
  const fpsLate = await fps(lab.page, 2000);
  const e = s.host.experiment;
  const sum = s.host.session;
  console.log(`evolution90 ${info.project.name}: level ${e.level} (${e.name}) at ${sum.active_seconds}s, poses ${[...poses].join(' > ')}, ${e.passes} passes, earned ${e.earned}, upgrades at ${sum.upgrades.map((u) => u.t_s).join(', ')}, fps ${fpsEarly.toFixed(1)} -> ${fpsLate.toFixed(1)}`);
  expect(e.coins, 'coins = what finished passes paid - what was spent').toBe(e.earned - spent);
  expect(sum.first_upgrade_s, 'the first upgrade within 10-30 s').toBeLessThanOrEqual(30);
  expect(sum.first_upgrade_s).toBeGreaterThanOrEqual(10);
  expect(sum.upgrades.length, 'several upgrades').toBeGreaterThanOrEqual(8);
  expect(poses.size, 'several tools and motions').toBeGreaterThanOrEqual(5);
  expect(fpsLate, 'no drop in frame rate as the Momo evolves').toBeGreaterThanOrEqual(fpsEarly * 0.8);
});

test('a reload of the direct link starts again; a hidden tab works nothing', async ({ lab }) => {
  await lab.open('./#evolution');
  let s = await lab.state();
  while (!s.host.action.affordable) s = (await lab.call('dev_advance', 2)).state;
  await lab.tapRect(s.host.rects.action);
  expect((await lab.state()).host.experiment.level).toBe(1);
  await lab.page.reload();
  await lab.ready();
  s = await lab.state();
  expect(s.route).toBe('evolution');
  expect(s.host.experiment.level, 'from the start again').toBe(0);
  await lab.shot('evolution90_reload');
  await lab.tab(true);
  const passes = (await lab.state()).host.experiment.passes;
  await lab.page.waitForTimeout(3000);
  expect((await lab.state()).host.experiment.passes, 'no work while hidden').toBe(passes);
  await lab.tab(false);
});
