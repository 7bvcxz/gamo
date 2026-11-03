// Step 96: C+'s thirty minutes in the real web build, time-stepped (a
// person's thirty minutes are the owner's to play; this checks the build
// keeps going): 2.5 hits a second for 1,800 s of play time in ten-second
// steps, buying the pickaxe whenever it can pay. No stall, no negative
// coins, kinds and great rocks keep coming, the 3/15/30-minute snapshots
// and the actions a minute are recorded. The light and hold alternatives
// open as dev links and say so; the kinds look different (FUNLAB_SHOTS); the
// tracks page shows the thirty-minute table and the alternatives.
import { test, expect } from '../lib/lab.mjs';

test('thirty minutes of C+ in the web build, time-stepped: it keeps going', async ({ lab }, info) => {
  test.skip(info.project.name === 'phone', 'p720 and desktop');
  test.setTimeout(900_000);
  await lab.open('./#rock-plus');
  await lab.call('dev_time_scale', 0);
  let s = await lab.state();
  let lastRock = 0;
  const kinds = new Set();
  const upgradesAt = [];
  for (let t = 0; t < 1800; t += 10) {
    await lab.call('dev_hits', 25);
    s = (await lab.call('dev_advance', 10)).state;
    for (let i = 0; i < 4 && s.host.action.affordable; i++) {
      await lab.call('dev_action');
      s = await lab.state();
      upgradesAt.push(s.host.session.active_seconds);
    }
    const e = s.host.experiment;
    expect(e.coins, `coins never negative (t ${t})`).toBeGreaterThanOrEqual(0);
    expect(e.rock, `the rocks only go forward (t ${t})`).toBeGreaterThanOrEqual(lastRock);
    lastRock = e.rock;
    kinds.add(e.kind);
    if (t === 600 || t === 1200) await lab.shot(`cplus96_${t / 60}min`);
  }
  const sum = s.host.session;
  const e = s.host.experiment;
  console.log(`cplus96 ${info.project.name}: 30 min time-stepped: ${e.rock} rocks (${e.big_breaks} great), pickaxe ${e.pick} (${e.tier}), ${kinds.size} kinds, now ${e.rock_name}, earned ${e.earned}`);
  expect(sum.active_seconds).toBeGreaterThanOrEqual(1800);
  for (const k of ['at_3min', 'at_15min', 'at_30min']) expect(sum[k], `${k} recorded`).not.toBeNull();
  expect(sum.actions_per_minute.length, 'actions in each minute').toBeGreaterThanOrEqual(30);
  expect(e.rock, 'past a hundred rocks').toBeGreaterThan(100);
  expect(e.big_breaks, 'a great rock every six').toBeGreaterThanOrEqual(16);
  expect(kinds.size, 'many kinds seen').toBeGreaterThanOrEqual(17);
  expect(e.pick, 'the pickaxe kept rising').toBeGreaterThanOrEqual(30);
  // No five minutes without an upgrade, start to end.
  const ups = sum.upgrades.map((u) => u.t_s);
  for (let w = 0; w < 1800; w += 300) expect(ups.some((x) => x > w && x <= w + 300), `an upgrade between ${w} and ${w + 300} s`).toBe(true);
  await lab.shot('cplus96_30min');
});

test('the light and hold alternatives open as dev links and say so', async ({ lab }, info) => {
  test.skip(info.project.name === 'p720', 'phone and desktop');
  await lab.open('./?dev=1&alt=light#rock-plus');
  let s = await lab.state();
  expect(s.host.alt).toBe('light');
  expect(s.host.experiment.max_hp, 'light: 60% of the first boulder').toBe(65);
  await lab.call('dev_hits', 21);
  expect((await lab.state()).host.experiment.breaks, 'not yet').toBe(0);
  await lab.call('dev_hits', 1);
  s = await lab.state();
  expect(s.host.experiment.breaks, '22 hits break it').toBe(1);
  expect(s.host.experiment.coins, 'for the same 25 coins').toBe(25);
  await lab.shot('cplus96_light');
  await lab.open('./?dev=1&alt=hold#tree');
  await lab.open('./?dev=1&alt=hold#rock-plus');
  await expect.poll(async () => (await lab.state()).route).toBe('rock-plus');
  expect((await lab.state()).host.session.variant).toBe('hold');
});

test('the kinds of rock look different, and the far islet shows the next great one', async ({ lab }, info) => {
  test.skip(info.project.name === 'p720', 'phone and desktop');
  await lab.open('./#rock-plus');
  const seen = [];
  for (const n of [2, 14, 26, 32, 50, 68, 80, 104]) {
    await lab.call('dev_rock', n);
    await lab.page.waitForTimeout(400);
    const e = (await lab.state()).host.experiment;
    seen.push(`${e.rock_name} -> ${e.next_big}`);
    await lab.shot(`cplus96_kind_${n}`);
  }
  console.log(`cplus96 ${info.project.name}: ${seen.join(' | ')}`);
  expect(new Set(seen.map((x) => x.split(' -> ')[0])).size, 'eight different rocks').toBe(8);
  for (const x of seen) expect(x.split(' -> ')[1], 'the next great rock ahead').toMatch(/^Great /);
});

test('the tracks page: the thirty-minute table and the alternatives', async ({ page }, info) => {
  test.skip(info.project.name === 'p720', 'phone and desktop are enough for a static page');
  await page.goto('./tracks.html');
  await expect.poll(async () => page.locator('#runsTable tr').count(), { timeout: 10_000 }).toBe(8);
  await expect(page.locator('#runsTable')).toContainText('C+, natural tapping');
  await expect(page.locator('#runsTable')).toContainText('1211.9초');
  const alts = await page.locator('.card[data-id="rock-plus"] a.btn.ghost').evaluateAll((as) => as.map((a) => a.getAttribute('href')));
  expect(alts).toContain('./?dev=1&alt=light#rock-plus');
  expect(alts).toContain('./?dev=1&alt=hold#rock-plus');
  await expect(page.locator('#guide15')).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1), 'no sideways scrolling').toBe(true);
  if (process.env.FUNLAB_SHOTS) await page.locator('#runs30').scrollIntoViewIfNeeded().then(() => page.screenshot({ path: `${process.env.FUNLAB_SHOTS}/cplus96_page_${info.project.name}.png` }));
});
