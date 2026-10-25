// Step 45: what three blind first-time players stumbled on, in the real
// build. The crops-for-dawn line under the EXP pill fits on the phone screen
// and says when it pays; the Momo's pencil holds still by its card; a level
// that opens buildings says which.
import { test, expect } from '../lib/fixtures.mjs';

test('the crops line fits the screen and says it pays at dawn', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_add_items', { crop: 1 });
  await expect.poll(async () => (await game.query('hud')).store.text || '', { timeout: 8_000 }).toBe('Crops 1 · +$5 at dawn');
  await game.page.waitForTimeout(300);
  const hud = await game.query('hud');
  const [x, , w] = hud.store.rect;
  expect(x, 'starts on screen').toBeGreaterThanOrEqual(0);
  expect(x + w, `ends on screen (${x + w} of ${hud.window[0]})`).toBeLessThanOrEqual(hud.window[0] + 1);
});

test('the pencil waits by the Momo card while the Momo walks', async ({ game }) => {
  const info = await game.query('momos');
  const box = await game.canvas.boundingBox();
  const body = info.momos['1'].body;
  await game.tap(body[0] * (box.width / info.window[0]), body[1] * (box.height / info.window[1]));
  await expect.poll(async () => (await game.query('watch')).pencil.length, { timeout: 5_000 }).toBe(4);
  const first = (await game.query('watch')).pencil;
  await game.page.waitForTimeout(2500);
  const later = (await game.query('watch')).pencil;
  expect(later, 'the pencil did not move').toEqual(first);
});

test('level 2 names what it opened', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_level', 2);
  const fx = await game.query('fx');
  expect(fx.celebration).toBe('Level 2');
  expect(fx.celebration_sub).toBe('Now open: Research lab · Lumberyard');
});
