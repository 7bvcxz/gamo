// Step 41: the cast, the goods and the icon set, in the browser on three screens.
//  1. #cast (the design sheet): every icon is drawn (ink and its own colour), no two icons share
//     an outline (their silhouettes overlap less than 85% after centring), and the walkers'
//     feet stay on their line while they lean, breathe and hop.
//  2. The factory at a fresh start (0 m), at the 3-minute milestone and in a 30-minute rush
//     at sign 8 (the game's clock advanced, the kettle popped by hand on the way): screenshots
//     of each, recorded on video; the people never stand over the glass tube or the floor's
//     badge, the buttons over them still answer a tap (the badge opens its card, the news
//     paper opens), and in the rush the shop is crowded with people of many looks.
import { test, expect } from '../lib/pop.mjs';
import { decodePng } from '../lib/png.mjs';

test.use({ video: { mode: 'on', size: { width: 360, height: 640 } } });

const BG = [255, 230, 176];   // the sheet's floor (PopTokens.FLOOR_TOP[0]) under a white 0.6 panel

function maskOf(img) {
  const m = new Uint8Array(img.width * img.height);
  let sx = 0, sy = 0, n = 0, r = 0, g = 0, b = 0, ink = 0;
  for (let y = 0; y < img.height; y++) for (let x = 0; x < img.width; x++) {
    const i = (y * img.width + x) * 4;
    const [R, G, B] = [img.data[i], img.data[i + 1], img.data[i + 2]];
    const far = Math.abs(R - 255) + Math.abs(G - 243) + Math.abs(B - 222) > 60;   // not the pale panel
    if (far) { m[y * img.width + x] = 1; sx += x; sy += y; n++; r += R; g += G; b += B; }
    if (R < 110 && G < 90 && B < 80) ink++;
  }
  return { m, n, cx: sx / Math.max(1, n), cy: sy / Math.max(1, n), mean: [r / Math.max(1, n), g / Math.max(1, n), b / Math.max(1, n)], ink, w: img.width, h: img.height };
}

function iou(a, b) {
  let inter = 0, uni = 0;
  const dx = Math.round(a.cx - b.cx), dy = Math.round(a.cy - b.cy);
  for (let y = 0; y < a.h; y++) for (let x = 0; x < a.w; x++) {
    const p = a.m[y * a.w + x];
    const bx = x - dx, by = y - dy;
    const q = bx >= 0 && by >= 0 && bx < b.w && by < b.h ? b.m[by * b.w + bx] : 0;
    if (p && q) inter++;
    if (p || q) uni++;
  }
  return inter / Math.max(1, uni);
}

test('the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put', async ({ pop }, testInfo) => {
  test.setTimeout(120_000);
  await pop.open('./#cast');
  const s0 = await pop.state();
  expect(s0.exp).toBe('cast');
  expect(s0.listed.includes('cast'), 'not on the chooser').toBe(false);
  await pop.page.waitForTimeout(1200);
  const box = await pop.page.locator('canvas').boundingBox();
  const k = box.width / s0.window[0];
  const d = s0.view;
  const shapes = {};
  for (const [name, c] of Object.entries(d.icons)) {
    const half = c.s * 0.6;
    const png = await pop.page.screenshot({ clip: { x: box.x + (c.plate[0] - half) * k, y: box.y + (c.plate[1] - half) * k, width: half * 2 * k, height: half * 2 * k } });
    // the bare icon (no white plate): its own outline
    const hb = c.small * 0.75;
    const bare = await pop.page.screenshot({ clip: { x: box.x + (c.bare[0] - hb) * k, y: box.y + (c.bare[1] - hb) * k, width: hb * 2 * k, height: hb * 2 * k } });
    shapes[name] = { plate: maskOf(decodePng(png)), bare: maskOf(decodePng(bare)) };
  }
  let worst = 0, pair = '';
  const names = Object.keys(shapes);
  for (let i = 0; i < names.length; i++) for (let j = 0; j < i; j++) {
    const v = iou(shapes[names[i]].bare, shapes[names[j]].bare);
    if (v > worst) { worst = v; pair = `${names[j]}~${names[i]}`; }
  }
  // the walkers: their feet over three seconds
  const feet = {};
  const motions = new Set();
  let lean = 0;
  for (let t = 0; t < 30; t++) {
    const w = (await pop.state()).view.walkers;
    for (const [i, p] of w.entries()) {
      (feet[i] ??= []).push(p.wy);
      motions.add(p.motion);
      lean = Math.max(lean, Math.abs(p.rot));
    }
    await pop.page.waitForTimeout(100);
  }
  const drift = Math.max(...Object.values(feet).map((ys) => Math.max(...ys) - Math.min(...ys)));
  await pop.shot('art41_cast');
  testInfo.annotations.push({ type: 'cast', description: JSON.stringify({ worst_iou: +worst.toFixed(3), pair, ink: Object.fromEntries(names.map((n) => [n, shapes[n].bare.ink])), mean: Object.fromEntries(names.map((n) => [n, shapes[n].bare.mean.map((v) => Math.round(v))])), feet_drift: drift, lean: +lean.toFixed(3), motions: [...motions] }) });
  expect(names.length, 'the eleven icons').toBe(11);
  for (const n of names) {
    expect(shapes[n].bare.n, `${n} is drawn`).toBeGreaterThan(20);
    expect(shapes[n].plate.ink, `${n} has its ink outline or ink parts on its plate`).toBeGreaterThan(3);
  }
  expect(worst, `no two icons share an outline (${pair})`).toBeLessThan(0.85);
  expect(drift, 'the walkers\' feet stay on their line').toBeLessThan(1.5);
  expect(lean, 'the lean stays small').toBeLessThan(0.12);
  expect(motions.has('walk') && motions.has('idle'), `walking and standing seen ${[...motions]}`).toBe(true);
  expect(pop.errors).toEqual([]);
});

const overlap = (a, b) => a[0] < b[0] + b[2] - 0.5 && b[0] < a[0] + a[2] - 0.5 && a[1] < b[1] + b[3] - 0.5 && b[1] < a[1] + a[3] - 0.5;

async function popOnce(pop) {
  const s = await pop.state();
  if (!s.run.heating && Object.keys(s.run.glass).length === 0 && s.run.cooldown_left <= 0) {
    await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  }
}

async function people(pop) {
  return (await pop.state()).view.cast.people;
}

function clearOf(ps, rects, names) {
  const hits = [];
  for (const p of ps) {
    if (p.alpha < 0.5) continue;
    for (const n of names) if (rects[n] && overlap(p.wbox, rects[n])) hits.push(`${p.who}#${p.id} over ${n}`);
    if (rects.tube && p.wbox[0] + p.wbox[2] > rects.tube[0] + 1) hits.push(`${p.who}#${p.id} over the tube`);
  }
  return hits;
}

test('the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons', async ({ pop }, testInfo) => {
  test.setTimeout(300_000);
  await pop.open('./#factory');
  await expect.poll(async () => (await people(pop)).length, { timeout: 20_000, message: 'the first customers walk in' }).toBeGreaterThan(0);
  await pop.page.waitForTimeout(1500);
  await pop.shot('art41_0m');
  const marks = {};
  let s = await pop.state();
  marks['0m'] = { people: (await people(pop)).length, hits: clearOf(await people(pop), s.rects, ['badge_top']) };
  // to three minutes: the hand pops and the sign is bought when it can be, the clock advanced
  for (let i = 0; i < 18; i++) {
    await popOnce(pop);
    s = await pop.state();
    if (s.run.open.sign && s.run.sign_cost > 0 && s.run.money >= s.run.sign_cost && s.run.sign_tier < 2) {
      await pop.tap('floor_top');
      await pop.tap('upgrade');
      await pop.tap('badge_top');
    }
    await pop.call('dev_advance', 9000);
  }
  await pop.page.waitForTimeout(2000);
  s = await pop.state();
  await pop.shot('art41_3m');
  marks['3m'] = { minute: +(s.run.now_ms / 60000).toFixed(1), sign: s.run.sign_tier, people: (await people(pop)).length, hits: clearOf(await people(pop), s.rects, ['badge_top']) };
  // the rush: sign 8 (bought from its card), on to thirty minutes, the kettle popped by hand
  await pop.call('dev_money', 400000);
  await pop.tap('floor_top');
  for (let t = s.run.sign_tier; t < 8; t++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(8);
  await pop.tap('badge_top');
  while ((await pop.state()).run.now_ms < 30 * 60000) {
    await popOnce(pop);
    await pop.call('dev_advance', 60000);
  }
  // the people walk at their own pace: a few real seconds of the rush
  let most = 0;
  const looks = new Set();
  const hits = [];
  for (let t = 0; t < 12; t++) {
    await popOnce(pop);
    await pop.call('dev_advance', 1500);
    await pop.page.waitForTimeout(400);
    s = await pop.state();
    const ps = s.view.cast.people;
    most = Math.max(most, ps.length);
    for (const p of ps) looks.add(`${p.who}/${p.style}`);
    hits.push(...clearOf(ps, s.rects, ['badge_top']));
  }
  await pop.shot('art41_30m');
  // the buttons over the crowd answer
  await pop.tap('badge_top');
  await expect.poll(async () => (await pop.state()).view.selected, { message: 'the badge opens the shop\'s card' }).toBe(0);
  await pop.shot('art41_30m_card');
  await pop.tap('badge_top');
  await expect.poll(async () => (await pop.state()).view.selected).toBe(-1);
  if ((await pop.state()).rects.news) {
    await pop.tap('news');
    await expect.poll(async () => (await pop.state()).view.news_open, { message: 'the news paper opens over the crowd' }).toBe(true);
    await pop.tap('news');
  }
  s = await pop.state();
  marks['30m'] = { minute: +(s.run.now_ms / 60000).toFixed(1), most, looks: looks.size, stats: s.view.cast.stats, hits: hits.slice(0, 5) };
  const info = await pop.call('dev_render_info');
  testInfo.annotations.push({ type: 'shop', description: JSON.stringify({ ...marks, render: { draw_calls: info.draw_calls, objects: info.objects, fps: info.fps } }) });
  expect(marks['0m'].hits).toEqual([]);
  expect(marks['3m'].hits).toEqual([]);
  expect(hits, 'in the rush nobody stands over the tube or the badge').toEqual([]);
  expect(most, 'the rush is crowded').toBeGreaterThanOrEqual(5);
  expect(looks.size, 'people of many looks').toBeGreaterThanOrEqual(5);
  expect(pop.errors).toEqual([]);
});
