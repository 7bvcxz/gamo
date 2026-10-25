// Step 40: comfort and access in the browser -- Settings: the battery saver
// caps the frame rate at 30; the view buttons appear and move the view with a
// tap instead of a drag; text and buttons get bigger. A first-time tip points
// at the sea once land can be bought (tips asked for by this test).
import { test, expect } from '@playwright/test';

async function open(page) {
  await page.addInitScript(() => { window.MOMONIUM_E2E = true; window.MOMONIUM_E2E_TIPS = true; });
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.state === 'function', null, { timeout: 90_000 });
  await page.waitForTimeout(800);
  return { query: (name, arg) => page.evaluate(([n, a]) => window.momonium.call(n, a), [name, arg]) };
}

test('settings for comfort, and a tip', async ({ page }, info) => {
  const g = await open(page);
  await g.query('set_language', 'en');
  const canvas = page.locator('canvas');
  const tap = async (r, win) => {
    const box = await canvas.boundingBox();
    const x = box.x + (r[0] + r[2] / 2) * (box.width / win[0]);
    const y = box.y + (r[1] + r[3] / 2) * (box.height / win[1]);
    if (info.project.use.hasTouch) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
    await page.waitForTimeout(300);
  };
  // A tip, once land is affordable.
  await g.query('dev_add_money', 100);
  await page.waitForTimeout(1500);
  let o = await g.query('options');
  expect(o.tip).toBe('land');
  expect(o.tip_text).toContain('$50');
  await tap(o.tip_ok, o.window);
  o = await g.query('options');
  expect(o.tip).toBe('');
  // Settings.
  const hud = await g.query('hud');
  await tap(hud.buttons.settings, hud.window);
  o = await g.query('options');
  await tap(o.toggles.low_power, o.window);
  o = await g.query('options');
  expect(o.max_fps).toBe(30);
  await tap(o.toggles.camera_buttons, o.window);
  o = await g.query('options');
  expect(o.pad.left.length).toBe(4);
  // Close Settings and use the pad.
  await tap(hud.buttons.settings, hud.window);
  o = await g.query('options');
  const before = o.camera;
  await tap(o.pad.left, o.window);
  o = await g.query('options');
  expect(o.camera).not.toEqual(before);
  await g.query('dev_max_fps', 0);
});
