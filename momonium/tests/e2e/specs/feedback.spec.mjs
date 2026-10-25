// Step 47: growth feedback is exact in the real build -- a real tap that
// harvests pops once over the farm (touch on phones, a click on desktop),
// time away caught up pops nothing, and Settings can switch effects off by a
// real tap (the harvest still happens, nothing pops).
import { test, expect } from '../lib/fixtures.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

async function farmReady(game) {
  await game.setTimeScale(0);
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  const b = async () => (await game.state()).buildings.buildings.find((x) => x.id === id);
  // Through sow and three waterings by command, to a ripe farm.
  for (let i = 0; i < 4; i++) {
    await game.command({ type: 'building.tap', id });
    for (let k = 0; k < 4 && (await b()).state !== 'idle'; k++) {
      const s = await game.state();
      const f = s.buildings.buildings.find((x) => x.id === id);
      const end = f.state === 'working' ? f.task_end : f.ready_at;
      await game.query('dev_advance_ms', Math.max(end - s.now_ms, 0) + 5);
    }
  }
  expect((await b()).stage).toBe(4);
  return { id, b };
}

async function harvestByTap(game, id, b) {
  const p = await clearPointOnCell(game, [1, 0]);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(100);
  const s = await game.state();
  const f = s.buildings.buildings.find((x) => x.id === id);
  expect(f.state, 'the tap started the harvest').toBe('working');
  await game.query('dev_advance_ms', f.task_end - s.now_ms + 5);
  expect((await b()).stage).toBe(0);
  // The merge window (0.45 s) passes on the page's own clock.
  await game.page.waitForTimeout(700);
}

const cropPops = (fx, id) => fx.world.filter((p) => p.key === `prod:${id}:crop`);

test('a real tap harvests once and pops once over the farm', async ({ game }) => {
  const { id, b } = await farmReady(game);
  const before = cropPops(await game.query('fx'), id).length;
  await harvestByTap(game, id, b);
  const fx = await game.query('fx');
  const pops = cropPops(fx, id);
  expect(pops.length - before, `one pop for one harvest (${JSON.stringify(pops)})`).toBe(1);
  expect(pops[pops.length - 1].text).toBe('+1');
});

test('time away caught up pops nothing', async ({ game }) => {
  await game.setTimeScale(0);
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  await game.command({ type: 'momo.assign', momo: 1, building: id });
  await game.page.waitForTimeout(700);
  const before = await game.query('fx');
  const r = await game.query('dev_away', 20 * 60 * 1000);
  expect(r.jobs, 'Momo worked while away').toBeGreaterThan(0);
  await game.page.waitForTimeout(700);
  const after = await game.query('fx');
  expect(after.world.length, 'no world pops for the catch-up').toBe(before.world.length);
  expect(after.hud.filter((t) => t.startsWith('+$') || t.endsWith('EXP')).length, 'no HUD pops for it').toBe(before.hud.filter((t) => t.startsWith('+$') || t.endsWith('EXP')).length);
});

test('effects off by a real tap in Settings: the harvest happens, nothing pops', async ({ game }) => {
  await game.query('set_language', 'en');
  const hud = await game.query('hud');
  const box = await game.canvas.boundingBox();
  const at = (r, win) => ({ x: (r[0] + r[2] / 2) * (box.width / win[0]), y: (r[1] + r[3] / 2) * (box.height / win[1]) });
  const gear = at(hud.buttons.settings, hud.window);
  await game.tap(gear.x, gear.y);
  await game.page.waitForTimeout(300);
  await game.query('dev_settings_reveal', 'Effects');
  await game.page.waitForTimeout(200);
  const st = await game.query('settings_ui');
  const toggle = at(st.toggles.effects, st.window);
  await game.tap(toggle.x, toggle.y);
  await game.page.waitForTimeout(200);
  expect((await game.query('fx')).effects, 'effects are off').toBe(false);
  await game.tap(gear.x, gear.y);
  await game.page.waitForTimeout(300);
  const { id, b } = await farmReady(game);
  const before = await game.query('fx');
  await harvestByTap(game, id, b);
  const after = await game.query('fx');
  expect((await game.state()).inventory.items.crop, 'the crop is in the store').toBeGreaterThan(0);
  expect(cropPops(after, id).length, 'but no pop').toBe(cropPops(before, id).length);
});
