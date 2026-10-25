// Step 09: one 30-second day runs Day 1 -> Day 2 on the simulation clock, and
// the sky band (top 2/5) shows day, sunset and night at the right moments.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

async function skyPixel(game) {
  const png = decodePng(await game.canvas.screenshot());
  // Top of the sky between the Day panel and the money pill (the HUD owns the
  // corners since Step 10), above the clouds and left of the sun's noon spot.
  return pixel(png, png.width * 0.33, png.height * 0.025);
}

test('day, sunset and night follow the clock', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_advance_to', [1, 0.3]);
  await game.page.waitForTimeout(250);
  expect((await game.query('sky')).phase).toBe('day');
  const day = await skyPixel(game);
  expect(day[2], `day sky ${day} is blue`).toBeGreaterThan(day[0] + 60);

  await game.query('dev_advance_to', [1, 0.62]);
  await game.page.waitForTimeout(250);
  expect((await game.query('sky')).phase).toBe('sunset');
  const sunset = await skyPixel(game);
  expect(sunset[0], `sunset sky ${sunset} is warmer than midday`).toBeGreaterThan(day[0] + 40);

  await game.query('dev_advance_to', [1, 0.86]);
  await game.page.waitForTimeout(250);
  expect((await game.query('sky')).phase).toBe('night');
  const night = await skyPixel(game);
  expect(night[0] + night[1] + night[2], `night sky ${night} is dark`).toBeLessThan(200);
});

test('the day counter rolls over after 30 simulated seconds', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_advance_to', [1, 0.99]);
  expect((await game.state()).day).toBe(1);
  await game.query('dev_advance_to', [2, 0.0]);
  const s = await game.state();
  expect(s.day).toBe(2);
  expect(s.time_in_day_ms).toBe(0);
});
