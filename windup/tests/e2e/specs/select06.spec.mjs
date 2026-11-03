// Step 06: the picker page opens each variant from a fresh start, and the
// frozen Step 04 reference build still runs beside them.
import { test, expect } from '@playwright/test';

test('picker links start each variant fresh; the Step 04 build still runs', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.addInitScript(() => { window.WINDUP_E2E = true; });
  for (const [label, v] of [['기준', 'base'], ['A · 감는 손맛', 'a'], ['B · 깨어나는 인형들', 'b'], ['C · 인형이 인형을 깨운다', 'c']]) {
    await page.goto('variants.html');
    await page.getByText(label, { exact: true }).click();
    await page.waitForFunction(() => window.windup && window.windup.ready === true, null, { timeout: 120_000 });
    const s = await page.evaluate(() => window.windup.state());
    expect(s.config.variant).toBe(v);
    expect(s.config.fresh).toBe(true);
    expect(s.build_id.endsWith('+' + v)).toBe(true);
  }
  await page.goto('variants.html');
  await page.getByText('Step 04 빌드(0.4.0, 그대로 보존)').click();
  await page.waitForFunction(() => window.windup && window.windup.ready === true, null, { timeout: 120_000 });
  const ref = await page.evaluate(() => window.windup.state());
  expect(ref.version).toBe('0.4.0');
  // Step 11: the tournament build, frozen, still runs each variant.
  for (const v of ['A', 'C']) {
    await page.goto('variants.html');
    await page.getByText(`0.10.0 ${v}`, { exact: true }).click();
    await page.waitForFunction(() => window.windup && window.windup.ready === true, null, { timeout: 120_000 });
    const t = await page.evaluate(() => window.windup.state());
    expect(t.build_id).toBe(`0.10.0+${v.toLowerCase()}`);
  }
  expect(errors).toEqual([]);
});
