// Step 07 V2, the visible workflow in a running browser: a real click on the
// key turns it and adds energy; real winding wakes a doll and it is seen
// helping another; resizing the window mid-game keeps the key clickable and
// every doll on screen; pause/return and reload are covered by play04.
import { test, expect } from '@playwright/test';
import { openGame, state, call, events, keyPoint } from '../lib/game.mjs';

test('click, awaken, help, resize', async ({ page }, info) => {
  test.skip(info.project.name !== 'desktop', 'resizing is a desktop window behaviour');
  test.setTimeout(240_000);
  const { errors } = await openGame(page, '?fresh=1');
  let k = await keyPoint(page);
  const s0 = await state(page);
  await page.mouse.click(k.x, k.y);
  await expect.poll(async () => (await state(page)).winds).toBe(1);
  const s1 = await state(page);
  expect(s1.energy).toBeGreaterThan(s0.energy);
  await expect.poll(async () => (await state(page)).key_angle, { timeout: 3000 }).toBeGreaterThan(1.0);  // a quarter turn ~1.57 rad

  // Real winding (hold) until the first doll is up and a doll helps another.
  await page.mouse.move(k.x, k.y);
  await page.mouse.down();
  await expect.poll(async () => (await state(page)).awake, { timeout: 60_000 }).toBe(1);
  await page.mouse.up();
  await expect.poll(async () => (await events(page)).filter((e) => e.ev === 'help').length, { timeout: 30_000 }).toBeGreaterThan(0);
  const help = (await events(page)).find((e) => e.ev === 'help');
  expect(help.helper).toBe(0);
  expect(help.target).toBe(1);

  // Resize mid-game: the key stays where the game says, clicks still land, dolls stay on screen.
  for (const vp of [{ width: 1920, height: 1080 }, { width: 1024, height: 768 }, { width: 1280, height: 720 }]) {
    await page.setViewportSize(vp);
    await page.waitForTimeout(600);
    k = await keyPoint(page);
    const before = (await state(page)).winds;
    await page.waitForTimeout(250);
    await page.mouse.click(k.x, k.y);
    await expect.poll(async () => (await state(page)).winds).toBe(before + 1);
    const off = await page.evaluate(() => window.windup.call('dev_dolls_on_screen'));
    expect(off.off_screen, JSON.stringify(off)).toBe(0);
  }
  expect(errors).toEqual([]);
});
