// Step 61: a schedule tapped in Schedule mode is an order. Three farms tapped
// 3rd -> 1st -> 2nd show 1, 2, 3 in that order and are worked in that order,
// one stage each, round and round; a Momo walking to its stop is not turned
// aside when another of its farms comes free. Real taps, phone and desktop.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

test.use({ starterMomo: true });

const toCss = async (game, p, win) => {
  const box = await game.canvas.boundingBox();
  return { x: p[0] * (box.width / win[0]), y: p[1] * (box.height / win[1]) };
};
const centre = (r) => [r[0] + r[2] / 2, r[1] + r[3] / 2];
async function tapAt(game, p, win) {
  const c = await toCss(game, p, win);
  await game.tap(c.x, c.y);
  await game.page.waitForTimeout(250);
}
async function tapCell(game, cell) {
  const c = await cellToCanvas(game, cell);
  await game.tap(c.x, c.y);
  await game.page.waitForTimeout(250);
}
const momo1 = async (game) => (await game.state()).momo.momos.find((m) => m.id === 1);

async function schedule(game, cells) {
  const m = await game.query('momos');
  await tapAt(game, m.momos['1'].body, m.window);
  let w = await game.query('watch');
  await tapAt(game, centre(w.schedule), w.window);
  for (const c of cells) await tapCell(game, c);
  w = await game.query('watch');
  await tapAt(game, centre(w.schedule), w.window);
  return w;
}

test('tapped 3rd -> 1st -> 2nd: numbered and worked in that order', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_grow_island', 3);
  const first = (await game.query('dev_place_building', ['farm', 0, 0])).id;
  const second = (await game.query('dev_place_building', ['farm', 1, 0])).id;
  const third = (await game.query('dev_place_building', ['farm', 2, 0])).id;
  await game.page.waitForTimeout(300);
  const w = await schedule(game, [[2, 0], [0, 0], [1, 0]]);
  expect(w.route).toBe('order');
  expect(w.stops.map(([id, n]) => [id, n]), 'the numbers follow the taps').toEqual([[third, 1], [first, 2], [second, 3]]);
  await game.page.screenshot({ path: test.info().outputPath('numbers.png') });
  // The stops it goes to, in order, as game time runs.
  const seq = [];
  for (let i = 0; i < 160 && seq.length < 7; i++) {
    await game.query('dev_advance_ms', 750);
    const s = await game.state();
    for (const b of s.buildings.buildings) {
      if (b.state === 'working' && b.worker === 1 && seq[seq.length - 1] !== b.id) seq.push(b.id);
    }
  }
  const want = [third, first, second, third, first, second, third];
  expect(seq, `worked in the tapped order, one stage each: ${seq}`).toEqual(want.slice(0, seq.length));
  expect(seq.length).toBeGreaterThanOrEqual(6);
});

test('walking to its stop, it is not turned aside by a farm coming free', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_grow_island', 3);
  const far = (await game.query('dev_place_building', ['farm', 2, 2])).id;
  const near = (await game.query('dev_place_building', ['farm', 0, 1])).id;
  await game.page.waitForTimeout(300);
  // The near farm busy: the player sows it by hand (a real tap).
  await tapCell(game, [0, 1]);
  let s = await game.state();
  expect(s.buildings.buildings.find((b) => b.id === near).state).toBe('working');
  await schedule(game, [[2, 2], [0, 1]]);
  expect((await momo1(game)).assigned, 'committed to stop 1, the far farm').toBe(far);
  let freed = false;
  for (let i = 0; i < 60; i++) {
    await game.query('dev_advance_ms', 200);
    s = await game.state();
    const m = s.momo.momos.find((x) => x.id === 1);
    const n = s.buildings.buildings.find((b) => b.id === near);
    const f = s.buildings.buildings.find((b) => b.id === far);
    if (n.state === 'idle') freed = true;
    if (f.state === 'working' && f.worker === 1) break;
    expect(m.assigned, `step ${i}: still going to stop 1`).toBe(far);
  }
  expect(freed, 'the near farm came free on the way').toBe(true);
  expect((await game.state()).buildings.buildings.find((b) => b.id === far).worker, 'stop 1 worked first').toBe(1);
});
