// Step 76: in the real web build Momo keeps its feet on its spot -- every
// frame of a job (the pickaxe's, the axe's) is
// drawn with the two feet on the point the game stands it on (its shadow,
// its tap area), and so is the Momo standing idle. Measured on the screen's
// pixels: Momo's two round cream feet (lib/momo_feet.mjs, the twin of
// tools/art/gen/momo_anchor.gd), against the Momo's ground point from the
// game. Each frame is held (`dev_hold_momo`) so the screenshot is that
// frame. On 0.75.0 the pickaxe's strike stood Momo ~45 px to the side and
// the water jet ~30. With MOMONIUM_SHOTS set, also saves every frame shot.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng } from '../lib/png.mjs';
import { feet } from '../lib/momo_feet.mjs';
import { pinch, touchDrag } from '../lib/touch.mjs';

test.use({ starterMomo: true });

// A frame's feet may be this far off the spot, in island pixels: the
// screen's rounding and the linear filter on a 72 px Momo.
const TOL = 2.5;
// The feet's outline under their cream, island px (1.5 texels at 72/160):
// the root is under the outline.
const OUTLINE = 0.7;
// Frames whose root is written down (a hidden foot, a hop): no two planted
// feet to find on screen there.
const WRITTEN = new Set(['sow_3', 'harvest_0', 'hammer_2', 'replant_0', 'replant_1', 'replant_2', 'replant_3']);

const momo = async (game) => (await game.query('momos')).momos['1'];

// The frame on show, measured: the feet's midpoint from the Momo's ground
// point, in island pixels -- {cell, dx, dy} or {cell, error}.
async function measure(game, shots, name) {
  const m = await momo(game);
  const box = await game.canvas.boundingBox();
  const win = (await game.query('momos')).window;
  const css = box.width / win[0];
  // Island pixels -> window pixels, from the ground and 35 island px above it.
  const k = (m.feet[1] - m.body[1]) / 35;
  const h = 72 * k * css;
  // Around the ground point, inside the page (a Momo near its edge is cut).
  const g = { x: box.x + m.feet[0] * css, y: box.y + m.feet[1] * css };
  const vp = game.page.viewportSize();
  const x0 = Math.max(0, g.x - h * 0.9);
  const y0 = Math.max(0, g.y - h * 1.25);
  const clip = { x: x0, y: y0, width: Math.min(vp.width, g.x + h * 0.9) - x0, height: Math.min(vp.height, g.y + h * 0.25) - y0 };
  const png = await game.page.screenshot({ clip, path: shots ? `${shots}/${name}_${m.cell}.png` : undefined });
  const img = decodePng(png);
  const dpr = img.width / clip.width;
  const r = feet(img.data, img.width, img.height, h * dpr);
  if (r.error) return { cell: m.cell, error: r.error };
  const px = k * css * dpr;
  return { cell: m.cell, dx: (r.x - (g.x - x0) * dpr) / px, dy: (r.y - (g.y - y0) * dpr) / px + OUTLINE };
}

async function zoomIn(game, info) {
  // In close, as a player looks at one Momo: at the island's own zoom a
  // foot is a few pixels and the outline between it and the leg is blurred
  // away. Two fingers on phones, the wheel (where the pointer is) on desktop.
  const m = await momo(game);
  const box = await game.canvas.boundingBox();
  const win = (await game.query('momos')).window;
  const css = box.width / win[0];
  const at = { x: box.x + m.feet[0] * css, y: box.y + m.feet[1] * css };
  if (info.project.use.hasTouch) {
    for (let i = 0; i < 2; i++) {
      await pinch(game.page, at, 60, 200);
      await game.page.waitForTimeout(300);
    }
  } else {
    await game.page.mouse.move(at.x, at.y);
    for (let i = 0; i < 6; i++) {
      await game.page.mouse.wheel(0, -240);
      await game.page.waitForTimeout(120);
    }
  }
  await game.page.waitForTimeout(500);
  // Then the Momo to the middle (zoomed at the pointer, it may sit at an
  // edge, its feet cut): a drag from the middle -- not from the Momo, which
  // would pick it up -- by as much as the Momo is off it.
  const n = await momo(game);
  const c = { x: box.x + box.width / 2, y: box.y + box.height * 0.55 };
  const off = { x: c.x - (box.x + n.feet[0] * css), y: c.y - (box.y + n.feet[1] * css) };
  if (Math.hypot(off.x, off.y) > 40) {
    if (info.project.use.hasTouch) await touchDrag(game.page, c, { x: c.x + off.x, y: c.y + off.y }, 16);
    else {
      await game.page.mouse.move(c.x, c.y);
      await game.page.mouse.down();
      await game.page.mouse.move(c.x + off.x, c.y + off.y, { steps: 16 });
      await game.page.mouse.up();
    }
    await game.page.waitForTimeout(600);
  }
}

async function toWork(game, type, cell) {
  const { day } = await game.query('dev_advance_ms', 0);
  await game.query('dev_advance_to', [day + 1, 0.06]);
  const { id } = await game.query('dev_place_building', [type, ...cell]);
  expect(id, `${type} placed`).toBeGreaterThan(0);
  expect((await game.command({ type: 'momo.assign', momo: 1, building: id })).ok).toBe(true);
  for (let i = 0; i < 200; i++) {
    await game.query('dev_advance_ms', 300);
    if ((await momo(game)).state === 'work') return id;
  }
  throw new Error(`${type}: Momo never started working`);
}

// Every frame of the job on show, held one by one and measured.
async function frames(game, shots, tag) {
  const out = [];
  const { frames: n } = await game.query('dev_hold_momo', [1, 0]);
  for (let i = 0; i < n; i++) {
    await game.query('dev_hold_momo', [1, i]);
    await game.page.waitForTimeout(250);
    out.push(await measure(game, shots, tag));
  }
  await game.query('dev_hold_momo', [1, -1]);
  return out;
}

test('a working Momo keeps its feet on its spot in every frame', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('dev_grow_island', 3);
  const shots = process.env.MOMONIUM_SHOTS || '';
  const report = { version: await game.version(), project: info.project.name, jobs: {} };
  // The farm's front fence covers the feet of a Momo at work in it (the
  // depth sort, on purpose): its frames are held to their roots by
  // test_momo_anchors and test_momo_anchor_rig.
  const jobs = [['mine', [2, 1], 'dig'], ['lumberyard', [2, 2], 'chop']];
  let zoomed = false;
  for (const [type, cell, job] of jobs) {
    await toWork(game, type, cell);
    if (!zoomed) {
      await zoomIn(game, info);
      zoomed = true;
    }
    const got = await frames(game, shots, `anchor76_${info.project.name}`);
    report.jobs[type] = got;
    console.log(`ANCHOR ${info.project.name} ${type}: ${got.map((g) => g.error ? `${g.cell} (${g.error})` : `${g.cell} ${g.dx.toFixed(1)},${g.dy.toFixed(1)}`).join('  ')}`);
    expect(got.map((g) => g.cell), `${type}: the job's four frames`).toEqual([0, 1, 2, 3].map((i) => `${job}_${i}`));
    const strict = got.filter((g) => !WRITTEN.has(g.cell));
    for (const g of strict) {
      expect(g.error, `${g.cell}: two feet on screen`).toBeUndefined();
      expect(Math.abs(g.dx), `${g.cell}: the feet over the spot (${g.dx?.toFixed(1)} px across)`).toBeLessThanOrEqual(TOL);
      expect(Math.abs(g.dy), `${g.cell}: on the spot's line (${g.dy?.toFixed(1)} px)`).toBeLessThanOrEqual(TOL);
    }
    const xs = strict.map((g) => g.dx);
    expect(Math.max(...xs) - Math.min(...xs), `${type}: no frame moves Momo (${strict.map((g) => `${g.cell} ${g.dx.toFixed(1)}`).join(', ')})`).toBeLessThanOrEqual(TOL);
    expect((await game.command({ type: 'momo.unassign', momo: 1 })).ok).toBe(true);
    await game.query('dev_advance_ms', 300);
  }
  await info.attach('anchors.json', { body: JSON.stringify(report, null, 1), contentType: 'application/json' });
});

test('a Momo standing still stands on its spot', async ({ game }, info) => {
  await game.setTimeScale(0);
  const { day } = await game.query('dev_advance_ms', 0);
  await game.query('dev_advance_to', [day + 1, 0.06]);
  await game.page.waitForTimeout(300);
  await zoomIn(game, info);
  let m = await momo(game);
  for (let i = 0; i < 40 && (m.state !== 'idle' || m.moving); i++) {
    await game.page.waitForTimeout(100);
    m = await momo(game);
  }
  expect(m.state).toBe('idle');
  const got = await frames(game, process.env.MOMONIUM_SHOTS || '', `anchor76_${info.project.name}_idle`);
  for (const g of got) {
    expect(g.error, `${g.cell}: two feet on screen`).toBeUndefined();
    expect(Math.abs(g.dx), `${g.cell}: across (${g.dx?.toFixed(1)})`).toBeLessThanOrEqual(TOL);
    expect(Math.abs(g.dy), `${g.cell}: on the line (${g.dy?.toFixed(1)})`).toBeLessThanOrEqual(TOL);
  }
});
