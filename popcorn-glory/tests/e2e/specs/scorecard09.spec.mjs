// Step 09: the owner's scorecard page beside the game (docs/popcorn-glory/scorecard.html).
// It must open the three experiments with the playtest protocol (?trial=1), keep what was
// entered across a reload (this browser's localStorage only), export exactly that, and send
// nothing anywhere. A plain page, no Godot: a scorecard that loses a score is worse than none.
import { test, expect } from '@playwright/test';

test('scorecard: trial links, saved across a reload, exported as entered, nothing sent', async ({ page, baseURL }) => {
  const foreign = [];
  page.on('request', (r) => { if (!r.url().startsWith(new URL(baseURL).origin)) foreign.push(r.url()); });
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

  await page.goto('scorecard.html');
  await page.evaluate(() => localStorage.removeItem('popcorn-glory.scorecard.v1'));
  await page.reload();

  // Links: the three experiments, each with ?trial=1 so the 3:00 clock shows.
  const hrefs = await page.locator('#links a').evaluateAll((as) => as.map((a) => a.getAttribute('href')));
  expect(hrefs).toEqual(['./?trial=1#click', './?trial=1#perfect', './?trial=1#explosion']);

  // Enter: B gets 4/5/3/skip and a memo; A gets Q1 = 2; the order.
  const pick = (exp, q, v) => page.locator(`[data-exp="${exp}"] input[name="${exp}-${q}"][value="${v}"] + span`).click();
  await pick('perfect', 'q1', 4); await pick('perfect', 'q2', 5); await pick('perfect', 'q3', 3); await pick('perfect', 'q4', 'skip');
  await pick('click', 'q1', 2);
  await page.fill('#perfect-memo', '금색에 떼는 순간이 좋았다');
  await page.fill('#order', 'B→C→A');

  await page.reload();
  await expect(page.locator('input[name="perfect-q2"][value="5"]')).toBeChecked();
  await expect(page.locator('input[name="perfect-q4"][value="skip"]')).toBeChecked();
  await expect(page.locator('input[name="click-q1"][value="2"]')).toBeChecked();
  await expect(page.locator('#perfect-memo')).toHaveValue('금색에 떼는 순간이 좋았다');
  await expect(page.locator('#order')).toHaveValue('B→C→A');

  await page.click('#md');
  const md = await page.locator('#out').inputValue();
  expect(md).toContain('순서: B→C→A');
  // The mean uses only the answered questions and says how many: (4+5+3)/3.
  expect(md).toContain('| B 완벽한 팝 | 4 | 5 | 3 | 건너뜀 | 4.00 (3) | 금색에 떼는 순간이 좋았다 |');
  expect(md).toContain('| A 클릭 & 팝 | 2 | — | — | — | 2.00 (1) |');
  expect(md).toContain('| C 팝콘 폭발 | — | — | — | — | — |');

  await page.click('#json');
  const j = JSON.parse(await page.locator('#out').inputValue());
  expect(j.rater).toBe('human-owner');
  expect(j.rows.perfect).toMatchObject({ q1: 4, q2: 5, q3: 3, q4: 'skip' });

  expect(foreign).toEqual([]);
  expect(errors).toEqual([]);
  // Keep later runs clean.
  await page.evaluate(() => localStorage.removeItem('popcorn-glory.scorecard.v1'));
});
