// Step 55: in the real web build, a Momo standing beside a building -- on the
// back half of its tile, at the side -- is drawn over it, as one in front of it
// is; a Momo clearly behind it is still hidden by it. Measured in WebGL
// pixels: how much of each Momo's lower body changes the picture of the
// island without it.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

async function shot(game) {
  const png = decodePng(await game.canvas.screenshot());
  const win = (await game.query('momos')).window;
  return { png, sx: png.width / win[0], sy: png.height / win[1] };
}

// Share of the Momo's legs-and-tummy box (window pixels, from where it
// stands) that differs from the island without it.
function shown(a, b, m) {
  const k = (m.feet[1] - m.body[1]) / 35;
  let n = 0;
  let diff = 0;
  for (let y = m.feet[1] - 50 * k; y < m.feet[1] - 6 * k; y += 2) {
    for (let x = m.feet[0] - 18 * k; x < m.feet[0] + 18 * k; x += 2) {
      const p = pixel(a.png, x * a.sx, y * a.sy);
      const q = pixel(b.png, x * b.sx, y * b.sy);
      n += 1;
      if (Math.abs(p[0] - q[0]) + Math.abs(p[1] - q[1]) + Math.abs(p[2] - q[2]) > 60) diff += 1;
    }
  }
  return diff / Math.max(n, 1);
}

test('beside a building: in front of it; clearly behind: hidden by it', async ({ game }) => {
  await game.setTimeScale(0);
  let at = null;
  for (const c of [[1, 1], [0, 1], [1, 0], [0, 0]]) {
    if ((await game.query('dev_place_building', ['research', ...c])).id) {
      at = c;
      break;
    }
  }
  expect(at, 'a lab on the island').not.toBeNull();
  const cx = at[0] + 0.5;
  const cy = at[1] + 0.5;
  await game.page.waitForTimeout(400);
  const empty = await shot(game);
  const spots = { front: [0.62, 0.62], side: [0.18, -0.45], behind: [-0.6, -0.6] };
  const ids = {};
  for (const [name, d] of Object.entries(spots)) ids[name] = (await game.query('dev_add_momo', [cx + d[0], cy + d[1]])).id;
  await game.page.waitForTimeout(400);
  const full = await shot(game);
  const momos = (await game.query('momos')).momos;
  const f = {};
  for (const name of Object.keys(spots)) f[name] = shown(empty, full, momos[String(ids[name])]);
  console.log(`depth55: shown front ${f.front.toFixed(2)} side ${f.side.toFixed(2)} behind ${f.behind.toFixed(2)}`);
  expect(f.front, 'a Momo in front of the lab is seen').toBeGreaterThan(0.35);
  // Before Step 55 the lab covered about 40% of it (0.53 of the front's 0.90).
  expect(f.side, 'beside it, on its tile: in front too').toBeGreaterThan(f.front * 0.8);
  // Just past its back corner: about half hidden, before and after.
  expect(f.behind, 'clearly behind it: the lab still hides part of it').toBeLessThan(f.front * 0.7);
});
