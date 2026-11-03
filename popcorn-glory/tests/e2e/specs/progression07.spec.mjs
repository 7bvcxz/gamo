// Step 07: progression checks on the real build. FAST-FORWARD: these use the
// dev clock hook (dev_advance) to jump play time -- they test that milestones,
// restarts, switching and re-entry behave, NOT what a newcomer experiences in
// real time (that is play180.spec.mjs, and Step 08's blind play).
import { test, expect } from '../lib/pop.mjs';

test('FAST-FORWARD: milestones in order through 3:00', async ({ pop }) => {
  test.info().annotations.push({ type: 'mode', description: 'fast-forward with dev_advance (not real-time play)' });
  await pop.open('./#click');
  await pop.call('dev_advance', 2000);
  for (let i = 0; i < 40; i++) await pop.tap('play');
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.level).toBeGreaterThanOrEqual(1);
  await pop.call('dev_advance', 180000);
  const sum = await pop.call('summary');
  const m = sum.milestones;
  for (const k of ['first_input', 'first_earn', 'first_affordable', 'first_upgrade', 'three_minutes']) expect(m[k], k).toBeGreaterThanOrEqual(0);
  expect(m.first_input).toBeLessThanOrEqual(m.first_earn);
  expect(m.first_earn).toBeLessThanOrEqual(m.first_affordable);
  expect(m.first_affordable).toBeLessThanOrEqual(m.first_upgrade);
  expect(m.three_minutes).toBeGreaterThanOrEqual(180000);
});

test('ten restarts in a row: each from nothing, no errors', async ({ pop }) => {
  await pop.open('./#explosion');
  for (let r = 0; r < 10; r++) {
    for (let i = 0; i < 9; i++) await pop.tap('play');
    await pop.tap('restart');
    await expect.poll(async () => (await pop.state()).run.money).toBe(0);
    const s = await pop.state();
    expect(s.run.loaded, `restart ${r}: empty chamber`).toBe(0);
    expect(s.run.level).toBe(0);
  }
  expect((await pop.state()).history).toBe(10);
});

test('an unusual order: A, C, B, A again, by tiles, links and the back button', async ({ pop }) => {
  await pop.open('./');
  await pop.tap('tile_click');
  await expect.poll(async () => (await pop.state()).exp).toBe('click');
  for (let i = 0; i < 3; i++) await pop.tap('play');
  await pop.page.evaluate(() => { location.hash = '#explosion'; });
  await expect.poll(async () => (await pop.state()).exp).toBe('explosion');
  expect((await pop.state()).run.money, 'C from nothing').toBe(0);
  await pop.tap('back');
  await pop.tap('tile_perfect');
  await expect.poll(async () => (await pop.state()).exp).toBe('perfect');
  await pop.page.goBack();
  await expect.poll(async () => (await pop.state()).screen).toBe('chooser');
  await pop.tap('tile_click');
  await expect.poll(async () => (await pop.state()).exp).toBe('click');
  const s = await pop.state();
  expect(s.run.money, 'A re-entered from nothing').toBe(0);
  expect(s.history, 'three finished runs this visit').toBe(3);
});
