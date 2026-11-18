// Step 39: the career curves are simulations (tools/sim/career39.gd, AUTOMATIC). These are the
// separate real-clock browser checks:
//  1. A fresh factory played for three real minutes with real holds into the gold and the sign
//     bought from its card when the money is there -- no time advance. It checks the game clock
//     keeps to the wall clock, the first sale comes as soon as in the sim, the money a minute is
//     within reach of the sim's skilled hand on the same rules (read from the committed CSV), and
//     the first three minutes offer what they offered before Step 39 (no machine, sign 1-2 prices).
//  2. A rich factory: the sign up to its new tiers 7 and 8 (each draws more than the last), and a
//     seven-figure wallet stays inside the money counter.
import { test, expect } from '../lib/pop.mjs';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const CSV = path.join(HERE, '..', '..', '..', 'evidence', 'step39', 'economy', 'career_after.csv');

function simMinutes(run) {
  // The sim's revenue in its first three minutes and its first sale (career_after.csv rows).
  if (!fs.existsSync(CSV)) return null;
  const [head, ...lines] = fs.readFileSync(CSV, 'utf8').trim().split('\n');
  const cols = head.split(',');
  const rows = lines.map((l) => Object.fromEntries(l.split(',').map((v, i) => [cols[i], v]))).filter((r) => r.run === run);
  const rev = rows.filter((r) => +r.min <= 3).reduce((a, r) => a + +r.revenue_pm, 0);
  const sign3 = rows.find((r) => +r.min === 3);
  return { revenue_3min: rev, sign_at_3: sign3 ? +sign3.sign : null };
}

async function closeCard(pop) {
  const s = await pop.state();
  if (s.view.selected >= 0) await pop.tap(['badge_top', 'badge_mid', 'badge_low'][s.view.selected]);
}

test('real clock: a fresh factory\'s first three minutes against the sim', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name === 'phone', 'p720 is the portrait touch run; three real minutes each');
  test.setTimeout(420_000);
  await pop.open('./#factory');
  let s = await pop.state();
  expect(s.run.machines.length, 'a fresh stand: no machine').toBe(0);
  expect(s.run.sign_tier, 'and sign 0').toBe(0);
  const wall0 = Date.now();
  const clock0 = s.run.now_ms;
  let firstSale = null;
  const marks = {};
  let spent = 0;
  let pops = 0;
  const offered = new Set();
  while (Date.now() - wall0 < 180_000) {
    s = await pop.state();
    const t = Date.now() - wall0;
    if (firstSale === null && s.run.stats.sold >= 1) firstSale = t;
    for (const k of [60, 120, 180]) if (!marks[k] && t >= k * 1000) marks[k] = { money: s.run.money, sign: s.run.sign_tier, sold: s.run.stats.sold, spent };
    for (const m of s.run.machines) offered.add(m.type);
    if (s.run.open.sign && s.run.sign_cost > 0 && s.run.money >= s.run.sign_cost && s.run.sign_tier < 3) {
      const before = s.run.money;
      await pop.tap('floor_top');
      await pop.tap('upgrade');
      await closeCard(pop);
      const after = (await pop.state()).run;
      spent += Math.max(0, before - after.money);
      continue;
    }
    if (!s.run.heating && Object.keys(s.run.glass).length === 0 && s.run.cooldown_left <= 0) {
      await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.3));
      pops++;
    } else {
      await pop.page.waitForTimeout(150);
    }
  }
  s = await pop.state();
  if (!marks[180]) marks[180] = { money: s.run.money, sign: s.run.sign_tier, sold: s.run.stats.sold, spent };
  const wall = Date.now() - wall0;
  const ratio = (s.run.now_ms - clock0) / wall;
  const sim = simMinutes('skilled/balanced/3901');
  const load = os.loadavg()[0];
  testInfo.annotations.push({ type: 'real3min', description: JSON.stringify({ firstSale, marks, pops, ratio: +ratio.toFixed(4), revenue: s.run.stats.revenue, sim, load: +load.toFixed(2) }) });
  expect(ratio, 'the game clock keeps to the wall clock').toBeGreaterThan(0.95);
  expect(ratio).toBeLessThan(1.03);
  expect(firstSale, 'the first sale within half a minute (the sim: 10-16 s)').not.toBeNull();
  expect(firstSale).toBeLessThan(30_000);
  expect(marks[180].sign, 'the sign bought at least once in three minutes').toBeGreaterThanOrEqual(1);
  expect(s.run.machines.length, 'no machine in the first three minutes (as before Step 39)').toBe(0);
  if (sim && load < 12) {
    // real holds, real taps and the browser's own delays: within reach of the sim's skilled hand
    expect(s.run.stats.revenue, `three minutes' sales near the sim's skilled hand (${sim.revenue_3min})`).toBeGreaterThan(sim.revenue_3min * 0.5);
  }
});

test('a rich factory: the sign\'s new tiers draw more, and a seven-figure wallet fits the counter', async ({ pop }, testInfo) => {
  test.setTimeout(180_000);
  await pop.open('./#factory');
  let s = await pop.state();
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  await pop.call('dev_money', 400000);
  await pop.tap('floor_top');
  const lit = [];
  for (let tier = 1; tier <= 8; tier++) {
    await pop.tap('upgrade');
    await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(tier);
    if (tier >= 6) {
      await pop.page.waitForTimeout(1500);   // the upgrade's sparkle gone
      s = await pop.state();
      const r = s.rects.sign;
      const pad = r[3] * 1.2;
      const png = await pop.page.screenshot({ clip: { x: Math.max(0, r[0] - pad), y: Math.max(0, r[1] - pad), width: r[2] + pad * 2, height: r[3] + pad * 2 } });
      const { decodePng } = await import('../lib/png.mjs');
      const img = decodePng(png);
      let warm = 0;
      for (let i = 0; i < img.data.length; i += 4) {
        const [R, G, B] = [img.data[i], img.data[i + 1], img.data[i + 2]];
        if (R > 230 && G > 190 && B < 200) warm++;   // gold stars, bulbs, searchlights
      }
      lit.push({ tier, warm });
      await pop.shot(`career39_sign${tier}`);
    }
  }
  expect(s.run.sign_cost, 'tier 8 is the last').toBe(-1);
  testInfo.annotations.push({ type: 'sign', description: JSON.stringify(lit) });
  expect(lit[1].warm, 'tier 7 lights more than the landmark (searchlights)').toBeGreaterThan(lit[0].warm);
  expect(lit[2].warm, 'tier 8 lights more than tier 7 (stars and the arrow)').toBeGreaterThan(lit[1].warm);
  await closeCard(pop);
  await pop.call('dev_money', 9876543);
  await pop.page.waitForTimeout(500);
  s = await pop.state();
  const m = s.rects.money;
  expect(m, 'the money counter is on screen').toBeTruthy();
  const vp = pop.page.viewportSize();
  expect(m[0] + m[2], 'the counter inside the screen').toBeLessThanOrEqual(vp.width + 1);
  // the counter's own box: ink only inside it (the number shrinks to fit)
  const png = await pop.page.screenshot({ clip: { x: Math.max(0, m[0] - 40), y: m[1], width: Math.min(vp.width - Math.max(0, m[0] - 40), m[2] + 80), height: m[3] } });
  const { decodePng } = await import('../lib/png.mjs');
  const img = decodePng(png);
  let inkOutside = 0;
  const left = m[0] - Math.max(0, m[0] - 40);
  for (let y = 0; y < img.height; y++) for (let x = 0; x < img.width; x++) {
    const i = (y * img.width + x) * 4;
    const dark = img.data[i] < 80 && img.data[i + 1] < 80 && img.data[i + 2] < 80;
    if (dark && (x < left - 2 || x > left + m[2] + 2)) inkOutside++;
  }
  await pop.shot('career39_money7');
  testInfo.annotations.push({ type: 'money', description: JSON.stringify({ rect: m, inkOutside }) });
  expect(inkOutside, 'the seven-figure number stays inside its counter').toBeLessThan(20);
});
