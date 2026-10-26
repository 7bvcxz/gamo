// Step 51: Momo is drawn from the 5x5 sprite sheet in the real web build --
// the starting Momo stands in a sheet cell, a walk steps through its walk
// cells, work shows a job cell, night the sleeping cell, and the pixels under
// it are the approved character's cream and dark outline (the WebGL import
// draws it, not an empty quad).
import { test, expect } from '../lib/fixtures.mjs';

const momo = async (game) => (await game.query('momos')).momos['1'];

test('Momo is drawn from the sprite sheet in every state', async ({ game }) => {
  await game.setTimeScale(0);
  let m = await momo(game);
  expect(m.sheet).toEqual([1280, 1280]);
  expect(m.cell).toMatch(/^(front|back|side)_(idle|blink)$|^sit$|^(happy|waiting|confused)$/);
  // Pixels under it: cream fur and the dark outline.
  const box = await game.canvas.boundingBox();
  const win = (await game.query('momos')).window;
  const sx = box.width / win[0];
  const sy = box.height / win[1];
  const clip = { x: box.x + (m.body[0] - 30) * sx, y: box.y + (m.body[1] - 45) * sy, width: 60 * sx, height: 85 * sy };
  const png = await game.page.screenshot({ clip });
  const counts = await game.page.evaluate(async (b64) => {
    const img = new Image();
    img.src = 'data:image/png;base64,' + b64;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const g = c.getContext('2d');
    g.drawImage(img, 0, 0);
    const d = g.getImageData(0, 0, c.width, c.height).data;
    let cream = 0, outline = 0;
    for (let i = 0; i < d.length; i += 4) {
      const [r, gg, b] = [d[i], d[i + 1], d[i + 2]];
      if (r > 225 && gg > 215 && b > 195 && r >= b) cream++;
      if (r < 110 && gg < 80 && b < 70) outline++;
    }
    return { cream, outline, total: d.length / 4 };
  }, png.toString('base64'));
  expect(counts.cream / counts.total).toBeGreaterThan(0.12);
  expect(counts.outline).toBeGreaterThan(10);
  // A walk: assign it to a building across the island and watch the cells.
  await game.query('dev_grow_island', 3);
  const { id: mine } = await game.query('dev_place_building', ['mine', 2, 2]);
  expect((await game.command({ type: 'momo.assign', momo: 1, building: mine })).ok).toBe(true);
  await game.setTimeScale(1);
  const walkCells = new Set();
  for (let i = 0; i < 20; i++) {
    await game.page.waitForTimeout(60);
    m = await momo(game);
    if (m.state === 'walk') walkCells.add(m.cell);
  }
  expect([...walkCells].every((c) => /_walk_[abc]$/.test(c))).toBe(true);
  expect(walkCells.size).toBeGreaterThanOrEqual(2);
  // At the mine: the pickaxe.
  await game.setTimeScale(0);
  for (let i = 0; i < 30; i++) {
    await game.query('dev_advance_ms', 500);
    await game.page.waitForTimeout(40);
    m = await momo(game);
    if (m.state === 'work') break;
  }
  expect(m.state).toBe('work');
  expect(m.cell).toBe('dig');
  // Night: a free Momo sleeps, on the sleeping cell (one at work keeps on).
  expect((await game.command({ type: 'momo.unassign', momo: 1 })).ok).toBe(true);
  await game.query('dev_advance_to', [3, 0.82]);
  await game.page.waitForTimeout(200);
  m = await momo(game);
  expect(m.state).toBe('sleep');
  expect(m.cell).toBe('sleep');
});
