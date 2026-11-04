// Step 10: the stand played for a long session in a real browser with real input (the slow
// test, one project:  POPCORN_STAND_MIN=12 popcorn-glory/tools/e2e.sh specs/play_stand.spec.mjs --project p720).
// A scripted player -- not a person, not fun -- holds early into the gold (pop.holdGold's
// aim), swings the finger three times while holding once shaking unlocks (until the motor
// does it), picks caramel once recipes unlock, and buys whichever of the two cards is cheaper
// when it can. It records the state every minute and screenshots at 0, 3 and 10 minutes and
// at the end, so the 10-20 minute shape of the slice can be seen and checked: everything
// unlocks, the helper earns by itself, nothing locks up, no page error.
import { test, expect } from '../lib/pop.mjs';
import fs from 'node:fs';
import os from 'node:os';

const MIN = Number(process.env.POPCORN_STAND_MIN || 12);
const OUT = process.env.POPCORN_PLAY_OUT;

test(`stand: ${MIN} real minutes`, async ({ pop }, testInfo) => {
  test.setTimeout((MIN * 60 + 240) * 1000);
  const touch = testInfo.project.use.hasTouch;
  await pop.open('./#stand');
  const cdp = touch ? await pop.cdp() : null;
  const t0 = Date.now();
  const minutes = [];
  const shots = new Set();
  let buys = 0;
  let shakesSent = 0;
  const snap = async (label) => {
    if (shots.has(label)) return;
    shots.add(label);
    await pop.shot(`stand_${label}`);
  };
  await snap('0min');
  while (true) {
    const s = await pop.state();
    const run = s.run;
    const mins = s.clock_ms / 60000;
    if (minutes.length < Math.floor(mins)) {
      minutes.push({ minute: Math.floor(mins), level: run.level, auto: run.auto_level, money: run.money, earned: run.earned,
        manual: run.manual_earned, helper: run.helper_earned, recipe: run.recipe, even_pops: run.even_pops, outcomes: run.outcomes, load: os.loadavg()[0] });
    }
    if (mins >= 3) await snap('3min');
    if (mins >= 10) await snap('10min');
    if (s.clock_ms >= MIN * 60000) break;
    if (Date.now() - t0 > (MIN * 60 + 200) * 1000) throw new Error(`play clock only at ${s.clock_ms} ms`);
    // The recipe, once.
    if (run.unlocked.recipes && run.recipe !== 'caramel' && !run.heating) { await pop.tap('recipe_caramel'); continue; }
    // Buying: the cheaper of the two cards, when affordable.
    const main = run.cost; const auto = run.unlocked.auto ? run.auto_cost : -1;
    const pick = main >= 0 && (auto < 0 || main <= auto) ? ['upgrade', main] : (auto >= 0 ? ['auto', auto] : null);
    if (pick && run.money >= pick[1] && !run.heating) { await pop.tap(pick[0]); buys++; await pop.page.waitForTimeout(150); continue; }
    // The hand.
    if (run.heating || run.cooldown_left > 0) { await pop.page.waitForTimeout(60); continue; }
    const w = run.window;
    const hold = Math.round(w[0] + (w[1] - w[0]) * 0.25);
    const r = s.rects.play;
    const box = await pop.canvas.boundingBox();
    const k = box.width / s.window[0];
    const x = box.x + (r[0] + r[2] / 2) * k; const y = box.y + (r[1] + r[3] * 0.6) * k;
    const shake = run.unlocked.shake;   // the hand's shake beats the motor (Step 11)
    const start = Date.now();
    if (touch) await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
    else { await pop.page.mouse.move(x, y); await pop.page.mouse.down(); }
    if (shake) {
      await pop.page.waitForTimeout(150);
      for (const dx of [70, -70, 70]) {
        if (touch) await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x + dx * k, y }] });
        else await pop.page.mouse.move(x + dx * k, y, { steps: 3 });
        shakesSent++;
        await pop.page.waitForTimeout(110);
      }
    }
    await pop.page.waitForTimeout(Math.max(0, hold - (Date.now() - start)));
    if (touch) await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    else await pop.page.mouse.up();
    await pop.page.waitForTimeout(200);
  }
  await snap('end');
  const s = await pop.state();
  const result = { minutes_played: MIN, buys, shakes_sent: shakesSent, final: s.run, per_minute: minutes, summary: await pop.call('summary'), log: await pop.call('log') };
  if (OUT) fs.writeFileSync(`${OUT}/play_stand_${MIN}min_${testInfo.project.name}.json`, JSON.stringify(result, null, 2));
  expect(s.run.unlocked).toEqual({ shake: true, auto: true, recipes: true });
  expect(s.run.motor, 'the motor bought').toBe(true);
  expect(s.run.helper_earned, 'the helper earned by itself').toBeGreaterThan(0);
  expect(s.run.even_pops, 'even pops happened').toBeGreaterThan(0);
  expect(pop.errors).toEqual([]);
});
