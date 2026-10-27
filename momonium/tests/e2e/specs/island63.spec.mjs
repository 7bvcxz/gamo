// Step 63: a City's island grows up, in the real web build. The same island
// under the same camera: as a Village the water reaches its cliffs; promoted
// to a City, half a tile of bank -- warm sand and turf, not sea -- lies in
// front of every coast, the grass a touch warmer; land bought afterwards gets
// its bank too; a Nation keeps the look; a reload shows it at once. The
// tiles a tap reaches and the land on offer do not move.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

const SHAPE = [[2, 0], [3, 0], [2, 1], [3, 1], [0, 2], [1, 2], [2, 2], [3, 2], [0, 3], [2, 3], [3, 3]];

async function at(game, logical, z = 0) {
  const p = await game.query('logical_screen', [logical[0], logical[1], z]);
  return [p.x, p.y, p.window];
}

// The colour a little way out from a coast, averaged over a few pixels.
async function sample(game, logical, z) {
  const [x, y, win] = await at(game, logical, z);
  const png = decodePng(await game.page.screenshot());
  const sx = png.width / win[0];
  const sy = png.height / win[1];
  const sum = [0, 0, 0];
  let n = 0;
  for (let dy = -3; dy <= 3; dy += 3) {
    for (let dx = -3; dx <= 3; dx += 3) {
      const p = pixel(png, Math.round((x + dx) * sx), Math.round((y + dy) * sy));
      for (let i = 0; i < 3; i++) sum[i] += p[i];
      n += 1;
    }
  }
  return sum.map((v) => v / n);
}

test('a City has a bank where a Village has water; the look stays and follows the land', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_advance_to', [1, 0.3]);
  await game.query('dev_add_land', SHAPE);
  await game.page.waitForTimeout(700);
  const cam = await game.query('camera');
  let s = await game.query('island');
  expect(s.city).toBe(false);
  expect(s.bank_quads).toBe(0);
  expect(s.shore_apron).toBe(0);
  const offers = (await game.query('land_buy')).invite;
  // 0.3 tile out from the near-right coast of (3, 1), on the bank's surface
  // there (water in front of a Village's cliff; sand on a City's bank).
  const spot = [4.3, 1.5];
  const village = await sample(game, spot, -0.402);
  await game.page.screenshot({ path: info.outputPath('village.png') });
  await game.query('dev_tier', 1);
  await game.page.waitForTimeout(1600);
  s = await game.query('island');
  expect(s.city, 'a City').toBe(true);
  expect(s.city_t, 'the change has played').toBe(1);
  expect(s.bank_quads).toBeGreaterThan(50);
  expect(s.shore_apron, 'the sea draws its coast at the bank foot').toBe(0.5);
  await game.page.screenshot({ path: info.outputPath('city.png') });
  const city = await sample(game, spot, -0.402);
  // Village: open water there (blue over red); City: sand or turf (red over blue).
  expect(village[2] - village[0], `water as a Village: ${village.map(Math.round)}`).toBeGreaterThan(40);
  expect(city[0] - city[2], `bank as a City: ${city.map(Math.round)}`).toBeGreaterThan(10);
  const cam2 = await game.query('camera');
  expect([cam2.x, cam2.y, cam2.zoom]).toEqual([cam.x, cam.y, cam.zoom]);
  // Nothing moved for the hand.
  expect((await game.query('land_buy')).invite, 'the same land on offer').toEqual(offers);
  // Land bought now gets its bank at once.
  await game.query('dev_add_land', [[4, 1]]);
  await game.page.waitForTimeout(500);
  const grown = await sample(game, [5.3, 1.5], -0.402);
  expect(grown[0] - grown[2], `the new coast has a bank: ${grown.map(Math.round)}`).toBeGreaterThan(10);
  // A Nation keeps it.
  await game.query('dev_tier', 2);
  await game.page.waitForTimeout(400);
  expect((await game.query('island')).city).toBe(true);
});

test('the City look comes back with the island after a reload', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_add_land', SHAPE);
  await game.query('dev_tier', 1);
  await game.page.waitForTimeout(1500);
  await game.query('save_now');
  const page = await game.page.context().newPage();
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.call === 'function', null, { timeout: 90_000 });
  await page.waitForTimeout(500);
  const s = await page.evaluate(() => window.momonium.call('island'));
  expect(s.tier).toBe(1);
  expect(s.city, 'a City at once').toBe(true);
  expect(s.city_t).toBe(1);
  expect(s.bank_quads).toBeGreaterThan(50);
});
