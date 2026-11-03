// Step 07: input edge cases on the real build -- a press that slides off a
// button does not buy, a press that starts on the machine and ends on the
// button does not buy, a double click buys once, a cancelled touch never
// locks B, dragging on the canvas never scrolls the page, the keyboard plays.
import { test, expect } from '../lib/pop.mjs';

const centre = async (pop, name) => {
  const s = await pop.state();
  const r = s.rects[name];
  const box = await pop.canvas.boundingBox();
  const k = box.width / s.window[0];
  return [box.x + (r[0] + r[2] / 2) * k, box.y + (r[1] + r[3] / 2) * k];
};

test.describe('mouse', () => {
  test.skip(({ hasTouch }) => hasTouch, 'mouse paths on the desktop project');

  test('slide off the upgrade before letting go: no purchase', async ({ pop }) => {
    await pop.open('./#click');
    await pop.call('dev_level', 0);
    for (let i = 0; i < 30; i++) await pop.tap('play');
    await expect.poll(async () => (await pop.state()).run.money).toBeGreaterThanOrEqual(24);
    const [ux, uy] = await centre(pop, 'upgrade');
    const [px, py] = await centre(pop, 'play');
    await pop.page.mouse.move(ux, uy);
    await pop.page.mouse.down();
    await pop.page.mouse.move(px, py, { steps: 5 });
    await pop.page.mouse.up();
    await pop.page.waitForTimeout(200);
    expect((await pop.state()).run.level, 'no purchase').toBe(0);
    // ...and a press that starts on the machine, ends on the button: no purchase either.
    await pop.page.mouse.move(px, py);
    await pop.page.mouse.down();
    await pop.page.mouse.move(ux, uy, { steps: 5 });
    await pop.page.mouse.up();
    await pop.page.waitForTimeout(200);
    expect((await pop.state()).run.level, 'still no purchase').toBe(0);
  });

  test('a double click buys once', async ({ pop }) => {
    await pop.open('./#click');
    for (let i = 0; i < 30; i++) await pop.tap('play');
    const s = await pop.state();
    expect(s.run.money).toBeLessThan(s.run.cost * 3);   // not enough for a second right after
    const [ux, uy] = await centre(pop, 'upgrade');
    await pop.page.mouse.dblclick(ux, uy);
    await pop.page.waitForTimeout(300);
    expect((await pop.state()).run.level, 'one purchase').toBe(1);
  });

  test('the keyboard plays: space presses, escape goes back', async ({ pop }) => {
    await pop.open('./#perfect');
    await pop.canvas.click();
    await pop.page.waitForTimeout(500);
    const before = (await pop.state()).run.presses;
    await pop.page.keyboard.down('Space');
    await pop.page.waitForTimeout(1625);
    await pop.page.keyboard.up('Space');
    await expect.poll(async () => (await pop.state()).run.presses).toBe(before + 1);
    await pop.page.keyboard.press('Escape');
    await expect.poll(async () => (await pop.state()).screen).toBe('chooser');
  });
});

test.describe('touch', () => {
  test.skip(({ hasTouch }) => !hasTouch, 'touch paths on touch projects');

  test('a cancelled touch never locks B', async ({ pop }) => {
    await pop.open('./#perfect');
    const [px, py] = await centre(pop, 'play');
    const cdp = await pop.cdp();
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: px, y: py }] });
    await pop.page.waitForTimeout(300);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchCancel', touchPoints: [] });
    // Whatever the cancel did, within the burn time the machine is free again.
    await expect.poll(async () => (await pop.state()).run.heating, { timeout: 6000 }).toBe(false);
    await pop.page.waitForTimeout(600);
    await pop.hold('play', 1700);
    await expect.poll(async () => { const o = (await pop.state()).run.outcomes; return o.perfect + o.near; }, { message: 'the next hold works' }).toBeGreaterThanOrEqual(1);
  });

  test('dragging on the game never scrolls the page', async ({ pop }) => {
    await pop.open('./#click');
    const [px, py] = await centre(pop, 'play');
    const cdp = await pop.cdp();
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: px, y: py }] });
    for (let i = 1; i <= 10; i++) await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: px, y: py - i * 30 }] });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await pop.page.waitForTimeout(300);
    const scroll = await pop.page.evaluate(() => [window.scrollX, window.scrollY, document.scrollingElement.scrollTop]);
    expect(scroll, 'no scroll').toEqual([0, 0, 0]);
  });
});
