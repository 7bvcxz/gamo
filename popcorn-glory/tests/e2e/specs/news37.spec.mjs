// Step 37: the news in a real browser. A shop built by taps (two kettles, a hopper, a filler, the
// coater on caramel) hears no news while it opens; its paper icon (top right of the shop) is grey
// and opens a quiet paper. A caramel craze starts: a strip slides out of the icon, the icon shows a
// red unread count and the time left; the coater making caramel carries a small paper mark. B's
// ring keeps working through all of it -- with the strip out and with the paper open. The paper
// shows the craze (the caramel bag, x2 beside a customer, the time, what it has sold) and its
// focus button puts caramel first. A hidden tab stops the news's clock. The craze brings real
// caramel customers (more than the same minutes after it) and no coin from nothing; after it, the
// modifier is gone, the badge does not call stale news and the paper keeps it as past news; a
// reload keeps a running festival and its time.
import { test, expect } from '../lib/pop.mjs';
import { decodePng } from '../lib/png.mjs';

const overlap = (a, b) => a[0] < b[0] + b[2] - 0.5 && b[0] < a[0] + a[2] - 0.5 && a[1] < b[1] + b[3] - 0.5 && b[1] < a[1] + a[3] - 0.5;

function countNear(png, rect, rgb, tol = 30) {
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
  await expect.poll(async () => !!(await pop.state()).rects[`pick_${type}`], { message: `${type} in the ${floor} picker` }).toBe(true);
  await pop.tap(`pick_${type}`);
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.machines.length, { message: `${type} built` }).toBe(n + 1);
  s = await pop.state();
  return s.run.machines[s.run.machines.length - 1];
}

// One real hold on the ring when the kettle is free; true when a press happened.
async function cook(pop) {
  const s = await pop.state();
  if (s.run.heating || Object.keys(s.run.glass).length > 0 || s.run.cooldown_left > 0) return false;
  const before = s.run.presses;
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.presses, { message: 'the ring took the press' }).toBe(before + 1);
  return true;
}

const card = (s) => s.run.news;

test('the news: quiet at opening, a craze that brings real customers, readable, never in the way', async ({ pop }, testInfo) => {
  test.setTimeout(600_000);
  await pop.open('./#factory');
  let s = await pop.state();
  expect(s.rects.news, 'the paper icon is on the shop floor').toBeTruthy();
  expect(card(s).active.length + card(s).log.length, 'no news at opening').toBe(0);
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  s = await pop.state();
  expect(card(s).next_in_ms, 'the first news is minutes away when the sign opens').toBeGreaterThanOrEqual(170_000);
  // A quiet paper: tap the icon, a grey paper; tap the paper, it folds.
  await pop.tap('news');
  await expect.poll(async () => (await pop.state()).view.news_open).toBe(true);
  await pop.page.waitForTimeout(300);
  await pop.shot('news37_quiet');
  await pop.tap('detail');
  await expect.poll(async () => (await pop.state()).view.news_open).toBe(false);

  // The shop: sign 6, packing 3, two kettles and a hopper, a filler and the coater on caramel.
  await pop.call('dev_money', 300000);
  await pop.tap('floor_top');
  for (let i = 0; i < 6; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(6);
  await pop.tap('floor_mid');
  for (let i = 0; i < 3; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier).toBe(3);
  for (const t of ['cooker', 'cooker', 'M01']) await build(pop, t, 'kitchen');
  const coat = await build(pop, 'P06', 'packing');
  s = await pop.state();
  if (s.view.selected >= 0) await pop.tap(['badge_top', 'badge_mid', 'badge_low'][s.view.selected]);
  expect(s.run.coaters.find((c) => c.id === coat.id).flavor, 'the coater makes caramel').toBe('caramel');
  for (let i = 0; i < 8; i++) { await cook(pop); await pop.call('dev_advance', 2000); }

  // The craze starts (named for the test; the schedule's draw is tested headless).
  // (the game runs in real time: money moves by sales and costs between two reads -- the news adds none)
  const book = (st) => st.run.stats.revenue - (st.run.stats.upkeep_paid || 0) - (st.run.stats.kernels_paid || 0) - (st.run.stats.oil_paid || 0) - (st.run.stats.ingredient_coins || 0);
  const s0 = await pop.state();
  const r = await pop.call('dev_news', 'caramel_craze');
  expect(r.ok, 'the craze starts').toBe(true);
  s = await pop.state();
  expect(s.run.money - s0.run.money, 'no coin from the news: money moved only by sales and costs').toBe(book(s) - book(s0));
  expect(s.run.demand_mods.flavors.caramel, 'caramel demand x2').toBe(2);
  await expect.poll(async () => (await pop.state()).view.ticker, { message: 'the strip slides out of the icon' }).toBe(r.n);
  await pop.page.waitForTimeout(450);
  const still = decodePng(await pop.page.screenshot());
  s = await pop.state();
  const k = still.width / s.window[0];
  const n = s.rects.news.map((v) => v * k);
  const badge = countNear(still, [n[0] + n[2] * 0.5, n[1] - n[3] * 0.2, n[2] * 0.75, n[3] * 0.6], [219, 64, 56], 30);
  const strip = countNear(still, [n[0] - n[2] * 3.6, n[1], n[2] * 3.4, n[3]], [219, 64, 56], 30);
  testInfo.annotations.push({ type: 'still', description: JSON.stringify({ badge, strip, unread: card(s).unread, marks: s.view.news_marks }) });
  expect(card(s).unread, 'one unread').toBe(1);
  expect(badge, 'a red count on the icon in a still').toBeGreaterThan(20);
  expect(strip, "the strip's red edge in a still beside the icon").toBeGreaterThan(40);
  expect(s.view.news_marks, 'the caramel coater carries a paper mark').toBeGreaterThanOrEqual(1);
  await pop.shot('news37_ticker');
  // B works with the strip out.
  for (let i = 0; i < 20 && !(await cook(pop)); i++) await pop.call('dev_advance', 500);

  // The paper: the craze's row, its focus button; reading clears the count.
  await pop.tap('news');
  await expect.poll(async () => (await pop.state()).view.news_open).toBe(true);
  s = await pop.state();
  expect(card(s).unread, 'read').toBe(0);
  expect(s.rects.news_focus_caramel, 'the focus button for caramel').toBeTruthy();
  expect(overlap(s.rects.detail, s.rects.ring), 'the paper never covers the ring').toBe(false);
  await pop.tap('news_focus_caramel');
  await expect.poll(async () => card(await pop.state()).focus).toBe('caramel');
  await pop.page.waitForTimeout(300);
  await pop.shot('news37_paper');
  // B works with the paper open (and the paper stays open).
  for (let i = 0; i < 20 && !(await cook(pop)); i++) await pop.call('dev_advance', 500);
  expect((await pop.state()).view.news_open, 'cooking does not fold the paper').toBe(true);

  // A hidden tab: the news's clock waits.
  const left0 = card(await pop.state()).active[0].left_ms;
  await pop.tab(true);
  await pop.page.waitForTimeout(2500);
  const leftHidden = card(await pop.state()).active[0].left_ms;
  await pop.tab(false);
  testInfo.annotations.push({ type: 'hidden', description: JSON.stringify({ left0, leftHidden }) });
  expect(left0 - leftHidden, 'no news time passes in a hidden tab').toBeLessThan(400);
  await pop.tap('detail');
  await expect.poll(async () => (await pop.state()).view.news_open).toBe(false);

  // The craze runs out with the hand popping: real customers ask for caramel.
  for (let i = 0; i < 80; i++) {
    if (i % 2 === 0) await cook(pop);
    const st = await pop.call('dev_advance', 2000);
    if (card(st.state).active.length === 0) break;
  }
  s = await pop.state();
  const row = card(s).log.find((x) => x.n === r.n);
  expect(row, 'the craze is over and in the paper').toBeTruthy();
  expect(s.run.demand_mods.flavors?.caramel, 'its modifier is gone').toBeUndefined();
  expect(card(s).unread, 'no stale badge').toBe(0);
  expect(card(s).focus, 'the focus went home with the crowd').toBe('');
  // The same length after it, for the record (the x2 itself is measured headless on 6,000 draws:
  // fifty-odd customers here are too few to compare without luck).
  const askedAt = (st) => (st.run.stats.asked_recipe || {}).caramel || 0;
  const a0 = askedAt(s);
  const t0 = s.run.flow_ms;
  let afterAsked = 0;
  for (let i = 0; i < 60; i++) {
    if (i % 2 === 0) await cook(pop);
    const st = await pop.call('dev_advance', 2000);
    afterAsked = askedAt(st.state) - a0;
    if (card(st.state).active.length > 0 || st.state.run.flow_ms - t0 >= 120000) break;   // (stop at a scheduled event)
  }
  testInfo.annotations.push({ type: 'craze', description: JSON.stringify({ row, afterAsked, flavor_sold: s.run.stats.flavor_sold }) });
  expect(row.asked, 'caramel customers came during the craze').toBeGreaterThan(0);
  expect(row.ms, 'it ran its length').toBe(120000);
  for (const e of s.run.ledger) expect(e.recipe, 'every sale is what was ordered').toBe(e.ordered_recipe);
  expect(s.run.portions_everywhere, 'every portion made is somewhere').toBe(s.run.stats.made_portions);
  await pop.tap('news');
  await pop.page.waitForTimeout(300);
  await pop.shot('news37_past');
  await pop.tap('detail');

  // A festival survives a reload with its time.
  const fest = await pop.call('dev_news', 'film_festival');
  expect(fest.ok, 'a festival').toBe(true);
  await pop.call('dev_advance', 10000);
  const beforeReload = card(await pop.state()).active.find((x) => x.id === 'film_festival');
  const wall0 = Date.now();
  await pop.call('dev_save');
  await pop.page.reload();
  await pop.ready();
  await expect.poll(async () => (await pop.state()).exp).toBe('factory');
  s = await pop.state();
  const again = card(s).active.find((x) => x.id === 'film_festival');
  expect(again, 'the festival after a reload').toBeTruthy();
  // (the shop runs between the read, the save and the page's return: never more than that wall time)
  const wall = Date.now() - wall0;
  testInfo.annotations.push({ type: 'reload', description: JSON.stringify({ before: beforeReload.left_ms, after: again.left_ms, wall }) });
  expect(again.left_ms, 'its time never grows back').toBeLessThanOrEqual(beforeReload.left_ms);
  expect(beforeReload.left_ms - again.left_ms, 'and runs no faster than the wall clock').toBeLessThanOrEqual(wall + 200);
  expect(s.run.demand_mods.arrivals, 'and its effect, once').toBe(1.5);
  expect(s.run.portions_everywhere).toBe(s.run.stats.made_portions);
});
