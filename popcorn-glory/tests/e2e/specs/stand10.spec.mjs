// Step 10: the Popcorn Stand in a real browser with real input (touch on the touch
// projects, the mouse on desktop). The first moment is B's hold and release; from its level
// a side-to-side drag while holding shakes (three swings = an even pop); a shaker tap chooses
// a recipe without pressing the machine; the automation card buys the motor and then the
// helper, which pays by itself. Later moments are set up with the dev hooks (level, money) --
// a picture of a later stand, not a play.
import { test, expect } from '../lib/pop.mjs';

async function point(pop, name, fx = 0.5, fy = 0.5) {
  const s = await pop.state();
  const r = s.rects[name];
  const box = await pop.canvas.boundingBox();
  const k = box.width / s.window[0];
  return [box.x + (r[0] + r[2] * fx) * k, box.y + (r[1] + r[3] * fy) * k, k];
}

test('the stand: B first, shake by dragging, a shaker chooses, the card buys the machines', async ({ pop }, testInfo) => {
  test.setTimeout(120_000);
  const touch = testInfo.project.use.hasTouch;
  await pop.open('./#stand');
  let s = await pop.state();
  expect(s.exp).toBe('stand');
  expect(s.rects.auto, 'no automation card at level 0').toBeUndefined();
  expect(s.rects.recipe_butter, 'no shakers at level 0').toBeUndefined();

  // 1. B's hold and release.
  await pop.holdGold();
  await expect.poll(async () => (await pop.state()).run.outcomes.perfect, { message: 'into the gold' }).toBe(1);
  expect((await pop.state()).run.money).toBe(10);
  await pop.page.waitForTimeout(600);

  // 2. Shake (level 3): hold, swing the finger side to side three times, let go.
  await pop.call('dev_level', 3);
  const [x, y, k] = await point(pop, 'play', 0.5, 0.6);
  const swing = 70 * k;
  const cdp = touch ? await pop.cdp() : null;
  const down = () => (touch ? cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] }) : pop.page.mouse.move(x, y).then(() => pop.page.mouse.down()));
  const move = (mx) => (touch ? cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: mx, y }] }) : pop.page.mouse.move(mx, y, { steps: 4 }));
  const up = () => (touch ? cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }) : pop.page.mouse.up());
  await down();
  await pop.page.waitForTimeout(150);
  for (const dx of [swing, -swing, swing]) { await move(x + dx); await pop.page.waitForTimeout(120); }
  await expect.poll(async () => (await pop.state()).run.shakes, { message: 'three swings, three shakes' }).toBe(3);
  await pop.page.waitForTimeout(700);
  await up();
  await expect.poll(async () => (await pop.state()).run.even_pops, { message: 'an even pop' }).toBe(1);
  await pop.shot('stand_shaken');
  await pop.page.waitForTimeout(600);

  // 3. A recipe (level 5): tap the cheese shaker.
  await pop.call('dev_level', 5);
  await expect.poll(async () => !!(await pop.state()).rects.recipe_cheese).toBe(true);
  const presses = (await pop.state()).run.presses;
  await pop.tap('recipe_cheese');
  await expect.poll(async () => (await pop.state()).run.recipe, { message: 'cheese chosen' }).toBe('cheese');
  expect((await pop.state()).run.presses, 'a shaker tap is not a press').toBe(presses);

  // 4. Automation: the card buys the motor, then the helper, which pops by itself.
  await pop.call('dev_money', 100000);
  await expect.poll(async () => !!(await pop.state()).rects.auto).toBe(true);
  await pop.tap('auto');
  await expect.poll(async () => (await pop.state()).run.motor, { message: 'the motor' }).toBe(true);
  await pop.page.waitForTimeout(300);
  await pop.tap('auto');
  await expect.poll(async () => (await pop.state()).run.helper_level, { message: 'the helper' }).toBe(1);
  await expect.poll(async () => (await pop.state()).run.helper_batches, { message: 'the helper pops by itself', timeout: 20_000 }).toBeGreaterThanOrEqual(1);
  await pop.shot('stand_helper');
  expect(pop.errors).toEqual([]);
});

test('the stand fits: shakers, helper, card and machine do not overlap the bars', async ({ pop }) => {
  await pop.open('./#stand');
  await pop.call('dev_level', 9);
  await pop.call('dev_money', 1000000);
  await pop.tap('auto');
  await pop.page.waitForTimeout(200);
  await pop.tap('auto');
  await expect.poll(async () => !!(await pop.state()).rects.helper).toBe(true);
  const r = (await pop.state()).rects;
  const inside = (a, b) => a[0] >= b[0] - 1 && a[1] >= b[1] - 1 && a[0] + a[2] <= b[0] + b[2] + 1 && a[1] + a[3] <= b[1] + b[3] + 1;
  const apart = (a, b) => a[0] + a[2] <= b[0] || b[0] + b[2] <= a[0] || a[1] + a[3] <= b[1] || b[1] + b[3] <= a[1];
  for (const key of ['recipe_butter', 'recipe_caramel', 'recipe_cheese', 'helper']) {
    expect(inside(r[key], r.play), `${key} inside the play area`).toBe(true);
    expect(apart(r[key], r.auto), `${key} clear of the card`).toBe(true);
  }
  expect(apart(r.auto, r.upgrade), 'the two cards apart').toBe(true);
  await pop.shot('stand_fits');
  expect(pop.errors).toEqual([]);
});
