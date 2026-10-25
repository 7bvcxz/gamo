// Step 34: tap a Momo watching several buildings -- its route shows (numbered
// stops); the Route line in its card switches nearest -> row by row ->
// zigzag -> zone with real taps, saved in the island; the smart route opens
// once its research has a point; a few days later the card compares the jobs
// a day before and after the change.
import { test, expect } from '../lib/fixtures.mjs';

const toCss = async (game, p, win) => {
  const box = await game.canvas.boundingBox();
  return { x: p[0] * (box.width / win[0]), y: p[1] * (box.height / win[1]) };
};
const centre = (r) => [r[0] + r[2] / 2, r[1] + r[3] / 2];

test('switch a Momo route and compare', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_grow_island', 3);
  for (const c of [[0, 0], [2, 0], [0, 2], [2, 2]]) await game.query('dev_place_building', ['lumberyard', c[0], c[1]]);
  await game.command({ type: 'momo.watch', momo: 1, cells: [[0, 0], [2, 0], [0, 2], [2, 2]], op: 'add' });
  // A few days on the first route, so there is a "before" to compare with.
  await game.query('dev_advance_ms', 30000 * 3);
  await game.page.waitForTimeout(300);
  const m = await game.query('momos');
  const body = await toCss(game, m.momos['1'].body, m.window);
  await game.tap(body.x, body.y);
  await game.page.waitForTimeout(250);
  let r = await game.query('route');
  expect(r.stops.length).toBe(4);
  expect(r.label).toBe('Route: Nearest first');
  for (const want of ['rows', 'zigzag', 'zone']) {
    const p = await toCss(game, centre(r.button), r.window);
    await game.tap(p.x, p.y);
    await game.page.waitForTimeout(200);
    r = await game.query('route');
    expect(r.route).toBe(want);
  }
  expect((await game.state()).momo.momos.find((x) => x.id === 1).route).toBe('zone');
  // Smart: one point placed on its research opens it.
  await game.query('dev_research_levels', { smart_schedule: 1 });
  r = await game.query('route');
  let p = await toCss(game, centre(r.button), r.window);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(200);
  r = await game.query('route');
  expect(r.route).toBe('auto');
  // Days on both sides of the change: the card compares.
  await game.query('dev_advance_ms', 30000 * 4);
  await game.page.waitForTimeout(400);
  r = await game.query('route');
  expect(r.compare).toMatch(/jobs a day/);
});
