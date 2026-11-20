// Step 35: flavor craftsmanship in a real browser. The factory is built by taps (two kettles, a
// hopper, the flavor base mixer; on the packing floor the sprayer on cheese and the coater on
// caramel, then the coater set to AUTO on its card). No spoon is offered until the hand has
// popped twenty times (real holds on the kettle). Then, while a batch is on the coater's drum, a
// real hold on its spoon, let go in the flavor's gold, finishes it by hand: the model counts the
// grade, the still a moment later shows the gold flourish, and the bags carrying the hand's
// portions sell above the machine's best of that flavor (Step 37: a large bag may mix them). The machine's own batches come out
// below 100 with their losses counted; a mixed bag (half caramel, half cheese) is asked for and
// sold; the coater's card shows its payback; every portion made is somewhere; a reload keeps AUTO.
import { test, expect } from '../lib/pop.mjs';
import { decodePng } from '../lib/png.mjs';

const overlap = (a, b) => a[0] < b[0] + b[2] - 0.5 && b[0] < a[0] + a[2] - 0.5 && a[1] < b[1] + b[3] - 0.5 && b[1] < a[1] + a[3] - 0.5;

function countNear(png, rect, rgb, tol = 10) {
  let n = 0;
  const [x0, y0, w, h] = rect.map((v) => Math.round(v));
  for (let y = Math.max(0, y0); y < Math.min(png.height, y0 + h); y += 1) {
    for (let x = Math.max(0, x0); x < Math.min(png.width, x0 + w); x += 1) {
      const i = (y * png.width + x) * 4;
      if (Math.abs(png.data[i] - rgb[0]) <= tol && Math.abs(png.data[i + 1] - rgb[1]) <= tol && Math.abs(png.data[i + 2] - rgb[2]) <= tol) n++;
    }
  }
  return n;
}

function turnedGold(a, b, rect, rgb = [255, 204, 77], tol = 40) {
  const near = (png, i) => Math.abs(png.data[i] - rgb[0]) <= tol && Math.abs(png.data[i + 1] - rgb[1]) <= tol && Math.abs(png.data[i + 2] - rgb[2]) <= tol;
  let n = 0;
  const [x0, y0, w, h] = rect.map((v) => Math.round(v));
  for (let y = Math.max(0, y0); y < Math.min(b.height, y0 + h); y++) {
    for (let x = Math.max(0, x0); x < Math.min(b.width, x0 + w); x++) {
      const i = (y * b.width + x) * 4;
      if (near(b, i) && !near(a, i)) n++;
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
  await expect.poll(async () => !!(await pop.state()).rects[`pick_${type}`], { message: `${type} in the ${floor} picker` }).toBe(true);
  await pop.tap(`pick_${type}`);
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.machines.length, { message: `${type} built` }).toBe(n + 1);
  s = await pop.state();
  return s.run.machines[s.run.machines.length - 1];
}

async function select(pop, m) {
  let s = await pop.state();
  if (s.view.sel_machine === m.id) return;
  await closeCardOver(pop, s.rects[`slot_${m.floor}_${m.slot}`]);
  await pop.tap(`slot_${m.floor}_${m.slot}`);
  await expect.poll(async () => (await pop.state()).view.sel_machine).toBe(m.id);
}

async function pop20(pop) {
  // Real holds on the kettle until the hand has popped twenty times (the spoon's threshold).
  for (let i = 0; i < 300; i++) {
    const s = await pop.state();
    if (s.run.presses >= 20) return;
    if (!s.run.heating && Object.keys(s.run.glass).length === 0 && s.run.cooldown_left <= 0) {
      await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
    }
    await pop.call('dev_advance', 1500);
  }
}

test('the spoon finishes a batch by hand; the machine, the mix and the payback stay honest', async ({ pop }, testInfo) => {
  test.setTimeout(600_000);
  await pop.open('./#factory');
  let s = await pop.state();
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  await pop.call('dev_money', 200000);
  await pop.tap('floor_top');
  for (let i = 0; i < 6; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(6);
  await pop.tap('floor_mid');
  for (let i = 0; i < 3; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier).toBe(3);
  for (const t of ['cooker', 'cooker', 'M01', 'M12']) await build(pop, t, 'kitchen');
  const spray = await build(pop, 'P05', 'packing');
  const coat = await build(pop, 'P06', 'packing');
  s = await pop.state();
  expect(s.run.coaters.map((c) => c.flavor), 'cheese and caramel').toEqual(['cheese', 'caramel']);
  expect(s.run.hand_open, 'a few pops: no spoon yet').toBe(false);
  // The coater's card: AUTO is one tap, and the payback bar is there.
  await select(pop, coat);
  await expect.poll(async () => !!(await pop.state()).rects.flavor_auto).toBe(true);
  await pop.tap('flavor_auto');
  await expect.poll(async () => (await pop.state()).run.coaters.find((c) => c.id === coat.id)?.mode).toBe('auto');
  await pop.shot('craft35_card_auto');
  for (let i = 0; i < 6; i++) {
    const r = await pop.call('dev_advance', 4000);
    expect(Object.keys(r.state.rects).some((k) => k.startsWith('spoon_')), 'no spoon before the hand cooks comfortably').toBe(false);
  }
  await pop20(pop);
  s = await pop.state();
  expect(s.run.presses, 'twenty pops by hand').toBeGreaterThanOrEqual(20);
  expect(s.run.hand_open, 'the spoon is open').toBe(true);

  // Wait for a batch on a drum, then a real hold on its spoon, let go in its gold.
  let spoon = null;
  for (let i = 0; i < 120 && !spoon; i++) {
    s = await pop.state();
    const c = s.run.coaters.find((x) => x.can_finish && s.rects[`spoon_${x.id}`]);
    if (c) { spoon = c; break; }
    if (!s.run.heating && Object.keys(s.run.glass).length === 0 && s.run.cooldown_left <= 0 && i % 2 === 0) {
      await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
    }
    await pop.call('dev_advance', 500);
  }
  expect(spoon, 'a batch on a drum with its spoon').toBeTruthy();
  await closeCardOver(pop, s.rects[`spoon_${spoon.id}`]);
  s = await pop.state();
  const fl = s.run.coaters.find((x) => x.id === spoon.id).held;
  const gold = { cheese: [500, 1300], spicy: [700, 1250], caramel: [1100, 1450], cocoa: [900, 1300] }[fl];
  const before = s.run.stats.hand_finish || {};
  const pre = decodePng(await pop.page.screenshot());   // the same place just before: the baseline
  // Real input latency only adds to a hold: aim a quarter of the way into the gold.
  await pop.hold(`spoon_${spoon.id}`, Math.round(gold[0] + (gold[1] - gold[0]) * 0.25));
  await pop.page.waitForTimeout(450);
  const still = decodePng(await pop.page.screenshot());
  // Under load (the Step 46 full run, load ~12) the release can land after the 450 ms still:
  // wait for the grade itself, a few seconds at most, before reading it.
  const graded0 = () => { const a = s.run.stats.hand_finish || {}; return Object.keys(a).some((g) => (a[g] || 0) > (before[g] || 0)); };
  for (let i = 0; i < 25; i++) { s = await pop.state(); if (graded0()) break; await pop.page.waitForTimeout(200); }
  const after = s.run.stats.hand_finish || {};
  const graded = Object.keys(after).find((g) => (after[g] || 0) > (before[g] || 0));
  testInfo.annotations.push({ type: 'spoon', description: JSON.stringify({ flavor: fl, gold, graded, hand_finish: after, hand_portions: s.run.stats.hand_portions }) });
  expect(['perfect', 'near'], `the hold was judged in or by the gold (${graded})`).toContain(graded);
  await pop.shot('craft35_finished');
  // The still 0.45 s after the release shows the flourish: gold round the coater.
  const k = still.width / s.window[0];
  const sm = s.run.machines.find((m) => m.id === spoon.id);
  const mr = s.rects[`slot_${sm.floor}_${sm.slot}`].map((v) => v * k);
  const area = [mr[0] - mr[2], mr[1] - mr[3] * 1.4, mr[2] * 3, mr[3] * 3];
  const goldPx = countNear(still, area, [255, 204, 77], 40);
  const goldPre = countNear(pre, area, [255, 204, 77], 40);
  const turned = turnedGold(pre, still, area);   // pixels gold now that were not just before
  testInfo.annotations.push({ type: 'flourish', description: JSON.stringify({ goldPx, goldPre, turned, area }) });
  expect(turned, 'the finish turns pixels round the coater gold in a still (against the same place before)').toBeGreaterThan(150);

  // Run until the hand's portions, a mix and the machine's batches are sold. Every sale row is
  // kept as it passes (the state shows the last 20): a bag may carry the hand's portions beside
  // the machine's (Step 37 found it: large bags from Step 36's cast), so the hand's work is judged
  // by the quality of the bags it is in, against the machine's own bags of the same flavor.
  const seen = new Map();
  const note = (rows) => { for (const e of rows) seen.set(e.pack, e); };
  const handRows = () => [...seen.values()].filter((e) => (e.hand || 0) > 0);
  const machineRows = () => [...seen.values()].filter((e) => e.recipe === fl && !(e.hand > 0));
  for (let i = 0; i < 90; i++) {
    s = await pop.state();
    if (!s.run.heating && Object.keys(s.run.glass).length === 0 && s.run.cooldown_left <= 0 && i % 2 === 0) {
      await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
    }
    const r = await pop.call('dev_advance', 5000);
    const st = r.state.run.stats;
    note(r.state.run.ledger);
    if ((st.hand_sold_portions || 0) >= (st.hand_portions || 1) && handRows().length > 0 && (st.mix_sold || 0) >= 1 && machineRows().length > 0 && i >= 10) break;
  }
  s = await pop.state();
  const st = s.run.stats;
  const coaterRow = s.run.coaters.find((c) => c.id === coat.id);
  testInfo.annotations.push({ type: 'craft trade', description: JSON.stringify({ hand_sold_portions: st.hand_sold_portions, mix_sold: st.mix_sold, lost: st.lost, lost_portions: st.lost_portions, flavor_sold: st.flavor_sold, coater: coaterRow, minutes: s.run.flow_ms / 60000 }) });
  expect(st.hand_sold_portions || 0, "the hand's portions were sold").toBeGreaterThanOrEqual(2);
  const handBest = Math.max(...handRows().map((e) => e.quality));
  const machineBest = Math.max(...machineRows().map((e) => e.quality));
  testInfo.annotations.push({ type: 'hand bags', description: JSON.stringify({ hand_rows: handRows().map((e) => [e.recipe, e.size, e.hand, e.quality]), machine_best: machineBest, all_hand_q100: st.hand_perfect_bags_sold || 0 }) });
  expect(handRows().length, "bags with the hand's portions were sold").toBeGreaterThan(0);
  expect(machineBest, "the machine's own flavor bags sell below 100").toBeLessThan(100);
  expect(handBest, "a bag with the hand's portions sells above the machine's best of that flavor").toBeGreaterThan(machineBest);
  expect(st.mix_sold || 0, 'a mixed bag was asked for and sold').toBeGreaterThanOrEqual(1);
  for (const e of s.run.ledger) expect(e.recipe, 'every sale is what was ordered').toBe(e.ordered_recipe);
  expect(st.wrong_sku || 0).toBe(0);
  expect(s.run.portions_everywhere, 'every portion made (and lost) is somewhere').toBe(st.made_portions);
  expect(coaterRow.net, "the coater's payback: margin - ingredients - upkeep").toBe(coaterRow.margin - coaterRow.ingredients - coaterRow.upkeep);
  expect(coaterRow.margin, 'its bags sold for more than butter').toBeGreaterThan(0);
  await select(pop, coat);
  await pop.page.waitForTimeout(300);
  await pop.shot('craft35_card_payback');
  await pop.shot('craft35_running');

  // A reload keeps AUTO (the factory's save).
  await pop.call('dev_save');
  await pop.page.reload();
  await pop.ready();
  await expect.poll(async () => (await pop.state()).exp).toBe('factory');
  const again = (await pop.state()).run;
  expect(again.coaters.find((c) => c.id === coat.id).mode, 'AUTO after a reload').toBe('auto');
  expect(again.portions_everywhere).toBe(again.stats.made_portions);
});
