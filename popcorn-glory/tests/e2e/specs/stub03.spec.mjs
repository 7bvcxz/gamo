// Step 03: the foundation in a real browser, on a 720x1280 touch screen, a
// phone and a desktop -- the chooser, the stub's press, upgrade, restart, back
// (the game's button and the browser's), a hidden tab, one finger = one press,
// and no browser storage.
import { test, expect } from '../lib/pop.mjs';

test('chooser opens the stub; press, upgrade, restart, back', async ({ pop }) => {
  await pop.open('./');
  let s = await pop.state();
  expect(s.screen).toBe('chooser');
  expect(s.listed).toContain('stub');
  await pop.shot('chooser');
  test.info().annotations.push({ type: 'load', description: `${pop.loadMs} ms to the first drawn frame` });

  await pop.tap('tile_stub');
  await expect.poll(async () => (await pop.state()).screen).toBe('play');
  expect(await pop.hash()).toBe('#stub');
  s = await pop.state();
  expect(s.run.money).toBe(0);

  // Ten real presses on the machine.
  for (let i = 0; i < 10; i++) await pop.tap('play');
  await expect.poll(async () => (await pop.state()).run.money).toBe(10);
  s = await pop.state();
  expect(s.run.presses, 'one finger is one press').toBe(10);
  expect(s.fx.peak, 'popcorn flew').toBeGreaterThan(0);
  await pop.shot('pressed');

  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.level).toBe(1);
  expect((await pop.state()).run.money).toBe(0);
  await pop.tap('play');
  await expect.poll(async () => (await pop.state()).run.money, { message: 'level 1 pops two' }).toBe(2);
  await pop.shot('upgraded');

  const log = await pop.call('log');
  const kinds = new Set(log.map((l) => l.type));
  for (const k of ['input', 'pop', 'earn', 'upgrade', 'milestone']) expect(kinds, `log has ${k}`).toContain(k);

  await pop.tap('restart');
  await expect.poll(async () => (await pop.state()).run.money).toBe(0);
  s = await pop.state();
  expect(s.run.level).toBe(0);
  expect(s.history).toBe(1);

  await pop.tap('back');
  await expect.poll(async () => (await pop.state()).screen).toBe('chooser');
  expect(await pop.hash()).toBe('');

  const storage = await pop.page.evaluate(() => Object.keys(localStorage).concat(Object.keys(sessionStorage)));
  expect(storage.filter((k) => !k.startsWith('popcorn-glory.')), 'no browser storage outside popcorn-glory.*').toEqual([]);
});

test('a direct link opens the stub, and the browser back button returns', async ({ pop }) => {
  await pop.open('./#stub');
  expect((await pop.state()).screen).toBe('play');
  await pop.tap('back');
  await expect.poll(async () => (await pop.state()).screen).toBe('chooser');
  await pop.tap('tile_stub');
  await expect.poll(async () => (await pop.state()).screen).toBe('play');
  await pop.page.goBack();
  await expect.poll(async () => (await pop.state()).screen).toBe('chooser');
});

test('a hidden tab stops the play clock', async ({ pop }) => {
  await pop.open('./#stub');
  await pop.page.waitForTimeout(1000);
  await pop.tab(true);
  const before = (await pop.state()).clock_ms;
  await pop.page.waitForTimeout(2500);
  const hidden = (await pop.state()).clock_ms;
  expect(hidden - before, 'no play time while hidden').toBeLessThanOrEqual(260);
  await pop.tab(false);
  await pop.page.waitForTimeout(1000);
  const after = (await pop.state()).clock_ms;
  expect(after - hidden, 'runs again when shown (the first frame counts at most 250 ms)').toBeGreaterThan(500);
  expect(after - hidden).toBeLessThan(1600);
});

test('three minutes shows the clock and is logged', async ({ pop }) => {
  await pop.open('./#stub');
  await pop.call('dev_advance', 180000);
  const sum = await pop.call('summary');
  expect(sum.milestones.three_minutes).toBeGreaterThanOrEqual(180000);
  await pop.page.waitForTimeout(300);
  await pop.shot('three_minutes');
});
