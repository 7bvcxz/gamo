// Step 87: experiment A, Island Growth, in the real web build. Tile A says
// PLAY and opens it; three minutes of play with a real tap on Upgrade Island
// whenever it can pay take the island through the Islet, the Village and the
// Town, with the Monument waiting as a ghost; the island stays between the
// frame and the button; a reload of the direct link starts a fresh island; a
// hidden tab earns nothing. FUNLAB_SHOTS=<dir> keeps early/mid/late frames.
import { test, expect } from '../lib/lab.mjs';

test('three minutes of Island Growth, tapping Upgrade Island when it can pay', async ({ lab }, info) => {
  await lab.open('./');
  let s = await lab.state();
  expect(s.playable, 'tile A says PLAY').toContain('island');
  await lab.tapRect(s.tiles.island);
  s = await lab.state();
  expect(s.route).toBe('island');
  expect(s.host.experiment.level).toBe(0);
  const shots = [[20, 'early'], [100, 'mid'], [178, 'late']];
  let taps = 0;
  while (s.host.session.active_seconds < 180) {
    await lab.call('dev_advance', 1);
    s = await lab.state();
    if (s.host.action.affordable) {
      const before = s.host.experiment.level;
      await lab.tapRect(s.host.rects.action);
      taps++;
      s = await lab.state();
      expect(s.host.experiment.level, 'one tap, one upgrade').toBe(before + 1);
    }
    if (shots.length && s.host.session.active_seconds >= shots[0][0]) {
      const [, label] = shots.shift();
      await lab.page.waitForTimeout(900);
      await lab.shot(`island87_${label}`);
      s = await lab.state();
    }
    const r = s.host.experiment.island_rect;
    expect(r[1] >= 199 && r[1] + r[3] <= s.host.rects.action[1] + 1, `the island between the frame and the button at ${s.host.session.active_seconds}s: ${r}`).toBe(true);
  }
  const sum = s.host.session;
  console.log(`island87 ${info.project.name}: level ${s.host.experiment.level} (${s.host.experiment.stage}) at ${sum.active_seconds}s, upgrades at ${sum.upgrades.map((u) => u.t_s).join(', ')}, milestones ${sum.milestones.map((m) => `${m.name}@${m.t_s}`).join(', ')}`);
  expect(sum.first_upgrade_s, 'the first upgrade within 10-30 s').toBeLessThanOrEqual(30);
  expect(sum.first_upgrade_s).toBeGreaterThanOrEqual(10);
  expect(s.host.experiment.stage, 'the Town by 3:00').toBe('town');
  expect(sum.milestones.map((m) => m.name)).toEqual(['village', 'town']);
  expect(sum.upgrades.length, 'several upgrades').toBeGreaterThanOrEqual(7);
  expect(s.host.experiment.milestone_ghost, 'the Monument waits as a ghost').toBe(true);
  expect(sum.actions_by_kind.button, 'every tap was one press').toBe(taps);
});

test('a reload of the direct link starts a fresh island', async ({ lab }) => {
  await lab.open('./#island');
  await lab.call('dev_advance', 20);
  let s = await lab.state();
  await lab.tapRect(s.host.rects.action);
  expect((await lab.state()).host.experiment.level).toBe(1);
  await lab.page.reload();
  await lab.ready();
  s = await lab.state();
  expect(s.route, 'still A').toBe('island');
  expect(s.host.experiment.level, 'from level 0').toBe(0);
  expect(s.host.experiment.coins).toBeLessThan(3);
  await lab.shot('island87_reload');
});

test('a hidden tab earns nothing', async ({ lab }) => {
  await lab.open('./#island');
  await lab.page.waitForTimeout(800);
  await lab.tab(true);
  const before = (await lab.state()).host.experiment.coins;
  await lab.page.waitForTimeout(3000);
  expect((await lab.state()).host.experiment.coins, 'no coins while hidden').toBe(before);
  await lab.tab(false);
});

test('reduced motion still shows every change', async ({ lab }) => {
  await lab.open('./?motion=reduce#island');
  let s = await lab.state();
  expect(s.reduced_motion).toBe(true);
  await lab.call('dev_advance', 50);
  for (let i = 0; i < 3; i++) {
    s = await lab.state();
    await lab.tapRect(s.host.rects.action);
  }
  s = await lab.state();
  expect(s.host.experiment.level).toBe(3);
  expect(s.host.experiment.cells, 'the Village coast at once').toBe(16);
  await lab.shot('island87_reduced');
});
