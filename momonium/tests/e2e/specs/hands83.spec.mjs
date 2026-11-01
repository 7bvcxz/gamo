// Step 83: the player's three hands in the real web build, by real taps (a
// finger on phones -- also the 720x1280 baseline -- the mouse on desktop).
// Tapping a farm, a mine and a lumberyard starts three jobs by hand, each
// with a glove and its own tool over it and no Momo; a fourth (the lab) is
// refused with a word over it, the card's chip warm, nothing spent; when one
// job ends the lab starts. A scheduled Momo still works with all three hands
// busy, and has no hands drawn. A panel opened over the hands covers them.
// With MOMONIUM_SHOTS set, saves the three hands and the refusal.
import { test, expect } from '../lib/fixtures.mjs';
import { logicalToCanvas } from '../lib/coords.mjs';

test.describe.configure({ timeout: 240_000 });

async function shot(game, info, name) {
  if (process.env.MOMONIUM_SHOTS) await game.page.screenshot({ path: `${process.env.MOMONIUM_SHOTS}/hands83_${info.project.name}_${name}.png` });
}

async function tapCell(game, cell) {
  const p = await logicalToCanvas(game, cell[0] + 0.5, cell[1] + 0.5);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(350);
  return game.query('selection');
}

const fresh = (s) => ({ money: s.economy.money, items: JSON.stringify(s.inventory) });

for (const shape of ['default', '720x1280']) {
  test.describe(shape, () => {
    if (shape === '720x1280') test.use({ viewport: { width: 360, height: 640 } });

    test('three jobs by hand, each with its tool; a fourth waits for a free hand', async ({ game }, info) => {
      test.skip(shape === '720x1280' && !info.project.use.hasTouch, 'the portrait baseline is a phone');
      await game.setTimeScale(0);
      await game.query('set_language', 'en');
      await game.query('dev_set_option', ['tips', false]);
      await game.query('dev_grow_island', 4);
      await game.query('dev_level', 20);
      const farm = { id: (await game.query('dev_place_building', ['farm', 0, 0])).id };
      expect(farm.id, 'a farm').toBeGreaterThan(0);
      const farmCell = [0, 0];
      const ids = {
        mine: (await game.query('dev_place_building', ['mine', 2, 0])).id,
        lumberyard: (await game.query('dev_place_building', ['lumberyard', 0, 2])).id,
        research: (await game.query('dev_place_building', ['research', 2, 2])).id,
      };
      await game.page.waitForTimeout(300);
      let h = await game.query('hands');
      expect(h.used, 'no hand busy').toBe(0);
      expect(h.limit).toBe(3);
      // Three by hand.
      const cells = [[farmCell, farm.id], [[2, 0], ids.mine], [[0, 2], ids.lumberyard]];
      for (let i = 0; i < cells.length; i++) {
        const sel = await tapCell(game, cells[i][0]);
        expect(sel.id, `the tap reached building ${cells[i][1]}`).toBe(cells[i][1]);
        h = await game.query('hands');
        expect(h.used, `${i + 1} hand(s) busy`).toBe(i + 1);
      }
      expect(h.hands.length, 'three hands drawn').toBe(3);
      expect(h.drawn, 'all on screen').toBe(3);
      const tools = Object.fromEntries(h.hands.map((x) => [x.type, x.tool]));
      expect(tools.mine, 'a pickaxe at the mine').toBe('pickaxe');
      expect(['axe', 'trowel']).toContain(tools.lumberyard);
      expect(['basket', 'seed_pouch', 'watering_can']).toContain(tools.farm);
      // Each hand over its own building.
      for (const x of h.hands) {
        const cx = x.rect[0] + x.rect[2] / 2;
        expect(Math.abs(cx - x.work[0]), `${x.type}: the hand near its work`).toBeLessThan(x.rect[2] * 1.5 + 40);
      }
      await game.setTimeScale(1);
      await game.page.waitForTimeout(700);
      await game.setTimeScale(0);
      await shot(game, info, `${shape}_three_hands`);
      // The fourth: refused, a word, nothing spent.
      const before = fresh(await game.state());
      const sel = await tapCell(game, [2, 2]);
      expect(sel.id, 'the lab selected').toBe(ids.research);
      expect(sel.result.reason, 'refused for want of a hand').toBe('err.manual_limit');
      h = await game.query('hands');
      expect(h.used, 'still three').toBe(3);
      expect(h.notes.at(-1), 'a word over the lab').toBe('Hands full: 3 jobs at once');
      expect(h.chip.shown, "the card's chip shows").toBe(true);
      expect(h.chip.full, 'warm: all hands busy').toBe(true);
      expect(fresh(await game.state()), 'nothing spent').toEqual(before);
      expect((await game.state()).buildings.buildings.find((b) => b.id === ids.research).state, 'the lab still idle').toBe('idle');
      await shot(game, info, `${shape}_fourth_waits`);
      // A job ends: the lab starts on the next tap.
      for (let i = 0; i < 600 && (await game.query('hands')).used >= 3; i++) await game.query('dev_advance_ms', 1000);
      expect((await game.query('hands')).used, 'a hand came free').toBeLessThan(3);
      const again = await tapCell(game, [2, 2]);
      expect(again.result.ok, 'the lab starts').toBe(true);
      h = await game.query('hands');
      expect(h.hands.some((x) => x.id === ids.research && x.tool === 'flask'), 'a flask at the lab').toBe(true);
    });
  });
}

test('a scheduled Momo works with every hand busy, and has no hands drawn; a panel covers the hands', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_set_option', ['tips', false]);
  await game.query('dev_grow_island', 4);
  await game.query('dev_level', 20);
  const farm = { id: (await game.query('dev_place_building', ['farm', 0, 0])).id };
  const mine = (await game.query('dev_place_building', ['mine', 2, 0])).id;
  const wood = (await game.query('dev_place_building', ['lumberyard', 0, 2])).id;
  const other = (await game.query('dev_place_building', ['farm', 3, 3])).id;
  for (const id of [farm.id, mine, wood]) await game.command({ type: 'building.tap', id });
  expect((await game.query('hands')).used).toBe(3);
  const momo = (await game.query('dev_add_momo', [2.5, 2.5])).id;
  const r = await game.command({ type: 'momo.watch', momo, cells: [[3, 3]], op: 'set', schedule: true });
  expect(r.ok, 'scheduled').toBe(true);
  let worked = false;
  for (let i = 0; i < 120 && !worked; i++) {
    await game.query('dev_advance_ms', 500);
    const b = (await game.state()).buildings.buildings.find((x) => x.id === other);
    worked = b.state === 'working' && b.worker === momo;
  }
  expect(worked, 'the Momo works its scheduled farm').toBe(true);
  const h = await game.query('hands');
  expect(h.hands.some((x) => x.id === other), "no hands over the Momo's work").toBe(false);
  expect(h.jobs.includes(other), "and it is not the player's job").toBe(false);
  // A panel over the hands: the island is busy, the hands stay in the world under it.
  const hud = await game.query('hud');
  const box = await game.canvas.boundingBox();
  const r2 = hud.buttons.settings;
  const x = (r2[0] + r2[2] / 2) * (box.width / hud.window[0]);
  const y = (r2[1] + r2[3] / 2) * (box.height / hud.window[1]);
  await game.tap(x, y);
  await game.page.waitForTimeout(450);
  const L = await game.query('layers');
  expect(L.busy, 'Settings open').toBe(true);
  expect(L.fx_layer, 'the world (and the hands in it) under the UI').toBeLessThan(L.ui_layer);
  await shot(game, info, 'settings_over_hands');
});
