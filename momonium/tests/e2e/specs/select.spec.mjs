// Step 11: a real tap on a farm starts its work at once and selects it; the
// work finishes on the simulation clock while something else is selected; a
// tile selects, open sea deselects; the panel's card is a second way to start.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

test('tap a farm, select elsewhere, the work still finishes', async ({ game }) => {
  await game.setTimeScale(0);
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  expect(id).toBeGreaterThan(0);
  await game.page.waitForTimeout(150);
  const farm = await cellToCanvas(game, [1, 0]);
  await game.tap(farm.x, farm.y);
  await game.page.waitForTimeout(150);
  let s = await game.query('selection');
  expect(s.kind).toBe('building');
  expect(s.id).toBe(id);
  let b = (await game.state()).buildings.buildings.find((x) => x.id === id);
  expect(b.state).toBe('working');

  const tile = await cellToCanvas(game, [0, 1]);
  await game.tap(tile.x, tile.y);
  await game.page.waitForTimeout(150);
  s = await game.query('selection');
  expect(s.kind).toBe('tile');
  expect(s.cell).toEqual([0, 1]);

  await game.setTimeScale(10);
  await expect.poll(async () => (await game.state()).buildings.buildings.find((x) => x.id === id).completed, { timeout: 10_000 }).toBe(1);
  await game.setTimeScale(0);

  const sea = await cellToCanvas(game, [6, -3]);
  const box = await game.canvas.boundingBox();
  await game.tap(Math.min(Math.max(sea.x, 5), box.width - 5), Math.min(Math.max(sea.y, box.height * 0.45), box.height - 5));
  await game.page.waitForTimeout(150);
  expect((await game.query('selection')).kind).toBe('');
});

test('the stage card starts the next stage', async ({ game }) => {
  await game.setTimeScale(0);
  const { id } = await game.query('dev_place_building', ['farm', 0, 0]);
  const farm = await cellToCanvas(game, [0, 0]);
  await game.tap(farm.x, farm.y);
  await game.setTimeScale(10);
  await expect.poll(async () => (await game.state()).buildings.buildings.find((x) => x.id === id).state, { timeout: 10_000 }).toBe('idle');
  await game.setTimeScale(0);
  const s = await game.query('selection');
  expect(s.cards.length).toBeGreaterThan(0);
  const box = await game.canvas.boundingBox();
  const [x, y, w, h] = s.cards[0];
  await game.tap((x + w / 2) * (box.width / s.window[0]), (y + h / 2) * (box.height / s.window[1]));
  await game.page.waitForTimeout(150);
  const b = (await game.state()).buildings.buildings.find((x2) => x2.id === id);
  expect(b.state).toBe('working');
  expect(b.completed).toBe(1);
});
