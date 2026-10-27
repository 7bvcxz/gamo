// Step 67: in the real web build a Momo at work moves -- with the simulation
// stopped (nothing finishes, nothing advances) its job still plays four
// different frames in order, on the screen's own clock; off work it stops.
// With MOMONIUM_SHOTS set, records a short clip of the island at work.
import { test, expect } from '../lib/fixtures.mjs';

test.use({ starterMomo: true });

const momo = async (game, id = 1) => (await game.query('momos')).momos[String(id)];

test('a working Momo plays its job in four frames', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_grow_island', 3);
  const { id: mine } = await game.query('dev_place_building', ['mine', 2, 1]);
  expect((await game.command({ type: 'momo.assign', momo: 1, building: mine })).ok).toBe(true);
  let m;
  for (let i = 0; i < 200; i++) {
    await game.query('dev_advance_ms', 300);
    m = await momo(game);
    if (m.state === 'work') break;
  }
  expect(m.state).toBe('work');
  // The clock stopped: the simulation does nothing, Momo still swings.
  const before = await game.query('dev_advance_ms', 0);
  const order = [];
  // The swing frame lasts a tenth of a second and a look through the bridge
  // can take longer: look until all four have shown (at most eight seconds).
  for (let i = 0; i < 160 && new Set(order).size < 4; i++) {
    await game.page.waitForTimeout(40);
    const c = (await momo(game)).cell;
    if (order[order.length - 1] !== c) order.push(c);
  }
  const after = await game.query('dev_advance_ms', 0);
  expect(after.now_ms, 'the simulation stood still').toBe(before.now_ms);
  expect([...new Set(order)].sort(), `digging: ${order.join(' ')}`).toEqual(['dig_0', 'dig_1', 'dig_2', 'dig_3']);
  // Always forward -- wind-up, swing, strike, recover, again -- never back
  // and forth (a missed short frame is a step of two).
  for (let i = 1; i < order.length; i++) {
    const step = (Number(order[i].slice(-1)) - Number(order[i - 1].slice(-1)) + 4) % 4;
    expect([1, 2], `${order[i - 1]} -> ${order[i]} goes forward`).toContain(step);
  }
  expect((await game.command({ type: 'momo.unassign', momo: 1 })).ok).toBe(true);
  await game.query('dev_advance_ms', 200);
  await game.page.waitForTimeout(300);
  m = await momo(game);
  expect(m.state).not.toBe('work');
  expect(m.cell).not.toMatch(/^dig_/);
});

test('many Momos at work, each on its own beat', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('dev_grow_island', 3);
  const jobs = [['farm', 2, 0], ['mine', 2, 1], ['lumberyard', 2, 2], ['research', 1, 2]];
  const ids = [1];
  for (let i = 1; i < jobs.length; i++) ids.push((await game.query('dev_add_momo', [1.5, 1.5])).id);
  for (let i = 0; i < jobs.length; i++) {
    const { id } = await game.query('dev_place_building', jobs[i]);
    expect((await game.command({ type: 'momo.assign', momo: ids[i], building: id })).ok).toBe(true);
  }
  const { day } = await game.query('dev_advance_ms', 0);
  await game.query('dev_advance_to', [day + 1, 0.08]);
  for (let i = 0; i < 200; i++) {
    await game.query('dev_advance_ms', 300);
    const ms = (await game.query('momos')).momos;
    if (ids.every((k) => ms[String(k)].state === 'work')) break;
  }
  const changes = Object.fromEntries(ids.map((k) => [k, new Set()]));
  for (let i = 0; i < 50; i++) {
    await game.page.waitForTimeout(60);
    const ms = (await game.query('momos')).momos;
    for (const k of ids) changes[k].add(ms[String(k)].cell);
  }
  for (const k of ids) expect(changes[k].size, `Momo ${k}: ${[...changes[k]].join(' ')}`).toBeGreaterThanOrEqual(3);
  if (process.env.MOMONIUM_SHOTS) {
    // A few seconds to watch, as a strip of frames.
    const box = await game.canvas.boundingBox();
    for (let i = 0; i < 12; i++) {
      await game.page.screenshot({ path: `${process.env.MOMONIUM_SHOTS}/anim67_${info.project.name}_${String(i).padStart(2, '0')}.png`, clip: { x: box.x + box.width * 0.18, y: box.y + box.height * 0.36, width: box.width * 0.64, height: box.height * 0.3 } });
      await game.page.waitForTimeout(120);
    }
  }
});
