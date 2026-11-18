// Step 38: contests in a real browser -- two playthroughs with real taps and holds.
// A plain stand: no contests until it has sold fifteen bags; then a gold trophy dot on the paper,
// and the paper opens on its trophy page. The "?" shows the one-line description and hides it again.
// Enter (the fee once) the Perfect Pop streak; real holds on B's ring count the perfect pops in a
// row (the paper never covers the ring); folded, a chip beside the paper shows the time and the
// score; a hidden tab stops its clock; it runs out in active time, the tier reached pays its
// prize once, the end slides out of the chip and the page shows the result. It rests, comes back,
// is entered again and cancelled with two taps (no prize, no refund). Rush hour cannot be
// entered during a film festival (its card shows the paper), keeps the festival away while it
// runs, and survives a reload with its deadline. A factory built by taps enters Lean packing, an
// advanced contest, and its score is the portions given away per 100 packed, from the counters.
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

const GOLD = [255, 199, 46];

async function goldIn(pop, rect) {
  const png = decodePng(await pop.page.screenshot());
  const s = await pop.state();
  const k = png.width / s.window[0];
  return countNear(png, rect.map((v) => v * k), GOLD, 34);
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

// One real hold on the ring when the kettle is free (a quarter into the gold); true when it pressed.
async function cook(pop) {
  const s = await pop.state();
  if (s.run.heating || Object.keys(s.run.glass).length > 0 || s.run.cooldown_left > 0) return false;
  const before = s.run.presses;
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.presses, { message: 'the ring took the press' }).toBe(before + 1);
  return true;
}

const C = (s) => s.run.contests;
const book = (st) => st.run.stats.revenue - (st.run.stats.upkeep_paid || 0) - (st.run.stats.kernels_paid || 0) - (st.run.stats.oil_paid || 0) - (st.run.stats.ingredient_coins || 0);

async function fold(pop) {
  if ((await pop.state()).view.news_open) {
    await pop.tap('detail');
    await expect.poll(async () => (await pop.state()).view.news_open).toBe(false);
  }
}

async function openContests(pop) {
  let s = await pop.state();
  if (!s.view.news_open) {
    await pop.tap('news');
    await expect.poll(async () => (await pop.state()).view.news_open).toBe(true);
  }
  s = await pop.state();
  if (s.view.news_tab !== 'contests') {
    await pop.tap('news_tab_contests');
    await expect.poll(async () => (await pop.state()).view.news_tab).toBe('contests');
  }
}

test('contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes', async ({ pop }, testInfo) => {
  test.setTimeout(720_000);
  await pop.open('./#factory');
  let s = await pop.state();
  expect(C(s).open, 'no contests at opening').toBe(false);
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  // A working stand: the hand pops, the stand sells (game time moved on by the test hook).
  for (let i = 0; i < 400; i++) {
    if (i % 4 === 0) await cook(pop);   // (a pop the stand can sell: about two a minute at sign 0)
    const st = await pop.call('dev_advance', 2000);
    if (C(st.state).open) break;
    expect(C(st.state).posted.length, 'nothing posted before').toBe(0);
  }
  s = await pop.state();
  expect(C(s).open, 'they open once the stand has sold its first bags').toBe(true);
  expect(s.run.stats.sold, 'after fifteen sales').toBeGreaterThanOrEqual(15);
  expect(C(s).fresh, 'news of them: the gold dot').toBe(true);
  expect(C(s).posted.map((p) => p.id), 'the approachable one is posted').toContain('perfect_streak');
  await pop.page.waitForTimeout(450);
  const n = s.rects.news;
  const dot = await goldIn(pop, [n[0] - n[2] * 0.1, n[1] - n[3] * 0.1, n[2] * 0.5, n[3] * 0.5]);
  testInfo.annotations.push({ type: 'dot', description: JSON.stringify({ dot, posted: C(s).posted.map((p) => p.id) }) });
  expect(dot, 'a gold dot on the paper in a still').toBeGreaterThan(20);

  // The stand's own coins buy the sign twice (more customers: the kettle is free more often).
  await pop.tap('floor_top');
  for (let i = 0; i < 2; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(2);
  await pop.tap('floor_top');
  for (let i = 0; i < 30 && Object.keys((await pop.state()).run.glass).length > 0; i++) await pop.call('dev_advance', 2000);
  // The paper opens on its trophy page; the dot goes.
  await pop.tap('news');
  await expect.poll(async () => (await pop.state()).view.news_tab).toBe('contests');
  await expect.poll(async () => C(await pop.state()).fresh).toBe(false);
  s = await pop.state();
  expect(s.rects.contest_enter_perfect_streak, 'its Enter button').toBeTruthy();
  expect(overlap(s.rects.detail, s.rects.ring), 'the paper never covers the ring').toBe(false);
  await pop.page.waitForTimeout(300);
  await pop.shot('contests38_board');
  await pop.tap('contest_info_perfect_streak');
  await expect.poll(async () => (await pop.state()).view.contest_info).toBe('perfect_streak');
  await pop.page.waitForTimeout(300);
  await pop.shot('contests38_info');
  await pop.tap('contest_info_perfect_streak');
  await expect.poll(async () => (await pop.state()).view.contest_info).toBe('');

  // Enter: the fee, once (money moves by sales and costs too: the book says by how much).
  const fee = C(s).posted.find((p) => p.id === 'perfect_streak').fee;
  const s0 = await pop.state();
  await pop.tap('contest_enter_perfect_streak');
  await expect.poll(async () => C(await pop.state()).entry.id).toBe('perfect_streak');
  s = await pop.state();
  expect(s.run.money - s0.run.money, 'the fee, once').toBe(book(s) - book(s0) - fee);
  expect(s.run.stats.contest_fees).toBe(fee);
  const tiers = C(s).entry.tiers;
  // Real holds on the ring, the paper open (cooking never folds it).
  for (let i = 0; i < 150 && C(await pop.state()).entry.pops < 4 && C(await pop.state()).entry.id; i++) {
    if (!(await cook(pop))) await pop.call('dev_advance', 1000);
  }
  s = await pop.state();
  expect(s.view.news_open, 'cooking does not fold the paper').toBe(true);
  const live = C(s).entry;
  testInfo.annotations.push({ type: 'live', description: JSON.stringify({ pops: live.pops, score: live.score, cur: live.cur, tiers, outcomes: s.run.outcomes }) });
  expect(live.pops, 'the hand popped during the contest').toBeGreaterThanOrEqual(3);
  expect(live.score, 'the best run of perfect pops so far').toBeLessThanOrEqual(live.pops);
  await pop.shot('contests38_live');
  // Folded: the chip beside the paper.
  await fold(pop);
  s = await pop.state();
  expect(s.rects.contest_chip, 'a chip beside the paper while it runs').toBeTruthy();
  await pop.page.waitForTimeout(300);
  const chipGold = await goldIn(pop, s.rects.contest_chip);
  expect(chipGold, 'the chip: a gold trophy and ring in a still').toBeGreaterThan(60);
  await pop.shot('contests38_chip');
  // A hidden tab: its clock waits.
  const left0 = C(await pop.state()).entry.left_ms;
  await pop.tab(true);
  await pop.page.waitForTimeout(2500);
  const leftHidden = C(await pop.state()).entry.left_ms;
  await pop.tab(false);
  testInfo.annotations.push({ type: 'hidden', description: JSON.stringify({ left0, leftHidden }) });
  expect(left0 - leftHidden, 'no contest time passes in a hidden tab').toBeLessThan(400);
  // It runs out in active time; the tier reached pays once.
  const seq = C(await pop.state()).entry.seq;
  for (let i = 0; i < 200; i++) {
    const st = await pop.call('dev_advance', 2000);
    if (!C(st.state).entry.id) break;
  }
  s = await pop.state();
  const res = C(s).results[C(s).results.length - 1];
  expect(res.seq, 'its result').toBe(seq);
  expect(res.how).not.toBe('cancel');
  const tierWanted = res.score >= tiers[2] ? 3 : res.score >= tiers[1] ? 2 : res.score >= tiers[0] ? 1 : 0;
  expect(res.tier, 'the tier its score reached').toBe(tierWanted);
  expect(s.run.stats.contest_prizes || 0, 'its prize, once').toBe(res.prize);
  expect(s.view.cticker, 'the end slides out of the chip').toBe(seq);
  await pop.page.waitForTimeout(500);
  await pop.shot('contests38_end');
  await openContests(pop);
  s = await pop.state();
  expect(s.rects.contest_top, 'the result at the top of the page').toBeTruthy();
  await pop.page.waitForTimeout(300);
  await pop.shot('contests38_result');
  testInfo.annotations.push({ type: 'result', description: JSON.stringify(res) });

  // It rests, comes back, is entered again -- and cancelled with two taps: no prize, no refund.
  for (let i = 0; i < 400; i++) {
    const st = await pop.call('dev_advance', 2000);
    if (C(st.state).posted.some((p) => p.id === 'perfect_streak')) break;
  }
  s = await pop.state();
  expect(C(s).posted.map((p) => p.id), 'posted again after its rest').toContain('perfect_streak');
  const fees0 = s.run.stats.contest_fees;
  const prizes0 = s.run.stats.contest_prizes || 0;
  await pop.tap('contest_enter_perfect_streak');
  await expect.poll(async () => C(await pop.state()).entry.id).toBe('perfect_streak');
  await pop.tap('contest_cancel');
  await expect.poll(async () => (await pop.state()).view.cancel_armed).toBe(true);
  expect(C(await pop.state()).entry.id, 'one tap only arms it').toBe('perfect_streak');
  await pop.page.waitForTimeout(250);
  await pop.shot('contests38_cancel_armed');
  await pop.tap('contest_cancel');
  await expect.poll(async () => C(await pop.state()).entry.id).toBeUndefined();
  s = await pop.state();
  const cres = C(s).results[C(s).results.length - 1];
  expect(cres.how, 'cancelled').toBe('cancel');
  expect(cres.prize).toBe(0);
  expect(s.run.stats.contest_fees, 'the fee is spent').toBe(fees0 + fee);
  expect(s.run.stats.contest_prizes || 0, 'no prize').toBe(prizes0);
  expect(C(s).posted.map((p) => p.id), 'it rests (no free restart)').not.toContain('perfect_streak');

  // Rush hour: refused during a festival, keeps it away while it runs, survives a reload.
  await fold(pop);
  await pop.call('dev_money', 5000);
  await pop.tap('floor_top');
  for (let i = 0; i < 6 && (await pop.state()).run.sign_tier < 3; i++) {
    const t0 = (await pop.state()).run.sign_tier;
    await pop.tap('upgrade');
    await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(t0 + 1);
  }
  expect((await pop.state()).run.sign_tier).toBe(3);
  await pop.tap('floor_top');
  expect((await pop.call('dev_contest', 'rush_hour')).ok, 'rush hour posted').toBe(true);
  expect((await pop.call('dev_news', 'film_festival')).ok, 'a festival').toBe(true);
  await openContests(pop);
  s = await pop.state();
  expect(C(s).posted.find((p) => p.id === 'rush_hour').problem, 'its card says why').toBe('err.contest_news');
  await pop.page.waitForTimeout(300);
  await pop.shot('contests38_collision');
  await pop.tap('contest_enter_rush_hour');
  await pop.page.waitForTimeout(300);
  expect(C(await pop.state()).entry.id, 'refused while the festival runs').toBeUndefined();
  for (let i = 0; i < 80; i++) {
    const st = await pop.call('dev_advance', 2000);
    if (!st.state.run.news.active.some((a) => a.id === 'film_festival')) break;
  }
  await pop.tap('contest_enter_rush_hour');
  await expect.poll(async () => C(await pop.state()).entry.id).toBe('rush_hour');
  expect((await pop.call('dev_news', 'film_festival')).ok, 'no festival during rush hour').toBe(false);
  for (let i = 0; i < 10; i++) { if (i % 2 === 0) await cook(pop); await pop.call('dev_advance', 2000); }
  const before = C(await pop.state()).entry;
  const wall0 = Date.now();
  await pop.call('dev_save');
  await pop.page.reload();
  await pop.ready();
  await expect.poll(async () => (await pop.state()).exp).toBe('factory');
  s = await pop.state();
  const again = C(s).entry;
  const wall = Date.now() - wall0;
  testInfo.annotations.push({ type: 'reload', description: JSON.stringify({ before: { seq: before.seq, left: before.left_ms, score: before.score }, after: { seq: again.seq, left: again.left_ms, score: again.score }, wall }) });
  expect(again.seq, 'the same contest after a reload').toBe(before.seq);
  expect(again.left_ms, 'its deadline never moves back').toBeLessThanOrEqual(before.left_ms);
  expect(before.left_ms - again.left_ms, 'and runs no faster than the wall clock').toBeLessThanOrEqual(wall + 200);
  expect(again.score, 'its score kept').toBeGreaterThanOrEqual(before.score);
  for (let i = 0; i < 200; i++) {
    const st = await pop.call('dev_advance', 2000);
    if (!C(st.state).entry.id) break;
  }
  s = await pop.state();
  const rres = C(s).results.filter((r) => r.seq === before.seq);
  expect(rres.length, 'one result for it').toBe(1);
  expect(rres[0].score, 'customers served').toBeGreaterThan(0);
  expect(s.run.stats.contests_entered).toBe(s.run.stats.contests_done + s.run.stats.contests_cancelled);
  for (const e of s.run.ledger) expect(e.recipe, 'every sale is what was ordered').toBe(e.ordered_recipe);
  expect(s.run.portions_everywhere, 'every portion made is somewhere').toBe(s.run.stats.made_portions);
});

test('contests: an advanced factory enters lean packing and its score comes from the counters', async ({ pop }, testInfo) => {
  test.setTimeout(600_000);
  await pop.open('./#factory');
  let s = await pop.state();
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  await pop.call('dev_money', 300000);
  await pop.tap('floor_top');
  for (let i = 0; i < 6; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier).toBe(6);
  await pop.tap('floor_mid');
  for (let i = 0; i < 3; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier).toBe(3);
  for (const t of ['cooker', 'cooker', 'M01']) await build(pop, t, 'kitchen');
  await build(pop, 'bagger', 'packing');
  s = await pop.state();
  if (s.view.selected >= 0) await pop.tap(['badge_top', 'badge_mid', 'badge_low'][s.view.selected]);
  for (let i = 0; i < 6; i++) { await cook(pop); await pop.call('dev_advance', 2000); }
  const r = await pop.call('dev_contest', 'lean_packing');
  expect(r.ok, `lean packing posted for a factory with a bagger (${r.reason || ''})`).toBe(true);
  await openContests(pop);
  await pop.page.waitForTimeout(300);
  await pop.shot('contests38_factory_board');
  const s0 = await pop.state();
  const st0 = s0.run.stats;
  await pop.tap('contest_enter_lean_packing');
  await expect.poll(async () => C(await pop.state()).entry.id).toBe('lean_packing');
  s = await pop.state();
  const base = s.run.stats;
  const w = (st) => (st.overfill_portions || 0) + (st.lost_portions || 0);
  for (let i = 0; i < 80; i++) {
    if (i % 2 === 0) await cook(pop);
    const st = await pop.call('dev_advance', 2000);
    if (i === 30) { await pop.page.waitForTimeout(200); await pop.shot('contests38_factory_live'); }
    if (!C(st.state).entry.id) break;
    const e = C(st.state).entry;
    const made = (st.state.run.stats.packed_portions || 0) - (base.packed_portions || 0);
    if (made > 0) expect(Math.abs(e.score - Math.round((w(st.state.run.stats) - w(base)) * 1000 / made) / 10), 'its score: given away per 100 packed').toBeLessThanOrEqual(0.11);
  }
  for (let i = 0; i < 100; i++) {
    const st = await pop.call('dev_advance', 3000);
    if (!C(st.state).entry.id) break;
  }
  s = await pop.state();
  const res = C(s).results[C(s).results.length - 1];
  expect(res.id).toBe('lean_packing');
  expect(res.packs, 'bags packed in it').toBeGreaterThan(0);
  const minp = res.min_packs;
  const t = res.tiers;
  const tierWanted = res.packs < minp ? 0 : res.score <= t[2] ? 3 : res.score <= t[1] ? 2 : res.score <= t[0] ? 1 : 0;
  expect(res.tier, 'the tier its score reached (fewer is better)').toBe(tierWanted);
  expect((s.run.stats.contest_prizes || 0), 'its prize, once').toBe(res.prize);
  expect(s.run.stats.contest_fees, 'its fee, once').toBe((st0.contest_fees || 0) + res.fee);
  testInfo.annotations.push({ type: 'lean', description: JSON.stringify({ score: res.score, packs: res.packs, tier: res.tier, prize: res.prize, overfill: s.run.stats.overfill_portions || 0, lost: s.run.stats.lost_portions || 0 }) });
  await openContests(pop);
  await pop.page.waitForTimeout(300);
  await pop.shot('contests38_factory_result');
  expect(s.run.portions_everywhere, 'every portion made is somewhere').toBe(s.run.stats.made_portions);
});
