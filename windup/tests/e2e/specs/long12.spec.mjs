// Step 12 release-candidate check: ten real minutes of the candidate (the
// default variant, C) in a browser from a fresh start, played the way a casual
// player does (a click every ~0.7 s with pauses, a few short holds). Every
// minute: the render budget, memory and node counts, the number on screen
// against the energy, and a picture. Passes when nothing grows without bound,
// nothing errors, the dolls keep waking through the ten minutes and the game
// is not over before minute ten.
// Evidence (WINDUP_EVIDENCE=1): windup/evidence/<WINDUP_EVIDENCE_STEP or step12>/long/.
import { test, expect } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { openGame, state, call, events, keyPoint, withinBudget } from '../lib/game.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const evidence = process.env.WINDUP_EVIDENCE
  ? path.resolve(here, '../../../evidence/' + (process.env.WINDUP_EVIDENCE_STEP || 'step12') + '/long')
  : path.resolve(here, '../test-results/evidence/step12/long');

test('ten minutes of the candidate: steady, still waking, not over early', async ({ page }, info) => {
  test.skip(info.project.name !== 'desktop', 'one long run is enough');
  test.setTimeout(16 * 60_000);
  fs.mkdirSync(evidence, { recursive: true });
  const { errors } = await openGame(page, '?fresh=1');
  const k = await keyPoint(page);
  const s0 = await state(page);
  expect(s0.build_id.endsWith('+c'), s0.build_id).toBe(true);
  const minutes = [];
  const t0 = Date.now();
  let n = 0;
  for (let minute = 1; minute <= 10; minute++) {
    const end = t0 + minute * 60_000;
    while (Date.now() < end) {
      n++;
      if (n % 40 === 0) {                       // now and then a short hold
        await page.mouse.move(k.x, k.y);
        await page.mouse.down();
        await page.waitForTimeout(1500);
        await page.mouse.up();
      } else if (n % 25 === 0) {
        await page.waitForTimeout(4000);        // a pause to watch
      } else {
        await page.mouse.click(k.x, k.y);
        await page.waitForTimeout(550 + (n * 37) % 300);
      }
    }
    const s = await state(page);
    const mem = await call(page, 'dev_memory');
    const budget = await withinBudget(page);
    const row = { minute, game_t: +s.t.toFixed(1), awake: s.awake, energy: Math.round(s.energy), shown: Math.round(s.counter_shown),
      rate: +s.rate.toFixed(2), draw_calls: budget.draw_calls, objects: budget.objects, nodes: mem.nodes, mem_objects: mem.objects,
      static_mb: +(mem.static_bytes / 1048576).toFixed(1), texture_mb: +(mem.texture_bytes / 1048576).toFixed(1) };
    minutes.push(row);
    await page.screenshot({ path: path.join(evidence, `minute_${String(minute).padStart(2, '0')}.png`) });
    console.log(JSON.stringify(row));
    expect(budget.ok, JSON.stringify(budget)).toBe(true);
  }
  const ev = await events(page);
  fs.writeFileSync(path.join(evidence, 'minutes.json'), JSON.stringify(minutes, null, 1) + '\n');
  fs.writeFileSync(path.join(evidence, 'events.jsonl'), ev.map((e) => JSON.stringify(e)).join('\n') + '\n');
  const wakes = ev.filter((e) => e.ev === 'doll_awake').map((e) => e.t);
  // Still waking late in the run, and not all twelve before minute ten (the MVP does not end early).
  expect(wakes.filter((t) => t > 300).length, `wakes ${wakes.map((t) => t.toFixed(0)).join(' ')}`).toBeGreaterThan(0);
  expect(minutes[minutes.length - 1].awake).toBeLessThan(12);
  // Nothing grows without bound: nodes and objects at minute 10 within 15% of minute 2.
  const m2 = minutes[1], m10 = minutes[9];
  expect(m10.nodes, JSON.stringify([m2, m10])).toBeLessThanOrEqual(Math.ceil(m2.nodes * 1.15));
  expect(m10.mem_objects, JSON.stringify([m2, m10])).toBeLessThanOrEqual(Math.ceil(m2.mem_objects * 1.15));
  // The number on screen agrees with the energy once no price is on its way.
  await expect.poll(async () => (await state(page)).spends_in_flight, { timeout: 10_000 }).toBe(0);
  const last = await state(page);
  expect(Math.abs(last.counter_shown - last.energy), JSON.stringify(last)).toBeLessThan(0.01);
  expect(errors, errors.join('\n')).toEqual([]);
});
