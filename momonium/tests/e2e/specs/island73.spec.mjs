// Step 73: Village, City and Nation look different at a glance, in the real
// web build. One irregular island (a notch, a cove, a lake) under one camera:
// a Village's water at its cliffs and grass at its coast; a City's sandy bank
// and a sandy footpath inside the coast; a Nation's stone bank and stone
// promenade with lamps. Each promotion fades from one look to the next. The
// tiles a tap reaches and the land on offer never move; land bought later
// gets the look at once; a reload shows it at once.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

// Cells added to the start (2x2 at 0..1): an irregular island with a lake at (3, 2).
const SHAPE = [[2, 0], [3, 0], [4, 0], [2, 1], [3, 1], [4, 1], [5, 1], [0, 2], [1, 2], [2, 2], [4, 2], [5, 2],
  [0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [1, 4], [2, 4], [3, 4]];

async function sample(game, logical, z) {
  const p = await game.query('logical_screen', [logical[0], logical[1], z]);
  const png = decodePng(await game.page.screenshot());
  const sx = png.width / p.window[0];
  const sy = png.height / p.window[1];
  const sum = [0, 0, 0];
  let n = 0;
  for (let dy = -2; dy <= 2; dy += 2) {
    for (let dx = -2; dx <= 2; dx += 2) {
      const c = pixel(png, Math.round((p.x + dx) * sx), Math.round((p.y + dy) * sy));
      for (let i = 0; i < 3; i++) sum[i] += c[i];
      n += 1;
    }
  }
  return sum.map((v) => v / n);
}

const greenish = (c) => c[1] - Math.max(c[0], c[2]);
const sandy = (c) => c[0] - c[2];
const grey = (c) => Math.max(...c) - Math.min(...c);

test('Village, City and Nation: three islands at a glance, nothing moved for the hand', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('dev_advance_to', [1, 0.3]);
  await game.query('dev_add_land', SHAPE);
  for (const [t, x, y] of [['farm', 2, 0], ['lumberyard', 4, 1], ['research', 1, 3]]) await game.query('dev_place_building', [t, x, y]);
  await game.page.waitForTimeout(800);
  const cam = await game.query('camera');
  const offers = (await game.query('land_buy')).invite;
  // A free coast cell (5, 2): its near-right coast edge at x = 6.
  const bankSpot = [6.3, 2.5];
  const pathSpot = [5.95, 2.5];
  let s = await game.query('island');
  expect([s.look, s.path_quads, s.lamps]).toEqual([0, 0, 0]);
  await game.page.screenshot({ path: info.outputPath('village.png') });
  const vBank = await sample(game, bankSpot, -0.402);
  const vPath = await sample(game, pathSpot, 0);

  await game.query('dev_tier', 1);
  await game.page.waitForTimeout(450);
  s = await game.query('island');
  expect(s.look_t, 'the change plays').toBeGreaterThan(0);
  expect(s.look_t).toBeLessThan(1);
  await game.page.screenshot({ path: info.outputPath('village_to_city.png') });
  await game.page.waitForTimeout(1200);
  s = await game.query('island');
  expect([s.look, s.look_t]).toEqual([1, 1]);
  expect(s.path_quads, 'a footpath round the coast').toBeGreaterThan(10);
  expect(s.lamps, 'no lamps in a City').toBe(0);
  expect(s.beds, 'flowerbeds and hedges').toBeGreaterThan(0);
  await game.page.screenshot({ path: info.outputPath('city.png') });
  const cBank = await sample(game, bankSpot, -0.402);
  const cPath = await sample(game, pathSpot, 0);

  await game.query('dev_tier', 2);
  await game.page.waitForTimeout(450);
  s = await game.query('island');
  expect(s.look_t, 'City to Nation plays too').toBeLessThan(1);
  await game.page.screenshot({ path: info.outputPath('city_to_nation.png') });
  await game.page.waitForTimeout(1200);
  s = await game.query('island');
  expect([s.look, s.look_t]).toEqual([2, 1]);
  expect(s.lamps, 'lamps on the promenade').toBeGreaterThan(3);
  await game.page.screenshot({ path: info.outputPath('nation.png') });
  const nBank = await sample(game, bankSpot, -0.402);
  const nPath = await sample(game, pathSpot, 0);

  // The coast: water for a Village, sand for a City, stone for a Nation.
  expect(vBank[2] - vBank[0], `Village: water (${vBank.map(Math.round)})`).toBeGreaterThan(40);
  expect(sandy(cBank), `City: sand (${cBank.map(Math.round)})`).toBeGreaterThan(10);
  expect(grey(nBank), `Nation: stone, not sand (${nBank.map(Math.round)})`).toBeLessThan(grey(cBank));
  // Inside the coast: grass, a sandy path, a pale stone promenade.
  expect(greenish(vPath), `Village: grass (${vPath.map(Math.round)})`).toBeGreaterThan(10);
  expect(sandy(cPath), `City: a sandy path (${cPath.map(Math.round)})`).toBeGreaterThan(20);
  expect(grey(nPath), `Nation: pale stone (${nPath.map(Math.round)})`).toBeLessThan(45);
  expect(Math.min(...nPath), 'and light').toBeGreaterThan(150);

  // Nothing moved for the hand.
  const cam2 = await game.query('camera');
  expect([cam2.x, cam2.y, cam2.zoom]).toEqual([cam.x, cam.y, cam.zoom]);
  expect((await game.query('land_buy')).invite, 'the same land on offer').toEqual(offers);

  // Land bought now gets the look at once.
  const before = s.path_quads;
  await game.query('dev_add_land', [[6, 1], [6, 2]]);
  await game.page.waitForTimeout(500);
  s = await game.query('island');
  expect(s.path_quads, 'the new coast has its promenade').toBeGreaterThan(before - 2);
  const grown = await sample(game, [7.3, 1.5], -0.402);
  expect(grey(grown), `and its stone bank (${grown.map(Math.round)})`).toBeLessThan(grey(cBank));

  // A reload shows the Nation's look at once.
  await game.query('save_now');
  const page = await game.page.context().newPage();
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.call === 'function', null, { timeout: 90_000 });
  await page.waitForTimeout(500);
  const r = await page.evaluate(() => window.momonium.call('island'));
  expect([r.tier, r.look, r.look_t]).toEqual([2, 2, 1]);
  expect(r.lamps).toBeGreaterThan(3);
});
