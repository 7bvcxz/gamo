// Step 09: one 30-second day runs Day 1 -> Day 2 on the simulation clock.
// Step 56: there is no sky -- the time of day is in the sea. Measured at the
// top of the screen, where the sky used to be: fresh blue by day, warmer at
// sunset, deep navy at night.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

// The water at the top of the screen, between the Day panel and the money
// card: a patch averaged, so a glint or a sparkle does not decide it.
async function topWater(game) {
  const png = decodePng(await game.canvas.screenshot());
  const sum = [0, 0, 0];
  let n = 0;
  for (let y = png.height * 0.02; y < png.height * 0.06; y += 2) {
    for (let x = png.width * 0.3; x < png.width * 0.5; x += 2) {
      const p = pixel(png, x, y);
      for (let i = 0; i < 3; i++) sum[i] += p[i];
      n += 1;
    }
  }
  return sum.map((v) => Math.round(v / n));
}

test('day, sunset and night are in the water', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_advance_to', [1, 0.3]);
  await game.page.waitForTimeout(250);
  expect((await game.query('day_look')).phase).toBe('day');
  const day = await topWater(game);
  expect(day[2], `day water ${day} is blue`).toBeGreaterThan(day[0] + 60);

  await game.query('dev_advance_to', [1, 0.62]);
  await game.page.waitForTimeout(250);
  expect((await game.query('day_look')).phase).toBe('sunset');
  const sunset = await topWater(game);
  expect(sunset[0], `sunset water ${sunset} is warmer than midday`).toBeGreaterThan(day[0] + 40);

  await game.query('dev_advance_to', [1, 0.86]);
  await game.page.waitForTimeout(250);
  expect((await game.query('day_look')).phase).toBe('night');
  const night = await topWater(game);
  expect(night[0] + night[1] + night[2], `night water ${night} is dark`).toBeLessThan(300);
  expect(night[2], `and navy blue, not grey (${night})`).toBeGreaterThan(night[0] + 50);
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
