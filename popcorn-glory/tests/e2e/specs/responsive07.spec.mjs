// Step 07: the responsive matrix -- 720x1280, 1920x1080, a small 360x640 phone
// at DPR 3, a tablet, a landscape phone -- for each experiment: every control
// inside the window, no two controls overlapping, the money large enough to
// read, a play area that is most of the screen; and the reduced-motion,
// sound-off mode. Runs only on the m-* projects (playwright.config.mjs).
import { test, expect } from '../lib/pop.mjs';

const CONTROLS = ['back', 'sound', 'restart', 'money', 'upgrade'];
const overlap = (a, b) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];

for (const id of ['click', 'perfect', 'explosion']) {
  test(`${id}: fits, no overlaps, readable`, async ({ pop }) => {
    await pop.open(`./#${id}`);
    await pop.tap('play');
    await pop.page.waitForTimeout(400);
    const s = await pop.state();
    const [w, h] = s.window;
    const box = await pop.canvas.boundingBox();
    const css = box.width / w;            // window pixels -> CSS pixels
    for (const name of [...CONTROLS, 'play']) {
      const r = s.rects[name];
      expect(r[0], `${name} left edge inside`).toBeGreaterThanOrEqual(-1);
      expect(r[1], `${name} top edge inside`).toBeGreaterThanOrEqual(-1);
      expect(r[0] + r[2], `${name} right edge inside ${w}`).toBeLessThanOrEqual(w + 1);
      expect(r[1] + r[3], `${name} bottom edge inside ${h}`).toBeLessThanOrEqual(h + 1);
    }
    for (let i = 0; i < CONTROLS.length; i++) for (let j = i + 1; j < CONTROLS.length; j++) {
      expect(overlap(s.rects[CONTROLS[i]], s.rects[CONTROLS[j]]), `${CONTROLS[i]} and ${CONTROLS[j]} do not overlap`).toBe(false);
    }
    const moneyCss = s.rects.money[3] * css;
    const buttonCss = Math.min(s.rects.back[2], s.rects.back[3]) * css;
    test.info().annotations.push({ type: 'sizes', description: `money ${moneyCss.toFixed(0)} px tall, icon buttons ${buttonCss.toFixed(0)} px, upgrade ${(s.rects.upgrade[2] * css).toFixed(0)}x${(s.rects.upgrade[3] * css).toFixed(0)} px (CSS)` });
    expect(moneyCss, 'the money is at least 24 CSS px tall').toBeGreaterThanOrEqual(24);
    expect(buttonCss, 'icon buttons at least 28 CSS px').toBeGreaterThanOrEqual(28);
    expect(s.rects.play[3] / h, 'the play area is at least 40% of the height').toBeGreaterThanOrEqual(0.4);
    await pop.shot(`responsive_${id}`);
  });
}

test('reduced motion and sound off still play', async ({ pop }) => {
  await pop.open('./?motion=reduce&sound=off#explosion');
  const s0 = await pop.state();
  expect(s0.sound.muted).toBe(true);
  for (let i = 0; i < 8; i++) await pop.tap('play');
  await expect.poll(async () => (await pop.state()).run.money).toBeGreaterThan(0);
  await pop.page.waitForTimeout(300);
  const s = await pop.state();
  expect(s.fx.peak, 'reduced motion draws few pieces').toBeLessThanOrEqual(40);
  await pop.shot('reduced');
});
