// Step 03: the web build draws the art (not the fallback), the doll wakes up
// in the browser, and the frame rate holds. Numbers and pictures go to
// windup/evidence/step03/ (browser_<project>.json, web_*.png).
import { test, expect } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import { openGame, state, call, paintedColours, withinBudget } from '../lib/game.mjs';

// Pictures and numbers go to windup/evidence/ only when asked (WINDUP_EVIDENCE=1), so
// a routine run cannot overwrite an earlier step's published-build evidence.
const evidence = process.env.WINDUP_EVIDENCE
  ? path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../evidence/' + (process.env.WINDUP_EVIDENCE_STEP || 'step03'))
  : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../test-results/evidence/step03');

test('art loads, the doll wakes, frames hold', async ({ page }, info) => {
  const { errors } = await openGame(page, '?fresh=1');
  const s0 = await state(page);
  expect(s0.art).toBe(true);
  expect(s0.doll).toBe('asleep');
  expect(await paintedColours(page)).toBeGreaterThan(40);   // a picture, not a few flat fills
  fs.mkdirSync(evidence, { recursive: true });
  await page.screenshot({ path: path.join(evidence, `web_asleep_${info.project.name}.png`) });

  expect((await call(page, 'dev_wake')).ok).toBe(true);
  await expect.poll(async () => (await state(page)).doll, { timeout: 10_000 }).toBe('stand');
  await page.screenshot({ path: path.join(evidence, `web_awake_${info.project.name}.png`) });

  const fps = [];
  for (let i = 0; i < 10; i++) { await page.waitForTimeout(1000); fps.push((await state(page)).fps); }
  const pack = await page.evaluate(async () => {
    const v = await (await fetch('version.json', { cache: 'no-store' })).json();
    return v;
  });
  fs.writeFileSync(path.join(evidence, `browser_${info.project.name}.json`),
    JSON.stringify({ project: info.project.name, version: s0.version, fps, pack }, null, 2) + '\n');
  // Render budget, not frames a second (see play04.spec.mjs); fps kept as evidence with a floor.
  const budget = await withinBudget(page);
  expect(budget.ok, JSON.stringify(budget)).toBe(true);
  // Only "not stalled": this shared machine runs at load 30-60 from other sessions,
  // where a phone-sized canvas at 2x drew 6 fps for reasons outside the game.
  expect(Math.min(...fps.slice(2))).toBeGreaterThanOrEqual(3);
  expect(errors).toEqual([]);
});
