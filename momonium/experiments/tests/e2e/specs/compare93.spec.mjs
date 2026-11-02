// Step 93: the same pictures of every experiment for the comparison page --
// each opened fresh at 720x1280 (the p720 project only), played by a simple
// scripted player (buy when it can pay; C taps the rock 2.5 times a second;
// D harvests when ripe), photographed at 5 s, 1:00 and 3:00 of play. Also
// checks that all six direct links load, play and start from nothing.
//   FUNLAB_COMPARE_OUT=<dir> momonium/experiments/tools/e2e.sh specs/compare93.spec.mjs --project p720
import { test, expect } from '../lib/lab.mjs';

const IDS = ['island', 'rock', 'tree', 'evolution', 'harvest', 'tycoon'];
const MARKS = [[5, '0'], [60, '1m'], [180, '3m']];

for (const id of IDS) {
  test(`${id}: a fresh three minutes, photographed at 5 s, 1:00 and 3:00`, async ({ lab }, info) => {
    test.skip(info.project.name !== 'p720', 'the comparison pictures are taken at 720x1280 only');
    await lab.open(`./#${id}`);
    await lab.call('dev_time_scale', 0);
    let s = await lab.state();
    expect(s.route).toBe(id);
    expect(s.host.session.actions, 'fresh: nothing done yet').toBe(0);
    const marks = MARKS.slice();
    let t = 0;
    while (marks.length) {
      // C is played by tapping: 2.5 hits a second of play.
      if (id === 'rock') await lab.call('dev_hits', 1);
      const step = id === 'rock' ? 0.4 : 0.5;
      s = (await lab.call('dev_advance', step)).state;
      t += step;
      if (s.host.action.affordable && s.host.action.kind !== 'rest') await lab.call('dev_action', null);
      if (t >= marks[0][0]) {
        const [, tag] = marks.shift();
        await lab.page.waitForTimeout(1200);
        if (process.env.FUNLAB_COMPARE_OUT) await lab.canvas.screenshot({ path: `${process.env.FUNLAB_COMPARE_OUT}/${id}_${tag}.png` });
      }
    }
    s = await lab.state();
    console.log(`compare93 ${id}: ${s.host.session.upgrades.length} upgrades, ${s.host.session.actions} actions in 180 s`);
    expect(s.host.session.upgrades.length, `${id} progresses in three minutes`).toBeGreaterThanOrEqual(5);
  });
}

test('the comparison page: six experiments, A C F first, every link opens its experiment fresh', async ({ page }, info) => {
  test.skip(info.project.name === 'p720', 'phone and desktop are enough for a static page');
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto('./compare.html');
  const titles = await page.locator('.card .title').allTextContents();
  expect(titles, 'A, C, F first, then B, D, E').toEqual(['Island Growth', 'Break & Upgrade', 'Endless Growth', 'Momo Evolution', 'Harvest Burst', 'Production Tycoon']);
  expect(await page.locator('.card .prio').count(), 'three marked first').toBe(3);
  await expect.poll(async () => (await page.locator('#objectiveTable tr').count()), { timeout: 10_000 }).toBe(7);
  // Every picture is there (they load lazily: bring each into view first).
  const imgs = await page.locator('.thumbs img').all();
  expect(imgs.length, 'three pictures for each of six').toBe(18);
  for (const img of imgs) {
    await img.scrollIntoViewIfNeeded();
    await expect.poll(() => img.evaluate((el) => el.complete ? el.naturalWidth : 0), { timeout: 10_000 }).toBeGreaterThan(100);
  }
  if (process.env.FUNLAB_SHOTS) {
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({ path: `${process.env.FUNLAB_SHOTS}/compare93_page_${info.project.name}.png`, fullPage: true });
  }
  const hrefs = await page.locator('.card a.btn:not(.ghost)').evaluateAll((as) => as.map((a) => a.getAttribute('href')));
  expect(hrefs).toEqual(['./#island', './#rock', './#tree', './#evolution', './#harvest', './#tycoon']);
  // Each link opens that experiment, from nothing.
  for (const href of hrefs) {
    const p = await page.context().newPage();
    await p.addInitScript(() => { window.FUNLAB_E2E = true; });
    await p.goto(new URL(href, page.url()).href);
    await p.waitForFunction(() => window.funlab && window.funlab.ready && typeof window.funlab.state === 'function', null, { timeout: 90_000 });
    await p.waitForTimeout(400);
    const s = await p.evaluate(() => window.funlab.state());
    expect(s.route, href).toBe(href.slice(3));
    expect(s.host.session.actions + s.host.session.upgrades.length, `${href} starts from nothing`).toBe(0);
    await p.close();
  }
  expect(errors).toEqual([]);
});

test('scores: only tested experiments rank, blanks stay blank, kept in this browser, exported', async ({ page }, info) => {
  test.skip(info.project.name === 'p720', 'phone and desktop are enough for a static page');
  await page.goto('./compare.html');
  await page.evaluate(() => localStorage.removeItem('funlab.compare.v1'));
  await page.reload();
  await expect(page.locator('#ranking')).toContainText('아직 점수가 없다');
  // Score C on all four, F on two; leave the rest.
  const cardOf = (name) => page.locator('.card', { hasText: name });
  for (const [dim, n] of [['intuitive', 5], ['delight', 4], ['curious', 3], ['continue', 4]]) await cardOf('Break & Upgrade').locator(`.dim[data-dim="${dim}"] button[data-n="${n}"]`).click();
  await cardOf('Endless Growth').locator('.dim[data-dim="curious"] button[data-n="5"]').click();
  await cardOf('Endless Growth').locator('.dim[data-dim="intuitive"] button[data-n="4"]').click();
  const rows = await page.locator('#ranking tr').allTextContents();
  expect(rows.length, 'a header and two scored experiments').toBe(3);
  expect(rows[1]).toContain('Endless Growth');
  expect(rows[1]).toContain('4.50');
  expect(rows[2]).toContain('Break & Upgrade');
  expect(rows[2]).toContain('4.00');
  await expect(page.locator('#ranknote')).toContainText('A, B, D, E');
  if (process.env.FUNLAB_SHOTS) await page.locator('#ranking').screenshot({ path: `${process.env.FUNLAB_SHOTS}/compare93_scores_${info.project.name}.png` }).catch(() => {});
  // Kept in this browser (its own key), and only there.
  await page.reload();
  expect((await page.locator('#ranking tr').allTextContents()).length, 'still there after a reload').toBe(3);
  const keys = await page.evaluate(() => Object.keys(localStorage));
  expect(keys.filter((k) => !k.startsWith('funlab.')), 'nothing outside the funlab. keys').toEqual([]);
  const [dl] = await Promise.all([page.waitForEvent('download'), page.click('#exportJson')]);
  const data = JSON.parse(await (await dl.createReadStream()).toArray().then((c) => Buffer.concat(c).toString()));
  const c = data.rows.find((r) => r.id === 'rock');
  expect([c.intuitive, c.delight, c.curious, c.continue]).toEqual([5, 4, 3, 4]);
  expect(data.rows.find((r) => r.id === 'island').tested, 'untested is marked, not zero').toBe(false);
  expect(data.rows.find((r) => r.id === 'island').intuitive).toBe(null);
  expect(data.objective && data.objective.runs && Object.keys(data.objective.runs).length, 'with the scripted numbers').toBe(6);
  const [csv] = await Promise.all([page.waitForEvent('download'), page.click('#exportCsv')]);
  const text = await (await csv.createReadStream()).toArray().then((ch) => Buffer.concat(ch).toString());
  expect(text.split('\n')[0]).toBe('id,letter,name,tested,intuitive,delight,curious,continue,average,note,scored_at,tester,device');
  await page.evaluate(() => localStorage.removeItem('funlab.compare.v1'));
});
