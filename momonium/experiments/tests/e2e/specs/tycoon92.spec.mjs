// Step 92: experiment E, Production Tycoon, in the real web build. Tile E
// says PLAY and opens it; the belt really moves and items ride it; three
// minutes of play with a real tap on Improve Line whenever it can pay make the
// line livelier step by step (arms, a new machine, Momo, lanes) and every
// delivery is counted once (coins = deliveries' value - spending); the frame
// rate does not fall as output rises; a hidden tab makes nothing; a reload
// starts the line again. FUNLAB_SHOTS=<dir> keeps early, mid and late lines.
import { test, expect } from '../lib/lab.mjs';

const fps = (page, ms) => page.evaluate((d) => new Promise((resolve) => {
  let n = 0;
  const t0 = performance.now();
  const tick = () => { n++; if (performance.now() - t0 < d) requestAnimationFrame(tick); else resolve(n / ((performance.now() - t0) / 1000)); };
  requestAnimationFrame(tick);
}), ms);

test('three minutes of Production Tycoon, tapping Improve Line when it can pay', async ({ lab }, info) => {
  await lab.open('./');
  let s = await lab.state();
  expect(s.playable, 'tile E says PLAY').toContain('tycoon');
  await lab.tapRect(s.tiles.tycoon);
  s = await lab.state();
  expect(s.route).toBe('tycoon');
  // The belt moves on its own: items appear and travel.
  s = (await lab.call('dev_advance', 6)).state;
  expect(s.host.experiment.on_belt, 'items on the belt').toBeGreaterThanOrEqual(1);
  await lab.page.waitForTimeout(500);
  // Three windows each, the median: one 2 s window at 15-20 frames a second
  // swung from pass to fail between runs of the same build under load
  // (Step 97: the 0.93.0 build read 19.5 -> 17.4 and 15.5 -> 17.1, the new
  // one 21.2 -> 15.6 and 20.1 -> 18.5).
  const median3 = async () => { const v = [await fps(lab.page, 1500), await fps(lab.page, 1500), await fps(lab.page, 1500)].sort((a, b) => a - b); return v[1]; };
  const fpsEarly = await median3();
  let spent = 0;
  const looks = new Set();
  const shots = [[25, 'early'], [100, 'mid'], [178, 'late']];
  while (s.host.session.active_seconds < 180) {
    s = (await lab.call('dev_advance', 1)).state;
    if (s.host.action.affordable) {
      const before = s.host.experiment;
      await lab.tapRect(s.host.rects.action);
      s = await lab.state();
      expect(s.host.experiment.level, 'one tap, one improvement').toBe(before.level + 1);
      spent += before.next_cost;
      const e = s.host.experiment;
      looks.add(`${e.lanes}/${e.arms}/${e.machine}/${e.helpers}`);
    }
    if (shots.length && s.host.session.active_seconds >= shots[0][0]) {
      const [, label] = shots.shift();
      await lab.page.waitForTimeout(600);
      await lab.shot(`tycoon92_${label}`);
      s = await lab.state();
    }
  }
  const fpsLate = await median3();
  const e = s.host.experiment;
  const sum = s.host.session;
  console.log(`tycoon92 ${info.project.name}: level ${e.level} (${e.name}), ${e.lanes} lanes, ${e.arms} arms, ${e.helpers} Momo, ${e.delivered} delivered of ${e.spawned} made, ${e.deliveries_per_min}/min at the end, upgrades at ${sum.upgrades.map((u) => u.t_s).join(', ')}, fps ${fpsEarly.toFixed(1)} -> ${fpsLate.toFixed(1)}`);
  expect(e.unique_deliveries, 'every delivery counted once').toBe(true);
  expect(e.coins, 'coins = deliveries paid - spending').toBe(e.earned - spent);
  expect(sum.first_upgrade_s, 'the first improvement within 10-30 s').toBeLessThanOrEqual(30);
  expect(sum.upgrades.length, 'several improvements').toBeGreaterThanOrEqual(6);
  expect(looks.size, 'the line looked different after the improvements').toBeGreaterThanOrEqual(4);
  expect(fpsLate, 'no stutter as output rises').toBeGreaterThanOrEqual(fpsEarly * 0.7);
});

test('a hidden tab makes nothing; a reload starts the line again', async ({ lab }) => {
  await lab.open('./#tycoon');
  let s = (await lab.call('dev_advance', 20)).state;
  await lab.tab(true);
  const made = (await lab.state()).host.experiment.spawned;
  await lab.page.waitForTimeout(2500);
  expect((await lab.state()).host.experiment.spawned, 'nothing made while hidden').toBe(made);
  await lab.tab(false);
  await lab.page.reload();
  await lab.ready();
  s = await lab.state();
  expect(s.route).toBe('tycoon');
  expect(s.host.experiment.delivered, 'a fresh line').toBe(0);
});
