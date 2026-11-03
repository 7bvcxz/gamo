// Step 94: the owner's two picks, C and E, each with a frozen baseline and an
// improved track (C+ #rock-plus, E+ #tycoon-plus). The launcher's chooser
// opens all four by a finger or the mouse; the six original links still open
// their experiments from nothing; a track's run records which track and
// alternative it is; and the tracks page (tracks.html) holds the 3/15/30-minute
// protocol and a scorecard whose every cell is "pending" until a person
// scores it, kept in this browser alone and exported as JSON and CSV.
// FUNLAB_SHOTS=<dir> keeps screenshots.
import { test, expect } from '../lib/lab.mjs';

test('the chooser: C, C+, E and E+ on screen, each opens its own run', async ({ lab }) => {
  await lab.open('./');
  let s = await lab.state();
  expect(Object.keys(s.picks).sort()).toEqual(['rock', 'rock-plus', 'tycoon', 'tycoon-plus']);
  expect(s.tracks).toEqual(['rock-plus', 'tycoon-plus']);
  for (const [id, r] of Object.entries({ ...s.picks, ...s.tiles })) {
    expect(r[0] >= 0 && r[1] >= 0 && r[0] + r[2] <= s.window[0] + 0.5 && r[1] + r[3] <= s.window[1] + 0.5, `${id} is on screen ${r}`).toBe(true);
  }
  await lab.shot('tracks94_launcher');
  for (const id of ['rock-plus', 'tycoon-plus', 'rock', 'tycoon']) {
    await lab.tapRect(s.picks[id]);
    s = await lab.state();
    expect(s.route, `${id}'s button`).toBe(id);
    expect(await lab.hash(), 'its direct link').toBe(`#${id}`);
    expect(s.host.base).toBe(id.replace('-plus', ''));
    expect(s.host.session.actions + s.host.session.upgrades.length, `${id} starts from nothing`).toBe(0);
    if (id.endsWith('-plus')) await lab.shot(`tracks94_${id}`);
    await lab.tapRect(s.host.rects.back);
    s = await lab.state();
    expect(s.screen).toBe('launcher');
  }
});

test('all eight direct links open fresh; C+ is played with real taps like C', async ({ lab }, info) => {
  test.skip(info.project.name === 'p720', 'phone and desktop cover the links');
  for (const id of ['island', 'evolution', 'rock', 'harvest', 'tycoon', 'tree', 'rock-plus', 'tycoon-plus']) {
    await lab.open(`./#${id}`);
    const s = await lab.state();
    expect(s.route, `#${id}`).toBe(id);
    expect(s.host.session.experiment).toBe(id);
    expect(s.host.session.actions, `#${id} from nothing`).toBe(0);
  }
  // C+ (still the baseline's rules at Step 94): three real taps on the rock are three hits.
  await lab.open('./?alt=check#rock-plus');
  let s = await lab.state();
  for (let i = 0; i < 3; i++) await lab.tapRect(s.host.experiment.rock_rect);
  s = await lab.state();
  expect(s.host.experiment.hits, 'one tap, one hit').toBe(3);
  expect(s.host.alt, 'the alternative asked for').toBe('check');
  expect(s.host.session.variant, 'and recorded with the run').toBe('check');
  expect(s.host.session.run).toBe(1);
  expect(s.host.session.actions_per_minute[0], 'actions by minute').toBe(3);
  expect(s.host.session.longest_upgrade_wait_s, 'the wait for a first upgrade is open').toBeGreaterThan(0);
});

test('the tracks page: four ways in, the protocol, every score pending until a person enters it', async ({ page }, info) => {
  test.skip(info.project.name === 'p720', 'phone and desktop are enough for a static page');
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto('./tracks.html');
  await page.evaluate(() => localStorage.removeItem('funlab.tracks.v1'));
  await page.reload();
  const fits = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1);
  expect(fits, 'no sideways scrolling').toBe(true);
  expect(await page.locator('.card .letter').allTextContents()).toEqual(['C', 'C+', 'E', 'E+']);
  const hrefs = await page.locator('.card a.btn:not(.ghost)').evaluateAll((as) => as.map((a) => a.getAttribute('href')));
  expect(hrefs).toEqual(['./#rock', './#rock-plus', './#tycoon', './#tycoon-plus']);
  await expect(page.locator('#summary td.pending')).toHaveCount(12);
  await expect(page.locator('#objectiveTable')).toContainText('Lv8, 배달 182');
  await expect(page.locator('#objectiveTable')).toContainText('바위 7개 깸');
  if (process.env.FUNLAB_SHOTS) await page.screenshot({ path: `${process.env.FUNLAB_SHOTS}/tracks94_page_${info.project.name}.png`, fullPage: true });

  // Score C+ at 3 minutes on two questions, and what bored; E at 15 on one.
  const cplus = page.locator('.card[data-id="rock-plus"]');
  await expect(cplus.locator('.state')).toContainText('대기');
  await cplus.locator('.dim[data-dim="ease"] button[data-n="5"]').click();
  await cplus.locator('.dim[data-dim="satisfaction"] button[data-n="4"]').click();
  await cplus.locator('textarea[data-field="bored"]').fill('같은 바위를 오래 쳤다');
  await expect(cplus.locator('.state')).not.toContainText('대기');
  const e = page.locator('.card[data-id="tycoon"]');
  await e.locator('.tabs button[data-m="15"]').click();
  await e.locator('.dim[data-dim="curiosity"] button[data-n="3"]').click();
  await expect(page.locator('#summary td.pending')).toHaveCount(10);
  await expect(page.locator('#summary')).toContainText('4.50');
  if (process.env.FUNLAB_SHOTS) await page.locator('#scores').scrollIntoViewIfNeeded().then(() => page.screenshot({ path: `${process.env.FUNLAB_SHOTS}/tracks94_scores_${info.project.name}.png` }));
  await page.reload();
  await expect(page.locator('#summary td.pending'), 'kept in this browser').toHaveCount(10);
  const keys = await page.evaluate(() => Object.keys(localStorage));
  expect(keys.filter((k) => !k.startsWith('funlab.')), 'nothing outside the funlab. keys').toEqual([]);
  expect(await page.evaluate(() => localStorage.getItem('funlab.compare.v1')), 'the six-way scores are not touched').toBe(null);

  const [dl] = await Promise.all([page.waitForEvent('download'), page.click('#exportJson')]);
  const data = JSON.parse(await (await dl.createReadStream()).toArray().then((c) => Buffer.concat(c).toString()));
  const row = data.rows.find((r) => r.id === 'rock-plus' && r.minutes === 3);
  expect([row.ease, row.satisfaction, row.curiosity, row.continue]).toEqual([5, 4, null, null]);
  expect(row.bored).toBe('같은 바위를 오래 쳤다');
  expect(data.pending.length, 'ten cells still pending, none made up').toBe(10);
  expect(data.rows.find((r) => r.id === 'rock' && r.minutes === 30).entered).toBe(false);
  expect(data.objective_historical.rock.scripted.hits).toBe(442);
  const [csv] = await Promise.all([page.waitForEvent('download'), page.click('#exportCsv')]);
  const text = await (await csv.createReadStream()).toArray().then((ch) => Buffer.concat(ch).toString());
  expect(text.split('\n')[0]).toBe('id,letter,track,minutes,entered,ease,satisfaction,curiosity,continue,average,bored,note,scored_at,tester,device');
  expect(text.split('\n').filter((l) => l.trim()).length, 'a row for every cell').toBe(13);
  await page.evaluate(() => localStorage.removeItem('funlab.tracks.v1'));
  expect(errors).toEqual([]);
});
