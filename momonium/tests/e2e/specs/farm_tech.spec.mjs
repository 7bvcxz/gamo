// Step 23: with farming research done, the player sows by tapping the farm, a
// drip line does all three waterings by itself, the harvest still needs a
// tap, and after it the farm's details let millet (two waterings) be chosen.
import { test, expect } from '../lib/fixtures.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('a drip line waters, hands harvest, millet next', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  await game.query('dev_research_done', ['farm_expansion', 'watering_efficiency', 'harvest_boost', 'watering_can', 'drip_irrigation', 'seed_selection', 'drought_millet']);
  await game.page.waitForTimeout(200);
  const farmAt = async () => clearPointOnCell(game, [1, 0]);
  let f = await farmAt();
  await game.tap(f.x, f.y);
  await game.page.waitForTimeout(200);
  let farm = (await game.state()).buildings.buildings.find((b) => b.id === id);
  expect(farm.state).toBe('working');
  expect(farm.worker).toBe(0);
  // Open the details from the farm's name.
  let p = await game.query('panels');
  const title = await centre(game, p.context_title, p.window);
  await game.tap(title.x, title.y);
  await game.page.waitForTimeout(200);
  let d = await game.query('details');
  expect(d.open).toBe(true);
  expect(d.varieties.millet.disabled).toBe(true);
  await game.query('dev_advance_ms', 5000 + 1000);
  d = await game.query('details');
  expect(d.workers[0]).toBe('auto');
  // Three waterings and their waits (18 s each with mulch and drip).
  await game.query('dev_advance_ms', 63000);
  farm = (await game.state()).buildings.buildings.find((b) => b.id === id);
  expect(farm.stage).toBe(4);
  expect(farm.state).toBe('idle');
  // Hands harvest: close the details, tap the farm.
  await game.page.keyboard.press('Escape').catch(() => {});
  p = await game.query('panels');
  if (p.detail_open) {
    const close = await centre(game, p.close, p.window);
    await game.tap(close.x, close.y);
  }
  await game.page.waitForTimeout(150);
  f = await farmAt();
  await game.tap(f.x, f.y);
  await game.query('dev_advance_ms', 5000);
  let s = await game.state();
  farm = s.buildings.buildings.find((b) => b.id === id);
  expect(farm.stage).toBe(0);
  expect(s.inventory.items.crop).toBe(3);
  // Next cycle: millet.
  p = await game.query('panels');
  const t2 = await centre(game, p.context_title, p.window);
  await game.tap(t2.x, t2.y);
  await game.page.waitForTimeout(200);
  d = await game.query('details');
  expect(d.varieties.millet.disabled).toBe(false);
  const m = await centre(game, d.varieties.millet.rect, d.window);
  await game.tap(m.x, m.y);
  await game.page.waitForTimeout(150);
  s = await game.state();
  expect(s.buildings.buildings.find((b) => b.id === id).variety).toBe('millet');
});
