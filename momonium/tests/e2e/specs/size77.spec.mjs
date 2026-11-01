// Step 77: in the real web build every Momo is drawn at 80% of its Step 76
// size -- 72 island pixels from the feet to the fur curl became 57.6 -- with
// its feet on the same spot, and what follows its body follows the smaller
// one: a tap on its middle picks it, a tap where the old, taller Momo's head
// was reaches the lab behind it, the Schedule button sits just under its
// feet, its mood bubble just over its head. Phone (also at the 720x1280
// baseline) and desktop, real taps.
//
// Measured on the screen's pixels, not from the size the game reports: the
// Momo is what changed between a shot of the island before it was added and
// one after, and an island pixel is a tile's width on screen over the
// projection's 128 (data/art.json). With MOMONIUM_SHOTS set, saves the shots.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng, pixel } from '../lib/png.mjs';
import { pinch } from '../lib/touch.mjs';
import { writeFileSync } from 'node:fs';

const HEIGHT = 72;
const SIZE = 0.8;
const TILE_W = 128;
const SPOT = [2.05, 2.05];

async function shot(game, name) {
  const buf = await game.canvas.screenshot();
  if (process.env.MOMONIUM_SHOTS) writeFileSync(`${process.env.MOMONIUM_SHOTS}/size77_${name}.png`, buf);
  const png = decodePng(buf);
  const win = (await game.query('momos')).window;
  return { png, sx: png.width / win[0], sy: png.height / win[1] };
}

// Window pixels per island pixel: a tile's width on screen.
async function islandPx(game) {
  const a = await game.query('logical_screen', [SPOT[0], SPOT[1], 0]);
  const b = await game.query('logical_screen', [SPOT[0] + 1, SPOT[1] - 1, 0]);
  return Math.hypot(b.x - a.x, b.y - a.y) / TILE_W;
}

// The Momo drawn: what changed from `a` to `b` around its feet `at`
// (window pixels, `px` a island pixel). Its top is read from the columns
// left of its middle and its width from the rows below its eyes: a mood
// bubble may already be up there, over the head and to the right. Its feet
// from the middle columns (its shadow is faint against the grass).
function changed(a, b, at, px) {
  const reach = HEIGHT * px * 1.2;
  let x0 = Infinity; let y0 = Infinity; let x1 = -Infinity; let y1 = -Infinity;
  const step = 1 / a.sx;
  for (let y = at.y - reach; y < at.y + reach * 0.4; y += step) {
    for (let x = at.x - reach * 0.7; x < at.x + reach * 0.7; x += step) {
      const p = pixel(a.png, x * a.sx, y * a.sy);
      const q = pixel(b.png, x * b.sx, y * b.sy);
      if (Math.abs(p[0] - q[0]) + Math.abs(p[1] - q[1]) + Math.abs(p[2] - q[2]) <= 120) continue;
      const dx = (x - at.x) / px;
      const dy = (y - at.y) / px;
      if (dx > -12 && dx < 3) y0 = Math.min(y0, y);
      if (dy > -40 && dy < -4) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); }
      if (Math.abs(dx) < 10) y1 = Math.max(y1, y);
    }
  }
  return { x0, y0, x1, y1 };
}

async function zoomIn(game, info, at) {
  const box = await game.canvas.boundingBox();
  const win = (await game.query('momos')).window;
  const css = box.width / win[0];
  const p = { x: box.x + at.x * css, y: box.y + at.y * css };
  if (info.project.use.hasTouch) {
    await pinch(game.page, p, 60, 170);
  } else {
    await game.page.mouse.move(p.x, p.y);
    for (let i = 0; i < 3; i++) {
      await game.page.mouse.wheel(0, -240);
      await game.page.waitForTimeout(120);
    }
  }
  await game.page.waitForTimeout(600);
}

async function tapWindow(game, p) {
  const box = await game.canvas.boundingBox();
  const win = (await game.query('momos')).window;
  await game.tap(p.x * (box.width / win[0]), p.y * (box.height / win[1]));
  await game.page.waitForTimeout(300);
}

for (const shape of ['default', '720x1280']) {
  test.describe(shape, () => {
    if (shape === '720x1280') test.use({ viewport: { width: 360, height: 640 } });

    test('drawn at 0.8, feet on its spot; taps, Schedule and mood follow the smaller body', async ({ game }, info) => {
      test.skip(shape === '720x1280' && !info.project.use.hasTouch, 'the portrait baseline is a phone');
      await game.setTimeScale(0);
      await game.query('set_language', 'en');
      await game.query('dev_grow_island', 4);
      const { id: lab } = await game.query('dev_place_building', ['research', 1, 1]);
      expect(lab, 'a lab behind the spot').toBeTruthy();
      await game.page.waitForTimeout(300);
      const spot = await game.query('logical_screen', [SPOT[0], SPOT[1], 0]);
      await zoomIn(game, info, spot);
      const empty = await shot(game, `${info.project.name}_${shape}_empty`);
      const { id } = await game.query('dev_add_momo', SPOT);
      await game.page.waitForTimeout(350);
      const full = await shot(game, `${info.project.name}_${shape}_momo`);
      const info77 = await game.query('momos');
      const m = info77.momos[String(id)];
      const px = await islandPx(game);
      const box = changed(empty, full, { x: m.feet[0], y: m.feet[1] }, px);
      const tall = (m.feet[1] - box.y0) / px;
      const wide = (box.x1 - box.x0) / px;
      console.log(`size77 ${info.project.name} ${shape}: ${tall.toFixed(1)} island px tall (Step 76: 72), ${wide.toFixed(1)} wide, ${px.toFixed(2)} window px a pixel`);
      expect(m.size, 'the game says 0.8').toBe(SIZE);
      // The fur curl to the feet: 57.6 (a breath of 1.2%, the screen's rounding).
      expect(tall, 'drawn 0.8 as tall as Step 76 (57.6 px)').toBeGreaterThan(HEIGHT * SIZE * 0.95);
      expect(tall, 'and no taller').toBeLessThan(HEIGHT * SIZE * 1.05);
      // Front, standing: the ears span 68 px at size 1 (54 at 0.8).
      expect(wide, 'and as wide').toBeLessThan(68 * SIZE * 1.08);
      expect(Math.abs((box.y1 - m.feet[1]) / px), 'its feet on its spot').toBeLessThan(3);
      expect(Math.abs((box.x0 + box.x1) / 2 - m.feet[0]) / px, 'centred on it').toBeLessThan(4);

      // Its mood (a free Momo is content: a heart), over the head drawn --
      // 24 island px to the bubble's middle at any size, as before.
      let mood = null;
      for (let i = 0; i < 40 && !mood; i++) {
        const ms = (await game.query('moods'))[String(id)];
        if (ms.visible && ms.mood) mood = ms;
        else await game.page.waitForTimeout(100);
      }
      expect(mood, 'its mood shows').not.toBeNull();
      // Faded in (a quarter second, rising 8 px into place), then read.
      await game.page.waitForTimeout(400);
      mood = (await game.query('moods'))[String(id)];
      expect(mood.visible, 'still showing').toBe(true);
      const gap = (box.y0 - mood.at[1]) / px;
      console.log(`size77 ${info.project.name} ${shape}: mood ${mood.mood} ${gap.toFixed(1)} island px over the head`);
      expect(gap, 'over the head drawn, as before (24; a 1.2 px bob)').toBeGreaterThan(20);
      expect(gap, '').toBeLessThan(28);
      expect(Math.abs((mood.at[0] - m.feet[0]) / px - 22 * SIZE), 'beside the smaller head').toBeLessThan(3);
      await shot(game, `${info.project.name}_${shape}_mood`);

      // A tap on its middle picks it; where the Step 76 Momo's head was,
      // the lab behind it.
      const head = { x: m.feet[0], y: m.feet[1] - 70 * px };
      await tapWindow(game, head);
      let sel = await game.query('selection');
      expect(sel.kind, 'over the smaller head: the lab').toBe('building');
      await tapWindow(game, { x: m.feet[0], y: m.feet[1] - HEIGHT * SIZE * 0.5 * px });
      const after = await game.query('momos');
      expect(after.selected, 'its middle: the Momo').toBe('momo');
      expect(after.selected_id).toBe(id);
      const hit = after.momos[String(id)].hit;
      expect((hit[1] + hit[3]) - m.feet[1], 'the tap box ends at its feet').toBeLessThan(4 * px);
      expect(box.y0 - hit[1], 'and just over its head').toBeLessThan(10 * px);

      // The Schedule button, under the feet, not on the Momo.
      await shot(game, `${info.project.name}_${shape}_selected`);
      const w = await game.query('watch');
      expect(w.momo).toBe(id);
      const b = w.schedule;
      expect(b.length, 'its Schedule button').toBe(4);
      if (w.side === 'below') {
        expect(b[1] - m.feet[1], 'just under its feet').toBeGreaterThan(0);
        expect(b[1] - m.feet[1], '').toBeLessThan(4 * px + 10);
      }
      const overlap = Math.max(0, Math.min(b[0] + b[2], box.x1) - Math.max(b[0], box.x0)) * Math.max(0, Math.min(b[1] + b[3], box.y1) - Math.max(b[1], box.y0));
      expect(overlap, 'not on the Momo').toBeLessThan(2 * px * px + 4);

    });
  });
}

test('many Momo among buildings: each drawn at 0.8 on its own spot', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('dev_grow_island', 4);
  for (const [t, x, y] of [['farm', 0, 0], ['mine', 2, 0], ['lumberyard', 0, 2], ['research', 2, 2]]) await game.query('dev_place_building', [t, x, y]);
  await game.page.waitForTimeout(300);
  const empty = await shot(game, `${info.project.name}_many_empty`);
  // The first in the middle of the four, the rest two tiles from it.
  const spots = [[1.5, 1.5], [3.5, 1.5], [1.5, 3.5], [3.5, 3.5], [3.5, 0.5], [0.5, 3.5]];
  const ids = [];
  for (const s of spots) ids.push((await game.query('dev_add_momo', s)).id);
  await game.page.waitForTimeout(350);
  const full = await shot(game, `${info.project.name}_many`);
  const px = await islandPx(game);
  const ms = (await game.query('momos')).momos;
  // The one between the buildings, measured alone (no other Momo in reach).
  const m = ms[String(ids[0])];
  const box = changed(empty, full, { x: m.feet[0], y: m.feet[1] }, px);
  const tall = (m.feet[1] - box.y0) / px;
  console.log(`size77 ${info.project.name} many: the one in the middle ${tall.toFixed(1)} px tall`);
  expect(tall).toBeGreaterThan(HEIGHT * SIZE * 0.93);
  expect(tall).toBeLessThan(HEIGHT * SIZE * 1.07);
  for (const i of ids) expect(ms[String(i)].size, `Momo ${i} at 0.8`).toBe(SIZE);
});
