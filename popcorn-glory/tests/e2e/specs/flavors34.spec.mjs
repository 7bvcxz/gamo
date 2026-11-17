// Step 34: five flavors in a real browser. The #flavors sheet draws each one's kernels, bag, cup
// and coating (each column carries its own colour). Then the factory, built the way a player
// builds it -- two kettles, a hopper and the flavor base mixer in the kitchen; on the packing
// floor the seasoning sprayer twice and the coater twice, their flavors chosen on each machine's
// card (cheese, spicy, caramel, cocoa) -- runs until every flavor has been coated, packed, asked
// for and sold to the customer who asked (Classic Butter too). The coaters' flavors survive a
// reload; a pick of a flavor the machine cannot make does nothing.
import { test, expect } from '../lib/pop.mjs';
import { decodePng } from '../lib/png.mjs';

const FIVE = ['plain', 'cheese', 'spicy', 'caramel', 'cocoa'];
// Each flavor's kernel fill (art/factory_art.gd FLAVOR_LOOK), 0-255.
const FILL = { plain: [255, 246, 232], cheese: [255, 184, 56], spicy: [250, 115, 64], caramel: [230, 153, 61], cocoa: [133, 82, 51] };

function countNear(png, rect, rgb, tol = 10) {
  let n = 0;
  const [x0, y0, w, h] = rect.map((v) => Math.round(v));
  for (let y = Math.max(0, y0); y < Math.min(png.height, y0 + h); y += 2) {
    for (let x = Math.max(0, x0); x < Math.min(png.width, x0 + w); x += 2) {
      const i = (y * png.width + x) * 4;
      if (Math.abs(png.data[i] - rgb[0]) <= tol && Math.abs(png.data[i + 1] - rgb[1]) <= tol && Math.abs(png.data[i + 2] - rgb[2]) <= tol) n++;
    }
  }
  return n;
}

test('the flavors sheet draws five distinct flavors on this screen', async ({ pop }, testInfo) => {
  await pop.open('./#flavors');
  const s = await pop.state();
  expect(s.exp).toBe('flavors');
  expect(s.listed.includes('flavors'), 'not on the chooser').toBe(false);
  await pop.page.waitForTimeout(800);
  await pop.shot('flavors34_sheet');
  const png = decodePng(await pop.page.screenshot());
  const k = png.width / s.window[0];
  const wide = s.window[0] > s.window[1] * 1.15;
  const counts = {};
  for (let i = 0; i < 5; i++) {
    // Columns on a wide screen, rows on a tall one (variants/flavors/flavors_view.gd).
    const r = wide ? [png.width * (i / 5), 0, png.width / 5, png.height] : [0, png.height * (0.1 + i * 0.165), png.width, png.height * 0.165];
    counts[FIVE[i]] = countNear(png, r, FILL[FIVE[i]]);
  }
  testInfo.annotations.push({ type: 'flavor pixels', description: JSON.stringify({ counts, scale: k }) });
  for (const f of FIVE) expect(counts[f], `${f}'s kernels are drawn in its own colour`).toBeGreaterThan(20);
});

async function opened(pop) {
  await pop.open('./#factory');
  const s = await pop.state();
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  await pop.call('dev_money', 200000);
  await pop.tap('floor_top');
  for (let i = 0; i < 6; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(6);
  await pop.tap('floor_mid');
  for (let i = 0; i < 3; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier).toBe(3);
}

const overlap = (a, b) => a[0] < b[0] + b[2] - 0.5 && b[0] < a[0] + a[2] - 0.5 && a[1] < b[1] + b[3] - 0.5 && b[1] < a[1] + a[3] - 0.5;

async function build(pop, type, floor) {
  let s = await pop.state();
  const taken = new Set(s.run.machines.filter((m) => m.floor === floor).map((m) => m.slot));
  let k = 0;
  while (taken.has(k)) k++;
  if (s.rects.detail && s.view.selected >= 0 && overlap(s.rects[`slot_${floor}_${k}`], s.rects.detail)) {
    await pop.tap(['badge_top', 'badge_mid', 'badge_low'][s.view.selected]);
    await expect.poll(async () => !!(await pop.state()).rects.detail).toBe(false);
  }
  const n = s.run.machines.length;
  await pop.tap(`slot_${floor}_${k}`);
  await expect.poll(async () => !!(await pop.state()).rects[`pick_${type}`], { message: `${type} in the ${floor} picker` }).toBe(true);
  await pop.tap(`pick_${type}`);
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.machines.length, { message: `${type} built` }).toBe(n + 1);
  s = await pop.state();
  return s.run.machines[s.run.machines.length - 1];
}

async function choose(pop, m, flavor) {
  // Select the machine (its place), then its card's flavor.
  let s = await pop.state();
  if (s.view.sel_machine !== m.id) {
    if (s.rects.detail && s.view.selected >= 0 && overlap(s.rects[`slot_${m.floor}_${m.slot}`], s.rects.detail)) {
      await pop.tap(['badge_top', 'badge_mid', 'badge_low'][s.view.selected]);
      await expect.poll(async () => !!(await pop.state()).rects.detail).toBe(false);
    }
    await pop.tap(`slot_${m.floor}_${m.slot}`);
    await expect.poll(async () => (await pop.state()).view.sel_machine).toBe(m.id);
  }
  await expect.poll(async () => !!(await pop.state()).rects[`flavor_${flavor}`], { message: `${flavor} on the card` }).toBe(true);
  await pop.tap(`flavor_${flavor}`);
  await expect.poll(async () => (await pop.state()).run.coaters.find((c) => c.id === m.id)?.flavor, { message: `${m.type} set to ${flavor}` }).toBe(flavor);
}

test('five flavors are coated, packed, asked for and sold in the browser', async ({ pop }, testInfo) => {
  test.setTimeout(600_000);
  await opened(pop);
  for (const t of ['cooker', 'cooker', 'M01', 'M12']) await build(pop, t, 'kitchen');
  const sprayA = await build(pop, 'P05', 'packing');
  const coatA = await build(pop, 'P06', 'packing');
  const sprayB = await build(pop, 'P05', 'packing');
  const coatB = await build(pop, 'P06', 'packing');
  let s = await pop.state();
  expect(s.run.coaters.map((c) => c.flavor), 'new coaters start on their first flavor').toEqual(['cheese', 'caramel', 'cheese', 'caramel']);
  // The sprayer's card offers cheese and spicy only (no caramel chip); the coater's caramel and cocoa.
  await choose(pop, sprayB, 'spicy');
  s = await pop.state();
  expect(!!s.rects.flavor_caramel, 'the sprayer has no caramel').toBe(false);
  await pop.shot('flavors34_card_sprayer');
  await choose(pop, coatB, 'cocoa');
  await pop.shot('flavors34_card_coater');
  s = await pop.state();
  expect(s.run.coaters.map((c) => c.flavor)).toEqual(['cheese', 'caramel', 'spicy', 'cocoa']);
  expect(s.run.flavors.every((f) => f.open), 'sign 6 and packing 3: all five open').toBe(true);

  // Run: the hand pops now and then; game time in steps (the model runs as it does live).
  const seen = new Set();
  // (Step 36: the cast asks for cocoa less often -- price-sensitive students and butter fans -- so up
  // to ten game minutes; it stops as soon as all five have sold)
  for (let i = 0; i < 120; i++) {
    s = await pop.state();
    if (!s.run.heating && Object.keys(s.run.glass).length === 0 && i % 2 === 0) {
      await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
    }
    const r = await pop.call('dev_advance', 5000);
    for (const c of r.state.run.coaters) if (c.state === 'run') seen.add(c.flavor);
    if (i === 20) await pop.shot('flavors34_running');
    const sold = r.state.run.stats.flavor_sold || {};
    const plain = r.state.run.ledger.some((e) => e.recipe === 'plain');
    if (FIVE.slice(1).every((f) => (sold[f] || 0) >= 1) && plain && i >= 24) break;
  }
  s = await pop.state();
  const sold = s.run.stats.flavor_sold || {};
  testInfo.annotations.push({ type: 'flavor trade', description: JSON.stringify({ sold, revenue: s.run.stats.flavor_revenue, coated: s.run.stats.coated, ingredients: s.run.stats.ingredient_coins, minutes: s.run.flow_ms / 60000, sold_total: s.run.stats.sold, seen_coating: [...seen] }) });
  for (const f of ['cheese', 'spicy', 'caramel', 'cocoa']) {
    expect(sold[f] || 0, `${f} sold`).toBeGreaterThanOrEqual(1);
    // Coated by its machine (a batch is 1-12 s: a snapshot every 5 s of play can miss it running).
    expect((s.run.stats.coated || {})[f] || 0, `${f} was coated from plain portions`).toBeGreaterThanOrEqual(4);
  }
  expect(s.run.ledger.some((e) => e.recipe === 'plain'), 'Classic Butter sold').toBe(true);
  for (const e of s.run.ledger) expect(e.recipe, 'every sale is the flavor ordered').toBe(e.ordered_recipe);
  expect(s.run.stats.wrong_sku || 0).toBe(0);
  expect(s.run.portions_everywhere, 'every portion made is somewhere').toBe(s.run.stats.made_portions);
  expect(s.run.money).toBeGreaterThanOrEqual(0);
  expect(s.run.stats.ingredient_coins, 'ingredients were paid in coins').toBeGreaterThan(0);
  // On screen: the packing floor's bin and shelf, and the queue's bubbles, carry the flavors' colours.
  await pop.page.waitForTimeout(500);
  const png = decodePng(await pop.page.screenshot());
  const k = png.width / s.window[0];
  const area = ['floor_top', 'floor_mid'].map((n) => s.rects[n].map((v) => v * k));
  const vis = {};
  for (const f of ['cheese', 'spicy', 'caramel', 'cocoa']) vis[f] = area.reduce((a, r) => a + countNear(png, r, FILL[f], 8), 0);
  testInfo.annotations.push({ type: 'flavor pixels on the floors', description: JSON.stringify(vis) });
  expect(Object.values(vis).filter((v) => v > 0).length, 'flavored popcorn is visible on the floors').toBeGreaterThanOrEqual(2);
  await pop.shot('flavors34_sold');

  // A reload keeps every coater's flavor (the factory's save).
  await pop.call('dev_save');
  const before = s.run.coaters.map((c) => [c.id, c.flavor]);
  await pop.page.reload();
  await pop.ready();
  await expect.poll(async () => (await pop.state()).exp).toBe('factory');
  const after = (await pop.state()).run;
  expect(after.coaters.map((c) => [c.id, c.flavor]), 'the flavors after a reload').toEqual(before);
  expect(after.portions_everywhere).toBe(after.stats.made_portions);
});
