// Step 45: what three blind first-time players stumbled on, in the real
// build. The line under the EXP pill fits on the phone screen (Step 50: it
// says what the island earned in the last minute); the Momo's pencil holds
// still by its card; a level that opens buildings says which.
import { test, expect } from '../lib/fixtures.mjs';

// Step 53: about what a Momo does -- the old starter Momo, explicitly.
test.use({ starterMomo: true });

test('the income line fits the screen and says per minute', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const { id } = await game.query('dev_place_building', ['farm', 0, 0]);
  for (let stage = 0; stage < 3; stage++) {
    let s = await game.state();
    let f = s.buildings.buildings.find((x) => x.id === id);
    if (f.state === 'cooldown') await game.query('dev_advance_ms', f.ready_at - s.now_ms + 5);
    await game.command({ type: 'building.tap', id });
    s = await game.state();
    f = s.buildings.buildings.find((x) => x.id === id);
    await game.query('dev_advance_ms', f.task_end - s.now_ms + 5);
  }
  await expect.poll(async () => (await game.query('hud')).store.text || '', { timeout: 8_000 }).toMatch(/^\+\$\d+\/min$/);
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
