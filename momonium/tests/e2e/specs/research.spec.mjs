// Step 22: a Momo's proposal (Step 57: discovered when its letter came, the
// letter never opened), notes from the lab, then the research menu by real
// taps: pick the node, start it, and it finishes on the clock with its effect
// (two crops a harvest).
import { test, expect } from '../lib/fixtures.mjs';
import { settle } from '../lib/farm.mjs';

// Step 53: about what a Momo does -- the old starter Momo, explicitly.
test.use({ starterMomo: true });

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('research field expansion', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const { id: farm } = await game.query('dev_place_building', ['farm', 1, 0]);
  const { id: lab } = await game.query('dev_place_building', ['research', 0, 1]);
  await game.command({ type: 'momo.assign', momo: 1, building: farm });
  await game.query('dev_advance_ms', 250000);
  expect((await game.state()).mail.letters[0].read_ms, 'the letter is not even read').toBe(-1);
  for (let i = 0; i < 3; i++) {
    await settle(game, lab);
    expect((await game.command({ type: 'building.tap', id: lab })).ok).toBe(true);
    await settle(game, lab);
  }
  await game.query('dev_add_money', 50);
  const hud = await game.query('hud');
  const btn = await centre(game, hud.buttons.research, hud.window);
  await game.tap(btn.x, btn.y);
  await game.page.waitForTimeout(250);
  let r = await game.query('research');
  expect(r.open).toBe(true);
  expect(r.nodes.farm_expansion.state).toBe('available');
  const node = await centre(game, r.nodes.farm_expansion.rect, r.window);
  await game.tap(node.x, node.y);
  await game.page.waitForTimeout(200);
  r = await game.query('research');
  expect(r.selected).toBe('farm_expansion');
  expect(r.effects).toEqual(['Harvest: Crops +1']);
  expect(r.button_disabled).toBe(false);
  const start = await centre(game, r.button, r.window);
  await game.tap(start.x, start.y);
  await game.page.waitForTimeout(200);
  r = await game.query('research');
  expect(r.active.id).toBe('farm_expansion');
  await game.query('dev_advance_ms', 60000);
  r = await game.query('research');
  expect(r.completed).toContain('farm_expansion');
});
