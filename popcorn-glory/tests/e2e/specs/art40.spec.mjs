// Step 40: the three rooms behind the machines (art/env_art.gd), on three screens.
//  - the rooms are drawn: the kitchen wall has brick texture (its luminance varies), the shop's
//    street windows show a sky (blue over red), the packing wall has tile seams
//  - the hand's kettle stays the vivid thing in the kitchen: a share of strongly saturated pixels,
//    the brick wall behind it none
//    (in the first minutes the backdrop must not compete with the cooker)
//  - the render cost is recorded beside the screenshots (compare with the same spec run on the
//    build before Step 40: POPCORN_E2E_BASE=<public 0.39.0>)
import { test, expect } from '../lib/pop.mjs';
import { decodePng } from '../lib/png.mjs';

async function toPage(pop, r) {
  const s = await pop.state();
  const box = await pop.page.locator('canvas').boundingBox();
  const k = box.width / s.window[0];
  return { x: box.x + r[0] * k, y: box.y + r[1] * k, width: r[2] * k, height: r[3] * k };
}

async function region(pop, clip) {
  const img = decodePng(await pop.page.screenshot({ clip }));
  let sat = 0, lum = 0, lum2 = 0, sky = 0, strong = 0;
  const n = img.width * img.height;
  for (let i = 0; i < img.data.length; i += 4) {
    const [R, G, B] = [img.data[i], img.data[i + 1], img.data[i + 2]];
    const mx = Math.max(R, G, B), mn = Math.min(R, G, B);
    const S = mx > 0 ? (mx - mn) / mx : 0;
    sat += S;
    if (S > 0.6 && mx > 100) strong++;   // vivid: the kettle's red, gold; never the pastel walls
    const L = 0.3 * R + 0.59 * G + 0.11 * B;
    lum += L; lum2 += L * L;
    if (B > R + 15) sky++;
  }
  const mean = lum / n;
  return { sat: +(sat / n).toFixed(3), lumStd: +Math.sqrt(Math.max(0, lum2 / n - mean * mean)).toFixed(2), skyShare: +(sky / n).toFixed(3), vivid: +(strong / n).toFixed(3) };
}

test('the three rooms are drawn behind the machines, and the hand\'s kettle stays the vivid thing in the kitchen', async ({ pop }, testInfo) => {
  test.setTimeout(120_000);
  await pop.open('./#factory');
  await pop.page.waitForTimeout(1500);
  const s = await pop.state();
  const low = await toPage(pop, s.rects.floor_low);
  const top = await toPage(pop, s.rects.floor_top);
  const mid = await toPage(pop, s.rects.floor_mid);
  const ring = await toPage(pop, s.rects.ring);
  // the kettle: the middle of the ring (its glass and red body); the wall: a strip at the
  // kitchen's left edge, below the badge, above the floor band
  const kettle = { x: ring.x + ring.width * 0.3, y: ring.y + ring.height * 0.35, width: ring.width * 0.4, height: ring.height * 0.35 };
  const wall = { x: low.x + low.width * 0.03, y: low.y + low.height * 0.35, width: Math.max(8, Math.min(low.width * 0.06, ring.x - low.x - low.width * 0.04)), height: low.height * 0.35 };
  const shopWin = { x: top.x + top.width * 0.35, y: top.y + top.height * 0.3, width: top.width * 0.4, height: top.height * 0.25 };
  const tiles = { x: mid.x + mid.width * 0.6, y: mid.y + mid.height * 0.08, width: mid.width * 0.12, height: mid.height * 0.25 };
  const k = await region(pop, kettle);
  const w = await region(pop, wall);
  const sw = await region(pop, shopWin);
  const t = await region(pop, tiles);
  const info = await pop.call('dev_render_info');
  await pop.shot('art40_0m');
  testInfo.annotations.push({ type: 'art', description: JSON.stringify({ kettle: k, wall: w, shop_window: sw, tiles: t, render: { draw_calls: info.draw_calls, objects: info.objects, primitives: info.primitives, nodes: info.nodes } }) });
  expect(w.lumStd, 'the kitchen wall has brick texture (not one flat colour)').toBeGreaterThan(3);
  expect(sw.skyShare, 'the shop\'s street windows show a sky').toBeGreaterThan(0.15);
  expect(t.lumStd, 'the packing wall has tile seams').toBeGreaterThan(1.5);
  expect(k.vivid, 'the hand\'s kettle is vivid (its red body)').toBeGreaterThan(0.15);
  expect(w.vivid, 'the wall behind it is not: the backdrop stays pastel').toBeLessThan(0.02);
});
