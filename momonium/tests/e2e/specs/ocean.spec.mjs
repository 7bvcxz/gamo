// Step 08: the sea moves, the coast is lighter than open water, and a much
// larger island keeps a usable frame rate.
import { test, expect } from '../lib/fixtures.mjs';
import { logicalToCanvas } from '../lib/coords.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

async function shot(game) {
  const png = decodePng(await game.canvas.screenshot());
  const box = await game.canvas.boundingBox();
  return { png, sx: png.width / box.width, sy: png.height / box.height, box };
}

test('the sea is animated and the coast is shallow and foamy', async ({ game }) => {
  const a = await shot(game);
  await game.page.waitForTimeout(700);
  const b = await shot(game);
  let changed = 0;
  for (let i = 0; i < 40; i++) {
    const x = (a.png.width * (i + 0.5)) / 40;
    const y = a.png.height * 0.9;
    const pa = pixel(a.png, x, y);
    const pb = pixel(b.png, x, y);
    if (Math.abs(pa[0] - pb[0]) + Math.abs(pa[1] - pb[1]) + Math.abs(pa[2] - pb[2]) > 3) changed++;
  }
  expect(changed, 'pixels across the open sea change over time').toBeGreaterThan(4);
  const bright = (p) => p[0] + p[1] + p[2];
  // Water just past the south-east coast (below the cliff) vs open sea at the left edge.
  const coast = await logicalToCanvas(game, 2.15, 1.0, -0.62);
  const nearCoast = pixel(b.png, coast.x * b.sx, coast.y * b.sy);
  const open = pixel(b.png, b.png.width * 0.04, b.png.height * 0.85);
  expect(bright(nearCoast), `coast ${nearCoast} brighter than open sea ${open}`).toBeGreaterThan(bright(open));
});

test('a 30x30 island still draws smoothly', async ({ game }) => {
  const r = await game.query('dev_grow_island', 30);
  expect(r.cells).toBe(900);
  const fps = await game.page.evaluate(() => new Promise((resolve) => {
    let frames = 0;
    const start = performance.now();
    const tick = () => { frames++; if (performance.now() - start < 2000) requestAnimationFrame(tick); else resolve(frames / ((performance.now() - start) / 1000)); };
    requestAnimationFrame(tick);
  }));
  console.log(`30x30 island: ${fps.toFixed(1)} fps (software GL in CI-like headless Chromium)`);
  expect(fps).toBeGreaterThan(20);
});
