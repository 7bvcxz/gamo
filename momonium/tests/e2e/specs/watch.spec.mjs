// Step 31 (Step 60: the pencil is the Schedule button under the Momo): tap a
// Momo -- its watched tiles light up and Schedule appears under its feet;
// Schedule, then a stroke across tiles adds them all (the first tile
// decides), a stroke starting on a watched tile removes, a tap edits one tile,
// within the Momo's capacity; the Momo goes to work on a newly watched farm at
// once; Schedule again ends it. Finger on phones, mouse on desktop.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

// Step 53: about what a Momo does -- the old starter Momo, explicitly.
test.use({ starterMomo: true });

const toCss = async (game, p, win) => {
  const box = await game.canvas.boundingBox();
  return { x: p[0] * (box.width / win[0]), y: p[1] * (box.height / win[1]) };
};
const centre = (r) => [r[0] + r[2] / 2, r[1] + r[3] / 2];

async function stroke(game, cells, touch) {
  const pts = [];
  for (const c of cells) pts.push(await cellToCanvas(game, c));
  if (touch) {
    // One finger through every point: touchDrag per leg would lift in between.
    const s = await game.page.context().newCDPSession(game.page);
    const box = await game.canvas.boundingBox();
    const at = (p) => ({ x: box.x + p.x, y: box.y + p.y, id: 0, radiusX: 2, radiusY: 2, force: 1 });
    await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [at(pts[0])] });
    for (let i = 1; i < pts.length; i++) {
      for (let k = 1; k <= 8; k++) {
        const p = { x: pts[i - 1].x + ((pts[i].x - pts[i - 1].x) * k) / 8, y: pts[i - 1].y + ((pts[i].y - pts[i - 1].y) * k) / 8 };
        await s.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [at(p)] });
        await game.page.waitForTimeout(16);
      }
    }
    await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    return;
  }
  const box = await game.canvas.boundingBox();
  await game.page.mouse.move(box.x + pts[0].x, box.y + pts[0].y);
  await game.page.mouse.down();
  for (let i = 1; i < pts.length; i++) await game.page.mouse.move(box.x + pts[i].x, box.y + pts[i].y, { steps: 8 });
  await game.page.mouse.up();
}

const watchOf = async (game) => (await game.state()).momo.momos.find((m) => m.id === 1).watch.map((c) => c.join(',')).sort();

test('tap a Momo, Schedule, paint its tiles', async ({ game }, info) => {
  const touch = info.project.use.hasTouch;
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_grow_island', 3);
  const { id: farm } = await game.query('dev_place_building', ['farm', 2, 0]);
  await game.page.waitForTimeout(300);
  // Tap the Momo.
  const m = await game.query('momos');
  const body = await toCss(game, m.momos['1'].body, m.window);
  await game.tap(body.x, body.y);
  await game.page.waitForTimeout(250);
  let w = await game.query('watch');
  expect(w.momo).toBe(1);
  expect(w.schedule.length).toBe(4);
  expect(w.editing).toBe(false);
  expect(w.capacity).toBe(4);
  // Schedule.
  let p = await toCss(game, centre(w.schedule), w.window);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(200);
  w = await game.query('watch');
  expect(w.editing).toBe(true);
  expect(w.count).toBe('0 / 4 tiles');
  // A stroke across three tiles adds all three; the camera stays.
  const cam = await game.query('camera');
  await stroke(game, [[0, 0], [0, 1], [1, 1]], touch);
  await game.page.waitForTimeout(250);
  expect(await watchOf(game)).toEqual(['0,0', '0,1', '1,1']);
  const cam2 = await game.query('camera');
  expect([cam2.x, cam2.y]).toEqual([cam.x, cam.y]);
  w = await game.query('watch');
  expect(w.tinted.length).toBe(3);
  expect(w.count).toBe('3 / 4 tiles');
  // A tap adds the farm's tile: the Momo heads there at once.
  const fc = await cellToCanvas(game, [2, 0]);
  await game.tap(fc.x, fc.y);
  await game.page.waitForTimeout(250);
  expect(await watchOf(game)).toEqual(['0,0', '0,1', '1,1', '2,0']);
  let s = await game.state();
  expect(s.momo.momos.find((x) => x.id === 1).assigned).toBe(farm);
  // Full: one more tile is refused.
  const extra = await cellToCanvas(game, [1, 0]);
  await game.tap(extra.x, extra.y);
  await game.page.waitForTimeout(200);
  w = await game.query('watch');
  expect(Object.values(w.result.refused)).toEqual(['err.watch_full']);
  // A stroke starting on a watched tile removes, and only removes.
  await stroke(game, [[0, 0], [0, 1], [0, 0]], touch);
  await game.page.waitForTimeout(250);
  expect(await watchOf(game)).toEqual(['1,1', '2,0']);
  // Schedule again ends it; the farm gets worked.
  w = await game.query('watch');
  p = await toCss(game, centre(w.schedule), w.window);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(200);
  expect((await game.query('watch')).editing).toBe(false);
  await game.setTimeScale(10);
  await expect.poll(async () => (await game.state()).buildings.buildings.find((b) => b.id === farm).completed, { timeout: 20_000 }).toBeGreaterThan(0);
});
