// Step 91: experiment D, Harvest Burst, in the real web build. Tile D says
// PLAY and opens it; a press before the field is ripe is refused; three
// minutes of play with a real tap on Harvest All a second after each ripening
// and on Bigger Field whenever it can pay -- every harvest pays exactly its
// payout once and the field starts over; two fingers on Harvest All at once
// pay once; a hidden tab grows nothing; a reload of the direct link starts
// again. FUNLAB_SHOTS=<dir> keeps the field growing, ripe, bursting, mid and late.
import { test, expect } from '../lib/lab.mjs';

test('three minutes of Harvest Burst with real taps', async ({ lab }, info) => {
  await lab.open('./');
  let s = await lab.state();
  expect(s.playable, 'tile D says PLAY').toContain('harvest');
  await lab.tapRect(s.tiles.harvest);
  s = await lab.state();
  expect(s.route).toBe('harvest');
  s = (await lab.call('dev_advance', 7)).state;
  expect(s.host.experiment.button).toBe('growing');
  await lab.shot('harvest91_growing');
  await lab.tapRect(s.host.rects.action);
  s = await lab.state();
  expect(s.host.experiment.coins, 'a press before ripe pays nothing').toBe(0);
  expect(s.host.session.actions_by_kind.button_refused, 'and is recorded').toBe(1);

  let harvests = 0;
  let ripeSeen = false;
  let shotBurst = false;
  let ripeAt = -1;
  const shots = [[95, 'mid'], [176, 'late']];
  while (s.host.session.active_seconds < 180) {
    s = (await lab.call('dev_advance', 0.5)).state;
    const e = s.host.experiment;
    if (e.ripe) {
      if (!ripeSeen) { ripeSeen = true; await lab.page.waitForTimeout(300); await lab.shot('harvest91_ripe'); }
      if (ripeAt < 0) ripeAt = s.host.session.active_seconds;
      if (s.host.session.active_seconds - ripeAt >= 1) {
        const before = e;
        await lab.tapRect(s.host.rects.action);
        s = await lab.state();
        harvests++;
        expect(s.host.experiment.harvests, 'one tap, one harvest').toBe(before.harvests + 1);
        expect(s.host.experiment.coins, `harvest ${harvests} pays its payout once`).toBe(before.coins + before.payout);
        expect(s.host.experiment.ripe, 'and starts over').toBe(false);
        if (!shotBurst) { shotBurst = true; await lab.page.waitForTimeout(250); await lab.shot('harvest91_burst'); s = await lab.state(); }
        ripeAt = -1;
      }
    } else if (e.button === 'upgrade') {
      const before = e;
      await lab.tapRect(s.host.rects.action);
      s = await lab.state();
      expect(s.host.experiment.level, 'one tap, one Bigger Field').toBe(before.level + 1);
    }
    if (shots.length && s.host.session.active_seconds >= shots[0][0]) {
      const [, label] = shots.shift();
      await lab.shot(`harvest91_${label}`);
    }
  }
  const sum = s.host.session;
  const pays = sum.milestones.filter((m) => m.name === 'harvest');
  console.log(`harvest91 ${info.project.name}: ${pays.length} harvests (${pays.map((p) => `${p.coins}@${p.t_s}`).join(', ')}), field ${s.host.experiment.level}, upgrades ${sum.upgrades.length}, waited ripe ${sum.metrics.ready_wait_s}s, early presses ${sum.metrics.early_presses}`);
  expect(pays.length, 'many harvests').toBeGreaterThanOrEqual(10);
  expect(pays[0].t_s, 'the first harvest within 15-30 s').toBeLessThanOrEqual(30);
  expect(pays[2].coins, 'the third pays at least twice the first').toBeGreaterThanOrEqual(2 * pays[0].coins);
  expect(sum.upgrades.length, 'several upgrades').toBeGreaterThanOrEqual(5);
});

test('two fingers on Harvest All pay once; a hidden tab grows nothing; a reload starts again', async ({ lab }, info) => {
  await lab.open('./#harvest');
  let s = (await lab.call('dev_advance', 14.5)).state;
  expect(s.host.experiment.ripe).toBe(true);
  const box = await lab.canvas.boundingBox();
  const k = box.width / s.window[0];
  const r = s.host.rects.action;
  const x = box.x + (r[0] + r[2] / 2) * k;
  const y = box.y + (r[1] + r[3] / 2) * k;
  if (info.project.use.hasTouch) {
    const cdp = await lab.page.context().newCDPSession(lab.page);
    const pts = [{ x: x - 20, y, id: 1 }, { x: x + 20, y, id: 2 }];
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: pts });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  } else {
    await lab.page.mouse.dblclick(x, y);
  }
  await lab.page.waitForTimeout(400);
  s = await lab.state();
  expect(s.host.experiment.harvests, 'one harvest').toBe(1);
  expect(s.host.experiment.coins, 'one payout').toBe(16);
  await lab.tab(true);
  const p = (await lab.state()).host.experiment.progress;
  await lab.page.waitForTimeout(2500);
  expect((await lab.state()).host.experiment.progress, 'no growth while hidden').toBe(p);
  await lab.tab(false);
  await lab.page.reload();
  await lab.ready();
  s = await lab.state();
  expect(s.route).toBe('harvest');
  expect(s.host.experiment.harvests, 'a fresh field').toBe(0);
});
