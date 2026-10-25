// Step 05: the world starts as exactly a 2x2 grass island in open sea, with
// nothing built, and the island is on screen below the sky.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

test('a 2x2 island and nothing else', async ({ game }) => {
  const s = await game.state();
  const cells = s.world.land.map(([x, y]) => `${x},${y}`).sort();
  expect(cells).toEqual(['0,0', '0,1', '1,0', '1,1']);
  expect(s.world.occupants).toEqual([]);
  expect(s.economy.money).toBe(10);
});

test('the island sits in the lower three fifths of the screen', async ({ game }) => {
  const box = await game.canvas.boundingBox();
  for (const cell of [[0, 0], [1, 0], [0, 1], [1, 1]]) {
    const p = await cellToCanvas(game, cell);
    expect(p.x).toBeGreaterThan(0);
    expect(p.x).toBeLessThan(box.width);
    expect(p.y).toBeGreaterThan(box.height * 0.4);
    expect(p.y).toBeLessThan(box.height);
  }
});
