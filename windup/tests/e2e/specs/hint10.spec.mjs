// Step 10: the hold hint as a slow clicker meets it in a real browser -- clicks
// 2 s apart on the key; 20 s after the first, the hand shows (a long press on
// the key, a ring filling round its fingertip, no big ring round the gear),
// inside the render budget and without console errors; holding the key clears it.
import { test, expect } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { openGame, state, events, keyPoint, withinBudget } from '../lib/game.mjs';

// The hand's pixels in a box round the key: light and nearly neutral (the night
// tint makes its white about (190, 190, 210); the brass key and the spirit are
// strongly coloured). Measured: about 80 without the hint, 4,000+ with the hand.
async function handPixels(page, k) {
  const png = await page.screenshot({ clip: { x: k.x - 60, y: k.y - 40, width: 160, height: 170 } });
  if (process.env.WINDUP_HINT_DEBUG) fs.writeFileSync(path.join(process.env.WINDUP_HINT_DEBUG, `clip_${Date.now()}.png`), png);
  return page.evaluate(async (b64) => {
    const img = new Image();
    img.src = 'data:image/png;base64,' + b64;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const g = c.getContext('2d');
    g.drawImage(img, 0, 0);
    const d = g.getImageData(0, 0, c.width, c.height).data;
    let n = 0;
    for (let i = 0; i < d.length; i += 4) {
      const lo = Math.min(d[i], d[i + 1], d[i + 2]), hi = Math.max(d[i], d[i + 1], d[i + 2]);
      if (lo > 170 && hi - lo < 45) n++;
    }
    return n;
  }, png.toString('base64'));
}

test('a slow clicker is shown a long press on the key', async ({ page }, info) => {
  test.skip(info.project.name !== 'desktop', 'one window size is enough for the hint');
  test.setTimeout(120_000);
  const { errors } = await openGame(page, '?fresh=1');
  const k = await keyPoint(page);
  const before = await handPixels(page, k);
  // The hint is asked through the game's own record (works on older builds too,
  // so this spec can be run against the 0.8.0 hint to see it fail).
  const shown = async () => (await events(page)).some((e) => e.ev === 'hint' && e.reason === 'hold');
  for (let i = 0; i < 12 && !(await shown()); i++) {
    await page.mouse.click(k.x, k.y);
    await page.waitForTimeout(2000);
  }
  await expect.poll(shown, { timeout: 10_000 }).toBe(true);
  // Over one 3 s cycle the hand is down (bright) for most frames.
  let most = 0;
  for (let i = 0; i < 6; i++) { most = Math.max(most, await handPixels(page, k)); await page.waitForTimeout(500); }
  expect(most, `hand pixels before ${before}, with the hint ${most}`).toBeGreaterThan(before + 1500);
  const budget = await withinBudget(page);
  expect(budget.ok, JSON.stringify(budget)).toBe(true);
  const ev = await events(page);
  const hint = ev.find((e) => e.ev === 'hint' && e.reason === 'hold');
  const first = ev.find((e) => e.ev === 'wind');
  expect(hint.t - first.t).toBeGreaterThanOrEqual(20);
  if (process.env.WINDUP_EVIDENCE) {
    const dir = path.join(path.dirname(new URL(import.meta.url).pathname), '../../../evidence', process.env.WINDUP_EVIDENCE_STEP || 'step10');
    fs.mkdirSync(dir, { recursive: true });
    await page.screenshot({ path: path.join(dir, `hold_hint_${(await state(page)).build_id}.png`) });
  }
  // Holding the key clears it.
  await page.mouse.move(k.x, k.y);
  await page.mouse.down();
  await page.waitForTimeout(1200);
  await page.mouse.up();
  await expect.poll(async () => (await state(page)).hold_hint).toBe(false);
  expect(errors, errors.join('\n')).toEqual([]);
});
