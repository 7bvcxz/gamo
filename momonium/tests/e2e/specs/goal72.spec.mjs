// Step 72: one distant goal, one place. A new island's chip says "Next: City
// 0/4" and opens Status on the same goal with the road drawn; at Nation the
// chip turns to the Golden Age with what is met; meeting it celebrates once,
// raises gold pennants on every building, and the Civilization takes its
// place. The view fits the screen.
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

const openFromChip = async (game) => {
  const hud = await game.query('hud');
  const g0 = await game.query('goal');
  const c = await centre(game, g0.chip_rect, hud.window);
  await game.tap(c.x, c.y);
  await game.page.waitForTimeout(400);
  return game.query('goal');
};

const closeStatus = async (game) => {
  const p = await game.query('panels');
  const hud = await game.query('hud');
  const c = await centre(game, p.close, hud.window);
  await game.tap(c.x, c.y);
  await game.page.waitForTimeout(250);
};

const fits = (g) => {
  const v = g.view;
  for (const r of g.rows) {
    expect(r[0] >= v[0] - 1 && r[0] + r[2] <= v[0] + v[2] + 1, 'a condition row inside the view').toBe(true);
  }
  expect(g.ladder[0] >= v[0] - 1 && g.ladder[0] + g.ladder[2] <= v[0] + v[2] + 1, 'the road inside the view').toBe(true);
};

test('one distant goal: City, Nation, a Golden Age, then the Civilization', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');

  let g = await game.query('goal');
  expect(g.chip, 'a new island').toBe('Next: City 0/4');
  expect(g.steps.map((s) => s.state)).toEqual(['done', 'current', 'ahead', 'ahead', 'ahead']);
  g = await openFromChip(game);
  expect(g.view.length, 'the chip opens the goal on Status').toBe(4);
  expect(g.next).toBe('Next: City');
  fits(g);
  await game.page.screenshot({ path: info.outputPath('early.png') });
  await closeStatus(game);

  await game.query('dev_tier', 2);
  g = await game.query('goal');
  expect(g.current.id).toBe('golden_age');
  expect(g.chip, 'the Nation met, one of three').toBe('Next: Golden Age 1/3');
  g = await openFromChip(game);
  expect(g.next).toBe('Next: Golden Age');
  expect(g.rows.length, 'three conditions').toBe(3);
  fits(g);
  await game.page.screenshot({ path: info.outputPath('mid.png') });
  await closeStatus(game);

  for (let i = 0; i < 10; i++) await game.query('dev_add_momo', [0.4 + (i % 4) * 0.4, 0.6 + Math.floor(i / 4) * 0.5]);
  await game.query('dev_research_done', ['combine_harvester', 'coppice_woodland']);
  await game.page.waitForTimeout(300);
  g = await game.query('goal');
  expect(g.reached).toContain('golden_age');
  expect(g.celebrating, 'a brief celebration').toBe(true);
  expect(g.golden, 'gold pennants on every building').toBe(g.buildings);
  expect(g.chip, 'the next distant goal at once').toBe('Next: Civilization 1/3');
  await game.page.screenshot({ path: info.outputPath('reached.png') });
  await game.page.waitForTimeout(4000);
  g = await openFromChip(game);
  expect(g.next).toBe('Next: Civilization');
  expect(g.steps.map((s) => s.state), 'the road: the Golden Age reached').toEqual(['done', 'done', 'done', 'done', 'current']);
  fits(g);
  await game.page.screenshot({ path: info.outputPath('late.png') });
});
