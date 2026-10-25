// Step 48: a Momo's mood in the real build -- read from the job rules, one
// small bubble over its head, shown a few seconds after the reason settles
// and then resting; it takes no taps (the Momo under it still selects).
import { test, expect } from '../lib/fixtures.mjs';

const wait = (game, ms) => game.page.waitForTimeout(ms);

test('a free Momo shows one heart, briefly', async ({ game }) => {
  // Let it wander until it stands still (free time), then hold the clock.
  await expect.poll(async () => (await game.query('moods'))['1'].reason, { timeout: 30_000 }).toBe('free');
  await game.setTimeScale(0);
  await expect.poll(async () => (await game.query('moods'))['1'].mood, { timeout: 8_000 }).toBe('content');
  const m = await game.query('moods');
  expect(m['1'].visible).toBe(true);
  for (const id of Object.keys(m)) expect(m[id].bubbles, `Momo ${id}: one bubble`).toBe(1);
  // Shown for a few seconds, then it rests (no permanent sign).
  await expect.poll(async () => (await game.query('moods'))['1'].mood, { timeout: 8_000 }).toBe('');
  expect((await game.query('moods'))['1'].shown).toBe(1);
});

test('a Momo short of ore shows a sweat drop and is still tapped through it', async ({ game }) => {
  await game.setTimeScale(0);
  const { id } = await game.query('dev_place_building', ['smelter', 1, 0]);
  await game.command({ type: 'momo.assign', momo: 1, building: id });
  for (let i = 0; i < 40 && (await game.query('moods'))['1'].reason !== 'short'; i++) {
    await game.query('dev_advance_ms', 500);
  }
  expect((await game.query('moods'))['1'].reason, 'no ore in the store').toBe('short');
  await expect.poll(async () => (await game.query('moods'))['1'].mood, { timeout: 8_000 }).toBe('worried');
  // A real tap on the Momo selects it: the bubble over its head takes no input.
  const info = await game.query('momos');
  const box = await game.canvas.boundingBox();
  const body = info.momos['1'].body;
  await game.tap(body[0] * (box.width / info.window[0]), body[1] * (box.height / info.window[1]));
  await wait(game, 300);
  expect((await game.query('momos')).selected).toBe('momo');
});
