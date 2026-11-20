// Step 46: one novice journey in one session, every action a real tap or hold on the canvas
// (pointer on desktop, CDP touch on phones). The first sale is pure play: no hook at all, the
// real clock. After it the journey uses exactly three hooks, each to skip waiting, never to
// act -- dev_money (the coins an hour of play would have made), dev_news and dev_contest (post
// an event/contest now instead of minutes later). They are listed in the 'hooks' annotation.
// What it walks: first click -> kettle -> packing -> pickup -> sale; the three stations
// upgraded (kitchen, packing, shop); a machine built in every category (kitchen, packing, shop,
// support) through the picker; one paused and resumed, one upgraded, from its card; the paper
// read and a contest entered by taps; a reload resumes the factory and two taps restart it.
import { test, expect } from '../lib/pop.mjs';

const hooks = [];
async function hook(pop, name, arg) {
  hooks.push(name);
  return pop.call(name, arg);
}

async function cook(pop) {
  const s = await pop.state();
  if (s.run.heating || Object.keys(s.run.glass).length > 0 || s.run.cooldown_left > 0) return false;
  await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  return true;
}

const overlap = (a, b) => a && b && a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];
async function closeCardOver(pop, r) {
  const s = await pop.state();
  if (s.rects.detail && s.view.selected >= 0 && overlap(r, s.rects.detail)) {
    await pop.tap(['badge_top', 'badge_mid', 'badge_low'][s.view.selected]);
    await expect.poll(async () => !!(await pop.state()).rects.detail).toBe(false);
  }
}

function freeSlot(run, floor) {
  const taken = new Set(run.machines.filter((m) => m.floor === floor).map((m) => m.slot));
  for (let k = 0; k < run.slots[floor]; k++) if (!taken.has(k)) return k;
  return -1;
}

async function build(pop, floor, type) {
  let s = await pop.state();
  const k = freeSlot(s.run, floor);
  expect(k, `a free place on ${floor}`).toBeGreaterThanOrEqual(0);
  await closeCardOver(pop, s.rects[`slot_${floor}_${k}`]);
  const n = s.run.machines.length;
  await pop.tap(`slot_${floor}_${k}`);
  await expect.poll(async () => !!(await pop.state()).rects[`pick_${type}`], { message: `${type} in the ${floor} picker` }).toBe(true);
  await pop.tap(`pick_${type}`);
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.machines.length, { message: `${type} built` }).toBe(n + 1);
  s = await pop.state();
  return s.run.machines.find((m) => m.floor === floor && m.slot === k);
}

test('a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart', async ({ pop }, testInfo) => {
  test.setTimeout(600_000);
  hooks.length = 0;
  await pop.open('./#factory');
  let s = await pop.state();
  expect(s.run.money).toBe(0);
  expect(s.run.machines.length).toBe(0);

  // 1. Pure play to the first sale: the hand's hold makes a lot, packing makes a pack, the
  // waiting customer picks it up and pays -- the real clock, no hook.
  const t0 = Date.now();
  await cook(pop);
  await expect.poll(async () => (await pop.state()).run.stats.sold, { message: 'the first sale', timeout: 30_000 }).toBeGreaterThanOrEqual(1);
  s = await pop.state();
  const firstSaleMs = Date.now() - t0;
  expect(s.run.money, 'paid by the customer').toBeGreaterThan(0);
  expect(s.run.money).toBe(s.run.stats.revenue);
  // A minute more of pure play: pops and sales by hand only.
  const play0 = Date.now();
  while (Date.now() - play0 < 60_000) { await cook(pop); await pop.page.waitForTimeout(400); }
  s = await pop.state();
  const earnedByHand = s.run.stats.revenue;
  testInfo.annotations.push({ type: 'by_hand', description: JSON.stringify({ first_sale_ms: firstSaleMs, minute_sales: s.run.stats.sold, revenue: earnedByHand, sign_open: s.run.open.sign }) });
  expect(s.run.stats.sold, 'more sales by hand').toBeGreaterThan(3);
  await pop.shot('journey46_by_hand');

  // 2. The three stations, by their floors' cards (coins: an hour of play skipped).
  await hook(pop, 'dev_money', 60000);
  await expect.poll(async () => (await pop.state()).run.open.sign, { timeout: 25_000 }).toBe(true);
  const st0 = await pop.state();
  await pop.tap('floor_top');
  for (let i = 0; i < 5; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.sign_tier, { message: 'the shop: the sign up' }).toBeGreaterThan(st0.run.sign_tier);
  await pop.tap('floor_mid');
  for (let i = 0; i < 2; i++) await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.packer_tier, { message: 'packing: the station up' }).toBeGreaterThan(st0.run.packer_tier);
  // The kitchen's station is the hand's kettle: with no floor card open, the button sells its
  // next level (tapping the kitchen floor would pick one of its machine places instead).
  s = await pop.state();
  if (s.view.selected >= 0) {
    await pop.tap(['badge_top', 'badge_mid', 'badge_low'][s.view.selected]);
    await expect.poll(async () => (await pop.state()).view.selected, { message: 'no card open' }).toBeLessThan(0);
  }
  const lv = (await pop.state()).run.level;
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.level, { message: 'the kitchen: the kettle up' }).toBeGreaterThan(lv);
  s = await pop.state();
  testInfo.annotations.push({ type: 'stations', description: JSON.stringify({ sign: [st0.run.sign_tier, s.run.sign_tier], packer: [st0.run.packer_tier, s.run.packer_tier], kettle: [st0.run.level, s.run.level] }) });

  // 3. A machine of every category through the picker: kitchen, packing, shop, support.
  const cooker = await build(pop, 'kitchen', 'cooker');
  const bagger = await build(pop, 'packing', 'bagger');
  const kiosk = await build(pop, 'shop', 'kiosk');
  const saver = await build(pop, 'kitchen', 'U03');
  expect([cooker.type, bagger.type, kiosk.type, saver.type]).toEqual(['cooker', 'bagger', 'kiosk', 'U03']);
  await pop.shot('journey46_four_categories');

  // 4. The card: pause and resume the cooker, upgrade the bagger.
  await closeCardOver(pop, (await pop.state()).rects[`slot_kitchen_${cooker.slot}`]);
  await pop.tap(`slot_kitchen_${cooker.slot}`);
  await expect.poll(async () => !!(await pop.state()).rects.m_pause, { message: "the cooker's card" }).toBe(true);
  await pop.tap('m_pause');
  await expect.poll(async () => (await pop.state()).run.machines.find((m) => m.id === cooker.id).state, { message: 'paused' }).toBe('paused');
  await pop.tap('m_pause');
  await expect.poll(async () => (await pop.state()).run.machines.find((m) => m.id === cooker.id).state, { message: 'resumed' }).not.toBe('paused');
  await closeCardOver(pop, (await pop.state()).rects[`slot_packing_${bagger.slot}`]);
  await pop.tap(`slot_packing_${bagger.slot}`);
  await expect.poll(async () => !!(await pop.state()).rects.m_pause, { message: "the bagger's card" }).toBe(true);
  const m0 = (await pop.state()).run.money;
  await pop.tap('upgrade');
  await expect.poll(async () => (await pop.state()).run.machines.find((m) => m.id === bagger.id).tier, { message: "the bagger's tier from its card" }).toBe(1);
  expect((await pop.state()).run.money, 'the upgrade cost coins').toBeLessThan(m0);

  // 5. The paper and a contest, by taps (posted now instead of minutes later).
  const nr = await hook(pop, 'dev_news', 'film_festival');
  expect(nr.ok, `the news event starts (${nr.reason || ''})`).toBe(true);
  await closeCardOver(pop, (await pop.state()).rects.news);   // (on a phone the bagger's card covers the paper)
  await pop.tap('news');
  await expect.poll(async () => (await pop.state()).view.news_open, { message: 'the paper open' }).toBe(true);
  await pop.shot('journey46_paper');
  await pop.call('dev_advance', 1000);
  const cr = await hook(pop, 'dev_contest', 'perfect_streak');
  expect(cr.ok, `the contest posted (${cr.reason || ''})`).toBe(true);
  s = await pop.state();
  if (s.view.news_tab !== 'contests') await pop.tap('news_tab_contests');
  await expect.poll(async () => !!(await pop.state()).rects.contest_enter_perfect_streak, { message: 'its Enter button' }).toBe(true);
  const fees0 = (await pop.state()).run.stats.contest_fees || 0;
  await pop.tap('contest_enter_perfect_streak');
  await expect.poll(async () => (await pop.state()).run.contests.entry?.id ?? '', { message: 'entered by a tap' }).toBe('perfect_streak');
  // The fee, from the fee counter: the factory keeps selling while the paper is open, so the
  // wallet alone can be higher after the tap (Step 46 full run, desktop: 54962 -> 54975).
  const entry = (await pop.state()).run.contests.entry;
  expect((await pop.state()).run.stats.contest_fees || 0, 'the fee paid').toBe(fees0 + (entry.fee ?? 0));
  expect(entry.fee ?? 0, 'a fee to pay').toBeGreaterThan(0);
  if ((await pop.state()).view.news_open) await pop.tap('detail');

  // 6. Resume after a reload, then two taps restart.
  await pop.page.waitForTimeout(6000);   // the game's own save, every 5 s of play
  const before = await pop.state();
  await pop.page.reload();
  await pop.ready();
  s = await pop.state();
  expect(s.save.from, 'resumed from the save').toBe('main');
  expect(s.run.machines.map((m) => `${m.type}@${m.floor}/${m.slot}#${m.tier}`).sort()).toEqual(before.run.machines.map((m) => `${m.type}@${m.floor}/${m.slot}#${m.tier}`).sort());
  expect(s.run.contests.entry?.id, 'the contest still running').toBe('perfect_streak');
  await pop.tap('restart');
  await pop.page.waitForTimeout(300);
  expect((await pop.state()).run.machines.length, 'one tap keeps the factory').toBe(before.run.machines.length);
  await pop.tap('restart');
  await expect.poll(async () => (await pop.state()).run.machines.length, { message: 'two taps: a new factory' }).toBe(0);
  testInfo.annotations.push({ type: 'hooks', description: JSON.stringify(hooks) });
  expect(hooks.every((h) => ['dev_money', 'dev_news', 'dev_contest'].includes(h)), 'only the waiting-skipping hooks').toBe(true);
  expect(pop.errors).toEqual([]);
});
