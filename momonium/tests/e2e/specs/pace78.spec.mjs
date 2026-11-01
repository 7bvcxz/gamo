// Step 78: every building's production x5 slower again, on the real web
// build -- a sowing by a real tap takes 31.25 s (Step 69: 6.25, Step 58: 2.5),
// the building's details count it down from 32 s and it ends on time, not
// before; the cycle reads 1 min 44 s by hand; after the watering the crop
// ripens 10 s (2 s before), counted down on the details and refused until
// then, no money before the harvest; a farm takes 37.5 s to build (x12.5)
// and is not ready a moment before. (Step 69's spec, pace69, checked the
// same at x6.25.)
import { test, expect } from '../lib/fixtures.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

// With MOMONIUM_SHOTS set: the ripening farm and its details, as drawn.
const shot = async (game, name, info) => {
  if (process.env.MOMONIUM_SHOTS) await game.page.screenshot({ path: `${process.env.MOMONIUM_SHOTS}/pace78_${info.project.name}_${name}.png` });
};

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('the slower work and the slower ripening, on the screen and on the clock', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const rules = await game.query('rules');
  expect(rules.work_scale).toBe(31.25);
  expect(rules.wait_scale).toBe(5);
  expect(rules.build_scale).toBe(12.5);
  expect(rules.farm_stages.map(([, w]) => w)).toEqual([31250, 31250, 31250]);
  expect(rules.farm_stages.map(([, , c]) => c), 'the wait after watering').toEqual([0, 10000, 0]);
  expect(rules.farm_wait_ms).toBe(10000);
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
  // The tap that selected the farm sowed it: 31.25 s, counted down from 32.
  expect(p.detail.state).toBe('Sow · 32 s left');
  expect(p.detail.you, 'a cycle by hand: 3 x 31.25 s + the 10 s ripening').toBe('1 min 44 s');
  const id = (await game.state()).buildings.buildings.find((b) => b.anchor[0] === 1 && b.anchor[1] === 0).id;
  const farm = async () => (await game.state()).buildings.buildings.find((b) => b.id === id);
  expect((await farm()).completed).toBe(0);
  await game.query('dev_advance_ms', 31000);
  await game.page.waitForTimeout(200);
  expect((await farm()).completed, 'not before its time').toBe(0);
  expect((await game.query('panels')).detail.state).toBe('Sow · 1 s left');
  await game.query('dev_advance_ms', 260);
  await game.page.waitForTimeout(200);
  expect((await farm()).completed, 'done at 31.25 s').toBe(1);
  // The watering, then the crop ripens: 10 s, counted down, refused until
  // then, nothing paid before the harvest.
  expect((await game.command({ type: 'building.tap', id })).ok).toBe(true);
  await game.query('dev_advance_ms', 31255);
  await game.page.waitForTimeout(200);
  expect((await farm()).state).toBe('cooldown');
  expect((await game.query('panels')).detail.state).toBe('Harvest in 10 s');
  await shot(game, 'ripening_10s', info);
  const money = (await game.state()).economy.money;
  await game.query('dev_advance_ms', 5000);
  await game.page.waitForTimeout(200);
  expect((await game.query('panels')).detail.state, 'the ripening counts down: not frozen').toBe('Harvest in 5 s');
  await shot(game, 'ripening_5s', info);
  expect((await game.command({ type: 'building.tap', id })).reason, 'not ripe yet').toBe('err.cooldown');
  await game.query('dev_advance_ms', 4990);
  expect((await game.command({ type: 'building.tap', id })).reason, '10 ms before: still ripening').toBe('err.cooldown');
  expect((await game.state()).economy.money, 'and nothing paid yet').toBe(money);
  await game.query('dev_advance_ms', 20);
  expect((await game.command({ type: 'building.tap', id })).ok, 'ripe: the harvest starts').toBe(true);
  await game.query('dev_advance_ms', 31255);
  expect((await game.state()).economy.money, 'paid at the harvest').toBeGreaterThan(money);
  // A farm built through the game's own command: 37.5 s, not 3.
  await game.query('dev_add_money', 100);
  const r = await game.command({ type: 'building.place', building: 'farm', anchor: [0, 1] });
  expect(r.ok).toBe(true);
  const built = async () => (await game.state()).buildings.buildings.find((b) => b.id === r.id).state;
  expect(await built()).toBe('constructing');
  await game.query('dev_advance_ms', rules.farm_build_ms - 50);
  expect(await built(), '50 ms before: still building').toBe('constructing');
  await game.query('dev_advance_ms', 60);
  expect(await built()).not.toBe('constructing');
  expect(rules.farm_build_ms).toBe(37500);
});
