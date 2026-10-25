// Step 43: the launch page and the addresses it links. launch.html shows the
// version from version.json and opens the game, the demo island or the large
// island demo; ?demo=... opens that labelled demo straight away (never saved),
// and the way back from it leads to the player's own island.
import { test, expect } from '@playwright/test';

async function ready(page) {
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.call === 'function', null, { timeout: 90_000 });
  await page.waitForTimeout(600);
}
const call = (page, name, arg) => page.evaluate(([n, a]) => window.momonium.call(n, a), [name, arg]);

test('launch page, demo addresses and the way back', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
  // The player's own island first, so there is something to come back to.
  await page.goto('./');
  await ready(page);
  await call(page, 'set_language', 'en');
  const own = await page.evaluate(() => window.momonium.state());
  await page.evaluate(() => window.momonium.command({ type: 'building.place', building: 'farm', anchor: [1, 1] }));
  await call(page, 'save_now', null);
  const mine = (await page.evaluate(() => window.momonium.state())).buildings.buildings.length;
  // The launch page: its version is the published one.
  await page.goto('./launch.html');
  const v = await (await page.request.get('./version.json')).json();
  await expect(page.locator('#version')).toContainText(`v${v.version}`);
  await expect(page.locator('#version')).toContainText(v.pack.replace(/^game-|\.pck$/g, ''));
  // Its large-demo link, by a real tap or click.
  const link = page.locator('#large');
  if (info.project.use.hasTouch) await link.tap(); else await link.click();
  await ready(page);
  let st = await call(page, 'settings_ui');
  expect(st.in_demo).toBe(true);
  expect(st.demo_kind).toBe('large');
  expect(st.badge).toBe(true);
  expect((await page.evaluate(() => window.momonium.state())).buildings.buildings.length).toBeGreaterThan(150);
  // An address with ?demo=full opens the demo island.
  await page.goto('./?demo=full');
  await ready(page);
  st = await call(page, 'settings_ui');
  expect(st.demo_kind).toBe('full');
  // And plain ./ is the player's island, untouched by either demo.
  await page.goto('./');
  await ready(page);
  st = await call(page, 'settings_ui');
  expect(st.in_demo).toBe(false);
  const back = await page.evaluate(() => window.momonium.state());
  expect(back.buildings.buildings.length).toBe(mine);
  expect(back.buildings.buildings.length).toBeGreaterThan(own.buildings.buildings.length);
  expect(errors).toEqual([]);
});
