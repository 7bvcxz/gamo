// Helpers for driving the real Windup web build.
import { expect } from '@playwright/test';

/** Opens the game through its public entry (index.html -> runner) and waits
 *  until the bridge answers and the canvas has drawn more than one colour. */
export async function openGame(page, query = '') {
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.addInitScript(() => { window.WINDUP_E2E = true; });
  await page.goto(`index.html${query}`);
  await page.waitForFunction(() => window.windup && window.windup.ready === true, null, { timeout: 120_000 });
  await expect.poll(() => paintedColours(page), { timeout: 30_000 }).toBeGreaterThan(3);
  return { errors };
}

/** Distinct colours on a coarse grid of the canvas: a blank or one-colour
 *  canvas is not a running game (AGENTS.md, 2026-08-08). */
export async function paintedColours(page) {
  const shot = await page.locator('canvas').screenshot();
  return page.evaluate(async (b64) => {
    const img = new Image();
    img.src = 'data:image/png;base64,' + b64;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const g = c.getContext('2d');
    g.drawImage(img, 0, 0);
    const seen = new Set();
    for (let y = 0; y < img.height; y += Math.max(1, img.height >> 4))
      for (let x = 0; x < img.width; x += Math.max(1, img.width >> 4)) {
        const d = g.getImageData(x, y, 1, 1).data;
        seen.add(`${d[0] >> 3},${d[1] >> 3},${d[2] >> 3}`);
      }
    return seen.size;
  }, shot.toString('base64'));
}

export const state = (page) => page.evaluate(() => window.windup.state());
export const call = (page, name, arg) => page.evaluate(([n, a]) => window.windup.call(n, a), [name, arg]);
export const events = async (page) =>
  (await page.evaluate(() => window.windup.events())).split('\n').filter(Boolean).map((l) => JSON.parse(l));

/** Render budget (draw calls, render objects) -- deterministic, unlike frames a
 *  second on a shared machine whose load the test cannot control. The two
 *  real regressions so far were both visible here (Step 04: 180 draw calls
 *  from one texture per doll part; Step 05: antialiased prop lines). */
// Step 12 re-measured every stage up to all twelve dolls (dev_advance with the
// key held): 'objects' grows with what the room shows -- props, dolls, threads --
// and the frozen 0.10.0 base itself reached 447 at stage 5, so 420 only ever
// held for the first stages. Draw calls stay at 150 (the guard that caught both
// real regressions); 0.12.0 batched its lights and is now at or under 146 at
// every stage in base and C (0.10.0 base: up to 162). Objects: 500, above the
// highest measured (479, C with ten awake).
export const RENDER_BUDGET = { draw_calls: 150, objects: 500 };

export async function withinBudget(page) {
  const r = await page.evaluate(() => window.windup.call('dev_render_info'));
  return { ...r, ok: r.draw_calls <= RENDER_BUDGET.draw_calls && r.objects <= RENDER_BUDGET.objects };
}

/** The key's position on the page, from the game's own answer. */
export async function keyPoint(page) {
  const k = await call(page, 'key_point');
  const box = await page.locator('canvas').boundingBox();
  return { x: box.x + k.x * box.width, y: box.y + k.y * box.height };
}
