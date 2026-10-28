// Step 69: the work x2.5 slower again, on the real web build -- a sowing by
// a real tap takes 6.25 s (Step 58: 2.5 s), the building's details count it
// down from 7 s and it ends on time, not before; the cycle reads 21 s by
// hand; a farm takes 7.5 s to build (x2.5) and is not ready a moment before.
import { test, expect } from '../lib/fixtures.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('the slower work, on the screen and on the clock', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const rules = await game.query('rules');
  expect(rules.work_scale).toBe(6.25);
  expect(rules.build_scale).toBe(2.5);
  expect(rules.farm_stages.map(([, w]) => w)).toEqual([6250, 6250, 6250]);
  await game.query('dev_place_building', ['farm', 1, 0]);
  await game.page.waitForTimeout(200);
  const f = await clearPointOnCell(game, [1, 0]);
  await game.tap(f.x, f.y);
  await game.page.waitForTimeout(250);
  let p = await game.query('panels');
  const t = await centre(game, p.context_title, p.window);
  await game.tap(t.x, t.y);
  await game.page.waitForTimeout(250);
  p = await game.query('panels');
  expect(p.detail_open).toBe(true);
  // The tap that selected the farm sowed it: 6.25 s, counted down from 7.
  expect(p.detail.state).toBe('Sow · 7 s left');
  expect(p.detail.you).toBe('21 s');
  const id = (await game.state()).buildings.buildings.find((b) => b.anchor[0] === 1 && b.anchor[1] === 0).id;
  const done = async () => (await game.state()).buildings.buildings.find((b) => b.id === id).completed;
  expect(await done()).toBe(0);
  await game.query('dev_advance_ms', 6000);
  await game.page.waitForTimeout(200);
  expect(await done(), 'not before its time').toBe(0);
  expect((await game.query('panels')).detail.state).toBe('Sow · 1 s left');
  await game.query('dev_advance_ms', 260);
  await game.page.waitForTimeout(200);
  expect(await done(), 'done at 6.25 s').toBe(1);
  // A farm built through the game's own command: 7.5 s, not 3.
  await game.query('dev_add_money', 100);
  const r = await game.command({ type: 'building.place', building: 'farm', anchor: [0, 1] });
  expect(r.ok).toBe(true);
  const built = async () => (await game.state()).buildings.buildings.find((b) => b.id === r.id).state;
  expect(await built()).toBe('constructing');
  await game.query('dev_advance_ms', rules.farm_build_ms - 50);
  expect(await built(), '50 ms before: still building').toBe('constructing');
  await game.query('dev_advance_ms', 60);
  expect(await built()).not.toBe('constructing');
  expect(rules.farm_build_ms).toBe(7500);
});
