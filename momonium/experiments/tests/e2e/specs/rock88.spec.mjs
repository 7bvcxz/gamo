// Step 88: experiment C, Break & Upgrade, in the real web build. Tile C says
// PLAY and opens it; three minutes of play at a natural pace -- a real tap on
// the rock about 2.5 times a second of play, Pickaxe Power bought with a real
// tap whenever it can pay -- break several rocks and buy several upgrades;
// every tap is exactly one hit (a finger on phones, the mouse on desktop), a
// tap on the frame's button never hits the rock, a hidden tab stops the rise
// of the next rock. FUNLAB_SHOTS=<dir> keeps cracks, a break and the
// pickaxe before and after.
import { test, expect } from '../lib/lab.mjs';

const centre = (r) => [r[0] + r[2] / 2, r[1] + r[3] / 2, 4, 4];

test('three minutes of Break & Upgrade with real taps', async ({ lab }, info) => {
  await lab.open('./');
  let s = await lab.state();
  expect(s.playable, 'tile C says PLAY').toContain('rock');
  await lab.tapRect(s.tiles.rock);
  s = await lab.state();
  expect(s.route).toBe('rock');
  await lab.shot('rock88_start');
  let taps = 0;
  let shotCracks = false;
  let shotUpgrade = false;
  while (s.host.session.active_seconds < 180) {
    const before = s.host.experiment;
    await lab.tapRect(centre(before.rock_rect));
    taps++;
    s = await lab.state();
    const e = s.host.experiment;
    const counted = (s.host.session.actions_by_kind.hit || 0) + (s.host.session.actions_by_kind.tap_wait || 0) + (s.host.session.actions_by_kind.tap_miss || 0);
    expect(counted, `tap ${taps}: one tap, one record`).toBe(taps);
    if (!before.rising && e.breaks === before.breaks && e.rock === before.rock) {
      expect(before.hp - e.hp, `tap ${taps}: one hit of ${before.damage}`).toBe(before.damage);
    }
    if (!shotCracks && e.cracks > 0.6 && e.rock === 0) { shotCracks = true; await lab.shot('rock88_cracks'); }
    if (s.host.action.affordable) {
      if (!shotUpgrade && e.pick === 1) await lab.shot('rock88_pick_before');
      await lab.tapRect(s.host.rects.action);
      s = await lab.state();
      if (!shotUpgrade && s.host.experiment.pick === 2) { shotUpgrade = true; await lab.page.waitForTimeout(250); await lab.shot('rock88_pick_after'); }
    }
    await lab.call('dev_advance', 0.12);
    s = await lab.state();
  }
  await lab.shot('rock88_late');
  const sum = s.host.session;
  const breaks = sum.milestones.filter((m) => m.name === 'break');
  console.log(`rock88 ${info.project.name}: ${taps} taps, ${sum.actions_by_kind.hit} hits, ${breaks.length} rocks at ${breaks.map((b) => b.t_s).join(', ')}, pickaxe ${s.host.experiment.pick} (upgrades at ${sum.upgrades.map((u) => u.t_s).join(', ')}), rock ${s.host.experiment.rock} ${s.host.experiment.rock_name}`);
  expect(sum.actions_by_kind.tap_miss || 0, 'every tap on the rock').toBe(0);
  expect(breaks.length, 'several rocks').toBeGreaterThanOrEqual(5);
  expect(sum.upgrades.length, 'several upgrades').toBeGreaterThanOrEqual(3);
  expect(breaks[0].t_s, 'the first break at a natural pace').toBeLessThanOrEqual(35);
  expect(s.host.experiment.goal_visible, 'the Giant Crystal still ahead').toBe(true);
});

test("the frame's button never hits the rock; a hidden tab holds the next rock", async ({ lab }) => {
  await lab.open('./#rock');
  let s = await lab.state();
  await lab.tapRect(s.host.rects.action);
  s = await lab.state();
  expect(s.host.experiment.hp, 'the button is not the rock').toBe(50);
  expect(s.host.session.actions_by_kind.button_refused).toBe(1);
  await lab.call('dev_hits', 50);
  s = await lab.state();
  expect(s.host.experiment.breaks).toBe(1);
  await lab.tab(true);
  await lab.page.waitForTimeout(1500);
  expect((await lab.state()).host.experiment.rising, 'the next rock waits while hidden').toBe(true);
  await lab.tab(false);
  await expect.poll(async () => (await lab.state()).host.experiment.rising, { timeout: 5000 }).toBe(false);
});
