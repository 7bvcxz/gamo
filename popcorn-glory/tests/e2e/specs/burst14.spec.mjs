// Step 14: the crescendo (?burst=1) in a real browser with real input -- touch on the touch
// projects, the mouse on desktop. The single B action still does everything: perfect pops
// fill the crescendo, and the pop that fills it is a burst worth 1.5x (money checked from the
// state, not from a log). (That no burst piece covers the gold is a render check:
// tools/check_gold_on_top.gd -- sampled browser frames could not tell, the pieces rarely reach
// the arc.) On desktop, the fountain (level 11) is heard and does not clip.
// Without ?burst=1 the stand is the stand: no crescendo, no bursts.
import { test, expect } from '../lib/pop.mjs';
import { AUDIO_TAP, listen } from '../lib/audio_tap.mjs';

test('burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst', async ({ pop }, testInfo) => {
  test.setTimeout(150_000);
  await pop.open('./?burst=1#stand');
  let s = await pop.state();
  expect(s.run.burst_mode, 'the mode is on').toBe(true);
  expect(s.rects.gold_mid, 'the gold arc is exposed for the check').toBeTruthy();
  let burstSeen = false;
  for (let i = 0; i < 12 && !burstSeen; i++) {
    const r0 = (await pop.state()).run;
    await pop.holdGold();
    await expect.poll(async () => (await pop.state()).run.presses).toBe(r0.presses + 1);
    await expect.poll(async () => (await pop.state()).run.heating).toBe(false);
    const r1 = (await pop.state()).run;
    const perfect = r1.outcomes.perfect - r0.outcomes.perfect, near = r1.outcomes.near - r0.outcomes.near;
    if (r1.bursts > r0.bursts) {
      burstSeen = true;
      await pop.shot('burst14_burst');
      const base = perfect ? 10 : 5;             // level 0: a perfect batch pays 10, a near one 5
      expect(r1.money - r0.money, `the burst pays floor(${base} x 1.5)`).toBe(Math.floor(base * 1.5));
      expect(r1.crescendo, 'the meter empties').toBe(0);
    } else {
      const add = perfect ? 2 : near ? 1 : 0;
      expect(r1.crescendo, `the meter after a ${perfect ? 'perfect' : near ? 'near' : 'miss'}`).toBe(r0.crescendo + add);
    }
    await pop.page.waitForTimeout(500);
  }
  expect(burstSeen, 'a burst within twelve holds').toBe(true);
  expect(pop.errors).toEqual([]);
});

test('without ?burst=1 the stand has no crescendo', async ({ pop }) => {
  await pop.open('./#stand');
  for (let i = 0; i < 4; i++) { await pop.holdGold(); await pop.page.waitForTimeout(500); }
  const s = await pop.state();
  expect(s.run.burst_mode).toBe(false);
  expect(s.run.crescendo).toBe(0);
  expect(s.run.bursts).toBe(0);
  expect(s.rects.gold_mid, 'no meter, no check rect').toBeUndefined();
});

test('the fountain is heard and does not clip', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop measures the sound');
  test.setTimeout(150_000);
  await pop.page.addInitScript(AUDIO_TAP);
  await pop.open('./?burst=1#stand');
  await pop.tap('play');
  await pop.page.waitForTimeout(1500);
  await pop.call('dev_level', 11);
  let worst = { rms: 0, peak: 0 };
  let bursts = 0;
  for (let i = 0; i < 10 && bursts === 0; i++) {
    const heard = await listen(pop.page);
    await pop.holdGold();
    const m = await heard(1600);
    worst = { rms: Math.max(worst.rms, m.rms), peak: Math.max(worst.peak, m.peak) };
    bursts = (await pop.state()).run.bursts;
  }
  expect(bursts, 'a fountain burst').toBeGreaterThan(0);
  expect((await pop.state()).run.burst_tier, 'level 11 = the fountain').toBe(2);
  testInfo.annotations.push({ type: 'mix', description: `fountain rms ${worst.rms.toFixed(3)} peak ${worst.peak.toFixed(3)}` });
  expect(worst.rms, 'heard').toBeGreaterThan(0.01);
  expect(worst.peak, `no clipping (peak ${worst.peak.toFixed(3)})`).toBeLessThan(1.0);
  expect(pop.errors).toEqual([]);
});
