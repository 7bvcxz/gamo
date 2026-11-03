// Step 99: the 15-minute test in the real web build. Each of C, C+, E and E+
// opens with ?t15=1, takes real input first (taps on the rock, a press of the
// button), then is time-stepped to fifteen minutes of play by a scripted
// player (C and C+ 2.5 hits a second; everything buys when it can pay). The
// checkpoints at 0, 3, 7, 10 and 15 minutes are kept in this browser and the
// test page (play15.html) shows them; the frame rate is measured at the start
// and at fifteen minutes on a narrow portrait phone. The page itself: one
// click to each variant, ratings that start as "not yet tested", a rating
// kept across a reload, a reset that clears one variant only, exports with
// no invented answers. Objective evidence only -- never "15 minutes of fun
// verified".
import fs from 'node:fs';
import { test, expect } from '../lib/lab.mjs';

const fps = (page, ms) => page.evaluate((d) => new Promise((resolve) => {
  let n = 0;
  const t0 = performance.now();
  const tick = () => { n++; if (performance.now() - t0 < d) requestAnimationFrame(tick); else resolve(n / ((performance.now() - t0) / 1000)); };
  requestAnimationFrame(tick);
}), ms);
const median3 = async (page) => [await fps(page, 1500), await fps(page, 1500), await fps(page, 1500)].sort((a, b) => a - b)[1];
const runs = (page) => page.evaluate(() => JSON.parse(localStorage.getItem('funlab.play15.runs.v1') || '[]'));

test('fifteen minutes of each variant: real input, then time-stepped; the checkpoints are kept and the test page shows them', async ({ lab, page }, info) => {
  test.skip(info.project.name === 'p720', 'a narrow portrait phone and desktop');
  test.setTimeout(1_500_000);
  const out = {};
  for (const id of ['rock', 'rock-plus', 'tycoon', 'tycoon-plus']) {
    await lab.open(`./?t15=1#${id}`);
    await expect.poll(async () => (await lab.state()).route, { timeout: 15_000 }).toBe(id);
    let s = await lab.state();
    expect(s.host.t15.on, `${id}: the 15-minute test is on`).toBe(true);
    const fpsStart = await median3(page);
    // Real input first, through the canvas.
    if (id.startsWith('rock')) {
      const before = s.host.experiment.taps;
      for (let i = 0; i < 5; i++) await lab.tapRect(s.host.experiment.rock_rect);
      s = await lab.state();
      expect(s.host.experiment.taps - before, `${id}: real taps land`).toBeGreaterThanOrEqual(4);
    } else {
      await lab.call('dev_coins', 12);
      s = await lab.state();
      await lab.tapRect(s.host.rects.action);
      s = await lab.state();
      expect(s.host.experiment.level, `${id}: a real press buys`).toBe(1);
    }
    // Then fifteen minutes of play time, scripted.
    await lab.call('dev_time_scale', 0);
    for (let guard = 0; guard < 120 && s.host.session.active_seconds < 900; guard++) {
      if (id.startsWith('rock')) await lab.call('dev_hits', 25);
      s = (await lab.call('dev_advance', 10)).state;
      for (let i = 0; i < 4 && s.host.action.affordable; i++) {
        await lab.call('dev_action');
        s = await lab.state();
      }
    }
    const sum = s.host.session;
    for (const k of ['at_0min', 'at_3min', 'at_7min', 'at_10min', 'at_15min']) expect(sum[k], `${id}: ${k}`).not.toBeNull();
    await lab.call('dev_time_scale', 1);
    await page.waitForTimeout(500);
    const fpsEnd = await median3(page);
    await lab.shot(`play15_${id}_15min`);
    const kept = (await runs(page)).filter((r) => r.id === id);
    expect(kept.length, `${id}: kept in this browser`).toBeGreaterThanOrEqual(1);
    const rec = kept[kept.length - 1];
    expect(Object.keys(rec.at).sort((a, b) => a - b), `${id}: every checkpoint`).toEqual(['0', '3', '7', '10', '15']);
    const p15 = rec.at['15'].probe;
    out[id] = { fpsStart, fpsEnd, actions: rec.at['15'].actions, upgrades: rec.at['15'].upgrades, rewards: rec.at['15'].rewards, probe: p15 };
    console.log(`play15 ${info.project.name} ${id}: fps ${fpsStart.toFixed(1)} -> ${fpsEnd.toFixed(1)} at 15:00; actions ${rec.at['15'].actions}, upgrades ${rec.at['15'].upgrades} (${rec.at['15'].visible_upgrades} visible), rewards ${JSON.stringify(rec.at['15'].rewards)}, ${JSON.stringify(p15)}`);
    if (info.project.name === 'phone') expect(fpsEnd, `${id}: no collapse in frame rate by fifteen minutes on a narrow phone`).toBeGreaterThanOrEqual(fpsStart * 0.5);
  }
  expect(out['rock-plus'].upgrades, 'C+ keeps upgrading past where C stops').toBeGreaterThan(out.rock.upgrades);
  expect(out['tycoon-plus'].probe.delivered, 'E+ makes more than E by fifteen minutes').toBeGreaterThan(out.tycoon.probe.delivered);
  // The test page reads what the Lab kept.
  await page.goto('./play15.html');
  await expect(page.locator('#mineTables h3')).toHaveCount(4);
  for (const letter of ['C', 'C+', 'E', 'E+']) await expect(page.locator('#mineTables')).toContainText(letter);
  expect(await page.locator('#mineTables table').count()).toBe(4);
  expect(await page.locator('#mineTables table').first().locator('tr').count(), 'a header and five checkpoints').toBe(6);
  await page.screenshot({ path: test.info().outputPath(`play15_page_${info.project.name}.png`), fullPage: true });
  if (process.env.FUNLAB_SHOTS) await page.screenshot({ path: `${process.env.FUNLAB_SHOTS}/play15_page_${info.project.name}.png`, fullPage: true });
});

test('the test page: one click to each, nothing rated until a person rates it, reset per variant, honest exports', async ({ page }, info) => {
  test.skip(info.project.name === 'p720', 'a narrow portrait phone and desktop');
  await page.goto('./play15.html');
  const starts = await page.locator('.card a.start').evaluateAll((as) => as.map((a) => a.getAttribute('href')));
  expect(starts).toEqual(['./?t15=1#rock', './?t15=1#rock-plus', './?t15=1#tycoon', './?t15=1#tycoon-plus']);
  await expect(page.locator('#summary')).toContainText('아직 안 해 봄');
  await expect(page.locator('#botTables h3')).toHaveCount(4);
  await expect(page.locator('#compareTable')).toContainText('대기');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1), 'no sideways scrolling').toBe(true);
  // A rating on C+ and E survives a reload; the others stay "not yet tested".
  await page.locator('.card[data-id="rock-plus"] .dim[data-dim="comprehension"] button[data-n="4"]').click();
  await page.locator('.card[data-id="rock-plus"] .dim[data-dim="strain"] button[data-n="2"]').click();
  await page.locator('.card[data-id="tycoon"] .dim[data-dim="continue"] button[data-n="3"]').click();
  await page.reload();
  await expect(page.locator('.card[data-id="rock-plus"] .dim[data-dim="comprehension"] button[data-n="4"]')).toHaveClass(/on/);
  await expect(page.locator('.card[data-id="rock"] .state')).toContainText('아직 안 해 봄');
  // Reset clears one variant only.
  page.once('dialog', (d) => d.accept());
  await page.locator('.card[data-id="tycoon"] .reset').click();
  await expect(page.locator('.card[data-id="tycoon"] .state')).toContainText('아직 안 해 봄');
  await expect(page.locator('.card[data-id="rock-plus"] .state')).toContainText('점수 있음');
  // Exports: the rating as given, everything else "not yet tested".
  const [dl] = await Promise.all([page.waitForEvent('download'), page.click('#exportJson')]);
  const doc = JSON.parse(fs.readFileSync(await dl.path(), 'utf8'));
  const by = Object.fromEntries(doc.ratings.map((r) => [r.id, r]));
  expect(by['rock-plus'].comprehension).toBe(4);
  expect(by['rock-plus'].strain).toBe(2);
  expect(by['rock-plus'].strain_means).toBe('fatigue');
  expect(by['rock-plus'].satisfaction).toBe('not yet tested');
  expect(by.tycoon.continue, 'reset').toBe('not yet tested');
  expect(by['tycoon-plus'].strain_means).toBe('boredom');
  expect(by.rock.entered).toBe(false);
  const [csv] = await Promise.all([page.waitForEvent('download'), page.click('#exportCsv')]);
  const text = fs.readFileSync(await csv.path(), 'utf8');
  expect(text.split('\n')[0]).toBe('kind,id,run,minute,field,value');
  expect(text).toContain('rating,rock-plus,,,comprehension,4');
  expect(text).toContain('rating,rock,,,comprehension,not yet tested');
});
