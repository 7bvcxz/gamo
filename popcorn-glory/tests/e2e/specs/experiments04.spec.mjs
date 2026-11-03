// Step 04: the three experiments with real input on 720x1280 touch, a phone
// and a desktop -- each opens from its chooser tile and from its direct link,
// its main action works the way it is meant to, it restarts from nothing, and
// one run never leaks into another.
import { test, expect } from '../lib/pop.mjs';

test('the chooser lists A, B, C and each tile opens its experiment', async ({ pop }) => {
  await pop.open('./');
  const s = await pop.state();
  expect(s.listed).toEqual(['click', 'perfect', 'explosion']);
  await pop.shot('chooser04');
  for (const id of ['click', 'perfect', 'explosion']) {
    await pop.tap(`tile_${id}`);
    await expect.poll(async () => (await pop.state()).exp).toBe(id);
    expect(await pop.hash()).toBe(`#${id}`);
    expect((await pop.state()).run.money).toBe(0);
    await pop.tap('back');
    await expect.poll(async () => (await pop.state()).screen).toBe('chooser');
  }
});

test('A Click & Pop: every press pays at once', async ({ pop }) => {
  await pop.open('./#click');
  for (let i = 0; i < 12; i++) await pop.tap('play');
  await expect.poll(async () => (await pop.state()).run.money).toBe(12);
  expect((await pop.state()).run.presses).toBe(12);
  await pop.shot('a_pressed');
  await pop.tap('restart');
  await expect.poll(async () => (await pop.state()).run.money).toBe(0);
});

test('B Perfect Pop: holding into the gold pays double; a quick tap is early', async ({ pop }) => {
  await pop.open('./#perfect');
  // The gold is 1400-1850 ms after the press at level 0: hold for 1625.
  await pop.hold('play', 1625);
  await expect.poll(async () => (await pop.state()).run.outcomes.perfect, { message: 'released in the gold' }).toBe(1);
  expect((await pop.state()).run.money).toBe(10);
  await pop.page.waitForTimeout(500);
  await pop.tap('play');
  await expect.poll(async () => (await pop.state()).run.outcomes.early, { message: 'a tap is early' }).toBe(1);
  const log = await pop.call('log');
  expect(log.filter((l) => l.type === 'input').length, 'a press and its release are one input').toBe(2);
  await pop.shot('b_after');
});

test('B Perfect Pop: holding on burns by itself and never locks', async ({ pop }) => {
  await pop.open('./#perfect');
  await pop.hold('play', 3200);
  await expect.poll(async () => (await pop.state()).run.outcomes.burnt).toBe(1);
  await pop.page.waitForTimeout(500);
  await pop.hold('play', 1625);
  await expect.poll(async () => (await pop.state()).run.outcomes.perfect, { message: 'the next hold works' }).toBe(1);
});

test('C Pop Explosion: eight presses erupt, drawn pieces stay under the cap', async ({ pop }) => {
  await pop.open('./#explosion');
  for (let i = 0; i < 7; i++) await pop.tap('play');
  await expect.poll(async () => (await pop.state()).run.loaded).toBe(7);
  expect((await pop.state()).run.money).toBe(0);
  await pop.shot('c_loaded');
  await pop.tap('play');
  await expect.poll(async () => (await pop.state()).run.money).toBe(10);
  await pop.page.waitForTimeout(400);
  await pop.shot('c_erupt');
  const s = await pop.state();
  expect(s.fx.peak).toBeLessThanOrEqual(s.fx.cap);
});

test('runs never leak between experiments', async ({ pop }) => {
  await pop.open('./#click');
  for (let i = 0; i < 5; i++) await pop.tap('play');
  await expect.poll(async () => (await pop.state()).run.money).toBe(5);
  await pop.tap('back');
  await pop.tap('tile_explosion');
  await expect.poll(async () => (await pop.state()).exp).toBe('explosion');
  let s = await pop.state();
  expect(s.run.money).toBe(0);
  expect(s.run.presses).toBe(0);
  await pop.page.goBack();
  await expect.poll(async () => (await pop.state()).screen).toBe('chooser');
  await pop.tap('tile_click');
  await expect.poll(async () => (await pop.state()).exp).toBe('click');
  s = await pop.state();
  expect(s.run.money, 'A again from nothing').toBe(0);
});
