// Step 36: the cast and the shop's popularity in a real browser. A new shop's first customer is
// the classic one asking for a small Classic Butter. Built by taps (two kettles, a hopper, the
// sprayer on cheese, the coater on caramel), the shop then sees several kinds of people, each in
// their own silhouette (a student's headphones are on screen when one waits), with their own
// orders; customers served in good humour leave with an arm up and a heart and lift the stars on
// the board; when the kitchen stops, people walk past or give up (a sad face, no blame) and the
// stars fall; the sign's card shows the stars and their effect on foot traffic.
import { test, expect } from '../lib/pop.mjs';
import { decodePng } from '../lib/png.mjs';

const overlap = (a, b) => a[0] < b[0] + b[2] - 0.5 && b[0] < a[0] + a[2] - 0.5 && a[1] < b[1] + b[3] - 0.5 && b[1] < a[1] + a[3] - 0.5;

function countNear(png, rect, rgb, tol = 12) {
  let n = 0;
  const [x0, y0, w, h] = rect.map((v) => Math.round(v));
  for (let y = Math.max(0, y0); y < Math.min(png.height, y0 + h); y++) {
    for (let x = Math.max(0, x0); x < Math.min(png.width, x0 + w); x++) {
      const i = (y * png.width + x) * 4;
      if (Math.abs(png.data[i] - rgb[0]) <= tol && Math.abs(png.data[i + 1] - rgb[1]) <= tol && Math.abs(png.data[i + 2] - rgb[2]) <= tol) n++;
    }
  }
  return n;
}

async function closeCardOver(pop, rect) {
  const s = await pop.state();
  if (s.rects.detail && s.view.selected >= 0 && overlap(rect, s.rects.detail)) {
    await pop.tap(['badge_top', 'badge_mid', 'badge_low'][s.view.selected]);
    await expect.poll(async () => !!(await pop.state()).rects.detail).toBe(false);
  }
}

async function build(pop, type, floor) {
  let s = await pop.state();
  const taken = new Set(s.run.machines.filter((m) => m.floor === floor).map((m) => m.slot));
  let k = 0;
  while (taken.has(k)) k++;
  await closeCardOver(pop, s.rects[`slot_${floor}_${k}`]);
  const n = s.run.machines.length;
  await pop.tap(`slot_${floor}_${k}`);
  await expect.poll(async () => !!(await pop.state()).rects[`pick_${type}`]).toBe(true);
  await pop.tap(`pick_${type}`);
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.machines.length).toBe(n + 1);
  s = await pop.state();
  return s.run.machines[s.run.machines.length - 1];
}

test('a classic first customer, then a cast with their own tastes, faces and stars', async ({ pop }, testInfo) => {
  test.setTimeout(600_000);
  await pop.open('./#factory');
  let s = await pop.state();
  expect(s.run.queue_who[0], 'the first customer is the classic one').toBe('classic');
  expect([s.run.orders_recipe[0], s.run.orders[0]], 'asking for a small Classic Butter').toEqual(['plain', 2]);
  expect(s.run.stars, 'an average shop: three stars').toBe(3);
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  await pop.call('dev_money', 200000);
  await pop.tap('floor_top');
  for (let i = 0; i < 6; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(6);
  await pop.tap('floor_mid');
  for (let i = 0; i < 3; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier).toBe(3);
  for (const t of ['cooker', 'cooker', 'M01']) await build(pop, t, 'kitchen');
  await build(pop, 'P05', 'packing');
  await build(pop, 'P06', 'packing');
  s = await pop.state();
  if (s.view.selected >= 0) await pop.tap(['badge_top', 'badge_mid', 'badge_low'][s.view.selected]);

  // Run: the hand pops now and then; watch who comes, and catch a student on screen.
  let studentPx = 0;
  let thanks = false;
  const p0 = (await pop.state()).run.popularity;
  for (let i = 0; i < 50; i++) {
    s = await pop.state();
    if (!s.run.heating && Object.keys(s.run.glass).length === 0 && s.run.cooldown_left <= 0 && i % 2 === 0) {
      await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
    }
    const r = await pop.call('dev_advance', 3000);
    if ((r.state.view.leaving_moods || []).includes('thanks')) thanks = true;
    if (!studentPx && (r.state.view.who || []).includes('student')) {
      await pop.page.waitForTimeout(400);
      const png = decodePng(await pop.page.screenshot());
      const k = png.width / r.state.window[0];
      studentPx = countNear(png, r.state.rects.floor_top.map((v) => v * k), [64, 140, 217], 14);   // headphone cups
      if (studentPx) await pop.shot('customers36_cast');
    }
    const who = Object.keys(r.state.run.stats.arrived_who || {});
    if (who.length >= 4 && studentPx && thanks && r.state.run.stats.sold >= 30 && i >= 12) break;
  }
  s = await pop.state();
  const st = s.run.stats;
  testInfo.annotations.push({ type: 'cast', description: JSON.stringify({ arrived_who: st.arrived_who, passed_by_who: st.passed_by_who, sold: st.sold, happy: st.happy_sales, popularity: [p0, s.run.popularity], stars: s.run.stars, favorite: s.run.favorite, studentPx, thanks, flavor_sold: st.flavor_sold }) });
  expect(Object.keys(st.arrived_who || {}).length, 'several kinds of people came').toBeGreaterThanOrEqual(4);
  expect(studentPx, "a student's headphones were on screen").toBeGreaterThan(5);
  expect(thanks, 'a served customer left with thanks (arm up, heart)').toBe(true);
  expect(st.happy_sales || 0, 'happy customers counted').toBeGreaterThan(0);
  expect(s.run.popularity, 'they lifted the popularity').toBeGreaterThan(p0);
  expect(s.run.favorite, 'the board knows the favorite').not.toBe('');
  for (const e of s.run.ledger) expect(e.recipe).toBe(e.ordered_recipe);
  expect(s.run.portions_everywhere).toBe(st.made_portions);

  // The sign's card: stars and what they do (x1.00 and above).
  await pop.tap('floor_top');
  await pop.page.waitForTimeout(300);
  await pop.shot('customers36_sign_card');
  await pop.tap('floor_top');

  // The kitchen stops: people walk past or give up, faces fall, the stars come down.
  const before = (await pop.state()).run;
  // (as a player would: open a kettle's card and pause its floor)
  const k0 = before.machines.find((m) => m.floor === 'kitchen');
  await closeCardOver(pop, (await pop.state()).rects[`slot_kitchen_${k0.slot}`]);
  await pop.tap(`slot_kitchen_${k0.slot}`);
  await expect.poll(async () => !!(await pop.state()).rects.m_group).toBe(true);
  await pop.tap('m_group');
  await expect.poll(async () => (await pop.state()).run.machines.filter((m) => m.floor === 'kitchen').every((m) => m.state === 'paused')).toBe(true);
  let sad = false;
  for (let i = 0; i < 40; i++) {
    const r = await pop.call('dev_advance', 4000);
    if ((r.state.view.leaving_moods || []).includes('sad')) sad = true;
    if (sad && r.state.run.stats.abandoned > before.stats.abandoned + 3 && r.state.run.popularity < before.popularity) break;
  }
  s = await pop.state();
  testInfo.annotations.push({ type: 'stopped', description: JSON.stringify({ abandoned: [before.stats.abandoned, s.run.stats.abandoned], passed: [before.stats.passed_by, s.run.stats.passed_by], popularity: [before.popularity, s.run.popularity], stars: s.run.stars }) });
  expect(sad, 'someone who gave up left with a sad face').toBe(true);
  expect(s.run.popularity, 'the popularity came down').toBeLessThan(before.popularity);
  expect(s.run.queue, 'the queue keeps its cap').toBeLessThanOrEqual(s.run.queue_cap);
  await pop.shot('customers36_stopped');
  expect(s.run.portions_everywhere).toBe(s.run.stats.made_portions);
});
