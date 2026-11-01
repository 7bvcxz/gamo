// Step 79: nothing happens while Momonium is in the background or closed.
// In the real web build, with the island's clock running in real time:
//
//  - the tab goes to the background for a real minute: saved once on the way
//    out, the island stands still (a ripening crop, a Momo 40% through a
//    dig, the money, EXP, store, letters, the day), and on return it goes on
//    from there -- the first frame back hands the whole minute over and none
//    of it counts; then play completes the work as usual;
//  - closed and opened again hours later (the page's clock moved on 5 and 10
//    hours), refreshed, and opened from the localStorage mirror with the
//    IndexedDB save gone: the island as it was saved, no welcome-back card,
//    nothing paid twice, no letter written again.
//
// The background tab: this machine's headless Chromium never reports a page
// hidden -- not with another tab in front, a window minimised, nor a CDP
// freeze (they were tried; the page kept drawing 60 frames a second). So the
// page does what a browser does to a background tab: document.visibilityState
// says "hidden" with a visibilitychange event, and no animation frame runs
// until it is visible again, when the waiting frame comes with the whole
// gap. Real time passes meanwhile. On 0.78.0 (offline catch-up) the minute
// is caught up and this spec fails.
import { test, expect } from '@playwright/test';

test.describe.configure({ timeout: 240_000 });

async function open(context, { shiftHours = 0, dropFileSave = false } = {}) {
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript(([shift, drop]) => {
    window.MOMONIUM_E2E = true;
    if (shift) {
      const now = Date.now.bind(Date);
      Date.now = () => now() + shift * 3600000;
    }
    if (drop) indexedDB.deleteDatabase('/userfs');
    // A background tab, as a browser makes one (see the header).
    let hidden = false;
    const waiting = [];
    const raf = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = (cb) => {
      if (hidden) {
        waiting.push(cb);
        return 0;
      }
      return raf(cb);
    };
    Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => (hidden ? 'hidden' : 'visible') });
    Object.defineProperty(document, 'hidden', { configurable: true, get: () => hidden });
    window.__tab = (h) => {
      hidden = h;
      document.dispatchEvent(new Event('visibilitychange'));
      if (!h) for (const cb of waiting.splice(0)) raf(cb);
    };
  }, [shiftHours, dropFileSave]);
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.state === 'function', null, { timeout: 90_000 });
  await page.waitForTimeout(500);
  const call = (name, arg) => page.evaluate(([n, a]) => window.momonium.call(n, a), [name, arg]);
  return {
    page, errors, call,
    state: () => page.evaluate(() => window.momonium.state()),
    command: (c) => page.evaluate((cmd) => window.momonium.command(cmd), c),
    scale: (x) => page.evaluate((v) => window.momonium.setTimeScale(v), x),
    tab: (h) => page.evaluate((v) => window.__tab(v), h),
  };
}

// What is left of building `id`'s work or wait on page `g`, in ms.
async function leftOf(g, id) {
  const s = await g.state();
  const x = s.buildings.buildings.find((y) => y.id === id);
  return Math.max((x.state === 'working' ? x.task_end : x.state === 'cooldown' ? x.ready_at : s.now_ms) - s.now_ms, 0);
}

// A crop ripening after its watering and a Momo 40% through a dig.
async function busyIsland(g) {
  await g.scale(0);
  await g.call('set_language', 'en');
  await g.call('dev_grow_island', 3);
  const momo = (await g.call('dev_add_momo', [0.55, 1.35])).id;
  const farm = (await g.call('dev_place_building', ['farm', 1, 0])).id;
  const mine = (await g.call('dev_place_building', ['mine', 2, 2])).id;
  const b = async (id) => (await g.state()).buildings.buildings.find((x) => x.id === id);
  const left = (id) => leftOf(g, id);
  expect((await g.command({ type: 'building.tap', id: farm })).ok, 'sowing').toBe(true);
  await g.call('dev_advance_ms', 14000);
  expect((await g.command({ type: 'momo.assign', momo, building: mine })).ok).toBe(true);
  await g.call('dev_advance_ms', await left(farm));
  expect((await g.command({ type: 'building.tap', id: farm })).ok, 'watering').toBe(true);
  for (let i = 0; i < 400; i++) {
    const m = await b(mine);
    const s = await g.state();
    if (m.state === 'working' && (s.now_ms - m.task_start) / (m.task_end - m.task_start) >= 0.4) break;
    await g.call('dev_advance_ms', 250);
  }
  expect((await b(farm)).state, 'the crop is ripening').toBe('cooldown');
  expect((await b(mine)).state, 'the Momo is digging').toBe('working');
  return { farm, mine, left };
}

// What must not change while away.
async function ledger(g) {
  const s = await g.state();
  return {
    money: s.economy.money, exp: s.progression.exp, level: s.progression.level,
    items: JSON.stringify(s.inventory.items), letters: s.mail.letters.length, day: s.day,
    completed: s.buildings.buildings.map((b) => b.completed),
  };
}

test('a real minute in the background: saved once, the island stands still, then goes on', async ({ context }) => {
  const g = await open(context);
  const { farm, mine, left } = await busyIsland(g);
  // The island's clock in real time from here on, as in play.
  await g.scale(1);
  await g.page.waitForTimeout(1000);
  const s0 = await g.call('session');
  expect(s0.foreground).toBe(true);
  const before = await ledger(g);
  const t0 = (await g.call('session')).now_ms;
  await g.tab(true);
  const hiddenAt = await g.call('session');
  expect(hiddenAt.foreground, 'hidden: the island stops').toBe(false);
  expect(hiddenAt.hidden).toBe(true);
  expect(hiddenAt.saves, 'saved once on the way out').toBe(s0.saves + 1);
  const farmLeft = await left(farm);
  const digLeft = await left(mine);
  const stopped = hiddenAt.now_ms;
  expect(stopped - t0, 'only the frames before hiding').toBeLessThan(1000);
  await g.page.waitForTimeout(60_000);
  const still = await g.call('session');
  expect(still.now_ms, 'a minute hidden: not a millisecond more').toBe(stopped);
  await g.tab(false);
  await g.page.waitForTimeout(1500);
  const back = await g.call('session');
  expect(back.foreground).toBe(true);
  expect(back.resumes).toBe(1);
  expect(back.away_seconds, 'the minute away is noted').toBeGreaterThan(59);
  const ran = back.now_ms - stopped;
  console.log(`offline79 ${test.info().project.name}: hidden 60 s, the island ran ${ran} ms since (the 1.5 s on screen after)`);
  expect(ran, 'back: only the frames seen since (not the minute)').toBeLessThan(3000);
  expect(await left(farm), 'the crop: the same ripening left, less the frames since').toBeGreaterThan(farmLeft - 3000);
  expect(await left(mine), 'the dig: the same 60% left').toBeGreaterThan(digLeft - 3000);
  expect(await ledger(g), 'money, EXP, store, letters, day, jobs: as they were').toEqual(before);
  expect((await g.call('persistence')).away_open, 'no welcome-back card').toBe(false);
  // Then play completes it as usual.
  await g.scale(0);
  await g.call('dev_advance_ms', (await left(farm)) + 10);
  expect((await g.state()).buildings.buildings.find((b) => b.id === farm).state, 'the crop ripens').toBe('idle');
  await g.call('dev_advance_ms', (await left(mine)) + 10);
  expect((await ledger(g)).completed[1], 'the dig is done, once').toBe(before.completed[1] + 1);
  expect(g.errors).toEqual([]);
});

test('closed for hours, refreshed, opened from the mirror: the island as it was saved', async ({ context }) => {
  const g = await open(context);
  const { farm, left } = await busyIsland(g);
  const saved = await g.call('save_now');
  expect(saved.err).toBe(0);
  const before = await ledger(g);
  // Each page saves as it is closed (pagehide), after the frames it showed:
  // the next one starts from there.
  let savedMs = (await g.state()).now_ms;
  let farmLeft = await left(farm);
  await g.page.close();
  for (const [label, opts] of [['5 h later', { shiftHours: 5 }], ['refreshed 10 h later', { shiftHours: 10 }], ['the file save gone: the mirror', { shiftHours: 10, dropFileSave: true }]]) {
    const h = await open(context, opts);
    await h.scale(0);
    const p = await h.call('persistence');
    expect(p.status, `${label}: opened`).toBe('ok');
    const s = await h.state();
    const ran = s.now_ms - savedMs;
    savedMs = s.now_ms;
    console.log(`offline79 ${test.info().project.name}: ${label}: the island ran ${ran} ms`);
    expect(ran, `${label}: the clock where it was saved (only the frames on screen)`).toBeLessThan(2000);
    expect(ran).toBeGreaterThanOrEqual(0);
    expect(await ledger(h), `${label}: nothing earned, made, written or paid again`).toEqual(before);
    expect(p.report, `${label}: no catch-up`).toEqual({});
    expect(p.away_open, `${label}: no welcome-back card`).toBe(false);
    const nowLeft = await leftOf(h, farm);
    expect(nowLeft, `${label}: the crop has its ripening left, less the frames on screen`).toBe(Math.max(farmLeft - ran, 0));
    farmLeft = nowLeft;
    expect(h.errors).toEqual([]);
    await h.page.close();
  }
});

test('losing focus while still on screen saves and keeps playing', async ({ context }) => {
  const g = await open(context);
  await g.scale(1);
  const s0 = await g.call('session');
  await g.page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await g.page.waitForTimeout(1000);
  const s1 = await g.call('session');
  expect(s1.foreground, 'unfocused but visible: still the game on screen').toBe(true);
  expect(s1.now_ms - s0.now_ms, 'its clock runs').toBeGreaterThan(500);
  expect(g.errors).toEqual([]);
});
