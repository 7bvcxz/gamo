// Step 101: the decision memo points to pages and links that must keep
// working while the owner decides -- the Lab, the four track variants by
// direct link, the 15-minute test, the 30-minute report, the two-track
// scorecards and the six-way comparison, each linking to the memo where it
// should. No product was created; this checks nothing was lost.
import { test, expect } from '../lib/lab.mjs';

const PAGES = [['compare.html', null], ['tracks.html', 'DECISION.md'], ['play15.html', 'DECISION.md'], ['report30.html', 'DECISION.md']];

test('the pages the memo names open, without errors, and link to the memo', async ({ page }, info) => {
  test.skip(info.project.name === 'p720', 'a narrow portrait phone and desktop');
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  for (const [path, memo] of PAGES) {
    const res = await page.goto(`./${path}`);
    expect(res.status(), `${path} is there`).toBe(200);
    await expect(page.locator('h1')).toBeVisible();
    if (memo) expect(await page.locator(`a[href$="${memo}"]`).count(), `${path} links the memo`).toBeGreaterThanOrEqual(1);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1), `${path}: no sideways scrolling`).toBe(true);
  }
  expect(errors, 'no page errors').toEqual([]);
});

test('C, C+, E and E+ still open by direct link and play', async ({ lab }, info) => {
  test.skip(info.project.name === 'p720', 'a narrow portrait phone and desktop');
  for (const id of ['rock', 'rock-plus', 'tycoon', 'tycoon-plus']) {
    await lab.open(`./#${id}`);
    await expect.poll(async () => (await lab.state()).route, { timeout: 15_000 }).toBe(id);
    const s = await lab.state();
    expect(s.host.playable, `${id} is playable`).toBe(true);
    expect(s.host.action.label, `${id} has its one button`).toBeTruthy();
  }
});
