// Step 89: experiment F, Endless Growth, in the real web build. Tile F says
// PLAY and opens it; three minutes of play with a real tap on Grow Tree
// whenever it can pay turn the tree through many shapes, each standing on its
// foot inside the frame; at three minutes the card asks "See the next tree?"
// and a real tap answers it; a reload of the direct link starts from the
// sprout; a hidden tab grows nothing. FUNLAB_SHOTS=<dir> keeps early, mid and
// late trees.
import { test, expect } from '../lib/lab.mjs';

test('three minutes of Endless Growth, tapping Grow Tree when it can pay', async ({ lab }, info) => {
  await lab.open('./');
  let s = await lab.state();
  expect(s.playable, 'tile F says PLAY').toContain('tree');
  await lab.tapRect(s.tiles.tree);
  s = await lab.state();
  expect(s.route).toBe('tree');
  expect(s.host.experiment.preview, 'the next shape stands behind the sprout').toBe(true);
  const shots = [[30, 'early'], [100, 'mid'], [178, 'late']];
  const seen = new Set([s.host.experiment.name]);
  while (s.host.session.active_seconds < 181) {
    s = (await lab.call('dev_advance', 1)).state;
    if (s.host.action.affordable) {
      const before = s.host.experiment.stage;
      await lab.tapRect(s.host.rects.action);
      s = await lab.state();
      expect(s.host.experiment.stage, 'one tap, one new shape').toBe(before + 1);
      seen.add(s.host.experiment.name);
    }
    if (shots.length && s.host.session.active_seconds >= shots[0][0]) {
      const [, label] = shots.shift();
      await lab.page.waitForTimeout(1300);
      await lab.shot(`tree89_${label}`);
      s = await lab.state();
    }
    const r = s.host.experiment.tree_rect;
    expect(r[1] >= 199 && s.host.experiment.foot[1] <= s.host.rects.action[1] + 1, `the tree inside the frame at ${s.host.session.active_seconds}s: ${r}`).toBe(true);
  }
  // The three-minute question, answered with a real tap.
  expect(s.host.rects.intent_yes, 'the card asks at three minutes').toBeTruthy();
  await lab.shot('tree89_question');
  await lab.tapRect(s.host.rects.intent_yes);
  s = await lab.state();
  const sum = s.host.session;
  console.log(`tree89 ${info.project.name}: stage ${s.host.experiment.stage} (${s.host.experiment.name}) at ${sum.active_seconds}s; shapes ${[...seen].join(' > ')}; changes at ${sum.upgrades.map((u) => u.t_s).join(', ')}; intent ${sum.metrics.continue_intent}`);
  expect(sum.metrics.continue_intent).toBe('yes');
  expect(sum.first_upgrade_s, 'the first change within 10-30 s').toBeLessThanOrEqual(30);
  expect(sum.first_upgrade_s).toBeGreaterThanOrEqual(10);
  expect(seen.size, 'many different trees in three minutes').toBeGreaterThanOrEqual(8);
});

test('a reload of the direct link starts from the sprout; a hidden tab grows nothing', async ({ lab }) => {
  await lab.open('./#tree');
  await lab.call('dev_advance', 13);
  let s = await lab.state();
  await lab.tapRect(s.host.rects.action);
  expect((await lab.state()).host.experiment.stage).toBe(1);
  await lab.page.reload();
  await lab.ready();
  s = await lab.state();
  expect(s.route).toBe('tree');
  expect(s.host.experiment.stage, 'a sprout again').toBe(0);
  await lab.shot('tree89_reload');
  await lab.tab(true);
  const coins = (await lab.state()).host.experiment.coins;
  await lab.page.waitForTimeout(2500);
  expect((await lab.state()).host.experiment.coins, 'no coins while hidden').toBe(coins);
  await lab.tab(false);
});

test('reduced motion: every shape still changes', async ({ lab }) => {
  await lab.open('./?motion=reduce#tree');
  let s = await lab.state();
  expect(s.reduced_motion).toBe(true);
  for (let i = 0; i < 3; i++) {
    while (!s.host.action.affordable) s = (await lab.call('dev_advance', 2)).state;
    await lab.tapRect(s.host.rects.action);
    s = await lab.state();
  }
  expect(s.host.experiment.stage).toBe(3);
  expect(s.host.experiment.name).toBe('Branching');
  await lab.shot('tree89_reduced');
});
