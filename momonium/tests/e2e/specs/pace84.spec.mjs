// Step 84: production three times as fast as Step 78, on the real web build
// -- a sowing by a real tap takes 10.4 s (Step 78: 31.25, Step 69: 6.25), the
// building's details count it down from 11 s and it ends on time, not
// before; the cycle reads 35 s by hand (Step 78: 1 min 44 s); after the
// watering the crop ripens 3.3 s (Step 78: 10 s), counted down and refused
// until then, no money before the harvest; a farm takes 12.5 s to build
// (Step 78: 37.5 s) and is not ready a moment before. A brand-new player's
// first harvest takes the new time, and a stage under way when the game was
// saved ends when it was going to after the game is opened again. (Step 78's
// spec, pace78, checked the same at x5.)
import { test, expect } from '../lib/fixtures.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

const shot = async (game, name, info) => {
  if (process.env.MOMONIUM_SHOTS) await game.page.screenshot({ path: `${process.env.MOMONIUM_SHOTS}/pace84_${info.project.name}_${name}.png` });
};

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('three times as fast as Step 78: the work, the ripening and construction, on the screen and on the clock', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const rules = await game.query('rules');
  expect(rules.work_scale).toBeCloseTo(31.25 / 3, 6);
  expect(rules.wait_scale).toBeCloseTo(5 / 3, 6);
  expect(rules.build_scale).toBeCloseTo(12.5 / 3, 6);
  expect(rules.farm_stages.map(([, w]) => w), 'each farm stage: a third of 31.25 s').toEqual([10417, 10417, 10417]);
  expect(rules.farm_stages.map(([, , c]) => c), 'the wait after watering: a third of 10 s').toEqual([0, 3333, 0]);
  expect(rules.farm_wait_ms).toBe(3333);
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
  // The tap that selected the farm sowed it: 10.42 s, counted down from 11.
  expect(p.detail.state).toBe('Sow · 11 s left');
  expect(p.detail.you, 'a cycle by hand: 3 x 10.42 s + the 3.33 s ripening').toBe('35 s');
  const id = (await game.state()).buildings.buildings.find((b) => b.anchor[0] === 1 && b.anchor[1] === 0).id;
  const farm = async () => (await game.state()).buildings.buildings.find((b) => b.id === id);
  expect((await farm()).completed).toBe(0);
  await game.query('dev_advance_ms', 10000);
  await game.page.waitForTimeout(200);
  expect((await farm()).completed, 'not before its time').toBe(0);
  await expect.poll(async () => (await game.query('panels')).detail.state).toBe('Sow · 1 s left');
  await game.query('dev_advance_ms', 420);
  await game.page.waitForTimeout(200);
  expect((await farm()).completed, 'done at 10.42 s').toBe(1);
  // The watering, then the crop ripens: 3.3 s, counted down, refused until
  // then, nothing paid before the harvest.
  expect((await game.command({ type: 'building.tap', id })).ok).toBe(true);
  await game.query('dev_advance_ms', 10422);
  await game.page.waitForTimeout(200);
  expect((await farm()).state).toBe('cooldown');
  await expect.poll(async () => (await game.query('panels')).detail.state).toBe('Harvest in 4 s');
  await shot(game, 'ripening', info);
  const money = (await game.state()).economy.money;
  await game.query('dev_advance_ms', 1500);
  await expect.poll(async () => (await game.query('panels')).detail.state, { message: 'the ripening counts down: not frozen' }).toBe('Harvest in 2 s');
  expect((await game.command({ type: 'building.tap', id })).reason, 'not ripe yet').toBe('err.cooldown');
  await game.query('dev_advance_ms', 3333 - 1500 - 10);
  expect((await game.command({ type: 'building.tap', id })).reason, '10 ms before: still ripening').toBe('err.cooldown');
  expect((await game.state()).economy.money, 'and nothing paid yet').toBe(money);
  await game.query('dev_advance_ms', 20);
  expect((await game.command({ type: 'building.tap', id })).ok, 'ripe: the harvest starts').toBe(true);
  await game.query('dev_advance_ms', 10422);
  expect((await game.state()).economy.money, 'paid at the harvest, once').toBeGreaterThan(money);
  // A farm built through the game's own command: 12.5 s.
  await game.query('dev_add_money', 100);
  const r = await game.command({ type: 'building.place', building: 'farm', anchor: [0, 1] });
  expect(r.ok).toBe(true);
  const built = async () => (await game.state()).buildings.buildings.find((b) => b.id === r.id).state;
  expect(await built()).toBe('constructing');
  await game.query('dev_advance_ms', rules.farm_build_ms - 50);
  expect(await built(), '50 ms before: still building').toBe('constructing');
  await game.query('dev_advance_ms', 60);
  expect(await built()).not.toBe('constructing');
  expect(rules.farm_build_ms).toBe(12500);
});

test("a brand-new player's first harvest takes the new time; a stage under way when saved ends on its time after opening again", async ({ page, context }, info) => {
  const errors = [];
  const open = async () => {
    const pg = await context.newPage();
    pg.on('pageerror', (e) => errors.push(e.message));
    await pg.addInitScript(() => {
      window.MOMONIUM_E2E = true;
      // The real first island (its ripe farm), not the bare test world.
      window.MOMONIUM_E2E_ISLAND = true;
    });
    await pg.goto('./');
    await pg.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.state === 'function', null, { timeout: 90_000 });
    await pg.waitForTimeout(500);
    await pg.evaluate(() => window.momonium.setTimeScale(0));
    return pg;
  };
  const call = (pg, n, a) => pg.evaluate(([n, a]) => window.momonium.call(n, a), [n, a]);
  const cmd = (pg, c) => pg.evaluate((x) => window.momonium.command(x), c);
  const st = (pg) => pg.evaluate(() => window.momonium.state());
  await page.close();
  const a = await open();
  const first = (await st(a)).buildings.buildings[0];
  expect(first.type).toBe('farm');
  const r = await cmd(a, { type: 'building.tap', id: first.id });
  expect(r.ok, "the new island's ripe crop: the first tap harvests").toBe(true);
  const now = (await st(a)).now_ms;
  expect(r.ends_ms - now, 'the harvest: 10.4 s (Step 78: 31.25 s)').toBe(10417);
  // Saved mid-harvest; opened again: it ends when it was going to.
  expect((await call(a, 'save_now')).err).toBe(0);
  await a.close();
  const b = await open();
  const again = (await st(b)).buildings.buildings.find((x) => x.id === first.id);
  expect(again.state, 'still harvesting').toBe('working');
  expect(again.task_end, 'the end it was promised').toBe(r.ends_ms);
  await call(b, 'dev_advance_ms', again.task_end - (await st(b)).now_ms);
  expect((await st(b)).buildings.buildings.find((x) => x.id === first.id).completed, 'done on its time, once').toBe(1);
  await shot({ page: b }, 'reopened', info);
  expect(errors).toEqual([]);
  await b.close();
});
