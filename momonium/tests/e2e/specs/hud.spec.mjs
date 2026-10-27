// Step 10: the corner HUD shows the simulation's numbers, its buttons take
// real taps/clicks without moving the camera, it relabels when the language
// changes, and it fits a small phone without overlaps.
import { test, expect } from '../lib/fixtures.mjs';

const toCss = async (game, rect, info) => {
  const box = await game.canvas.boundingBox();
  const sx = box.width / info.window[0];
  const sy = box.height / info.window[1];
  return { x: (rect[0] + rect[2] / 2) * sx, y: (rect[1] + rect[3] / 2) * sy, w: rect[2] * sx, h: rect[3] * sy, left: rect[0] * sx, top: rect[1] * sy };
};

test('shows Day, money and exact EXP', async ({ game }) => {
  await game.query('set_language', 'en');
  await game.page.waitForTimeout(150);
  const info = await game.query('hud');
  expect(info.day).toBe('Day 1');
  expect(info.money).toBe('10');
  expect(info.exp).toBe(`0 / ${(await game.query('rules')).exp_to_next[0]}`);
  expect(info.seconds).toMatch(/^\d\d \/ 30 sec$/);
});

test('corner buttons take a real tap and leave the camera alone', async ({ game }) => {
  const before = await game.query('camera');
  for (const name of ['research', 'status', 'hire', 'shop']) {
    const info = await game.query('hud');
    const p = await toCss(game, info.buttons[name], info);
    await game.tap(p.x, p.y);
    await game.page.waitForTimeout(120);
  }
  const after = await game.query('hud');
  expect(after.actions.slice(-4)).toEqual(['research', 'status', 'hire', 'shop']);
  const cam = await game.query('camera');
  expect(cam.x).toBeCloseTo(before.x, 3);
  expect(cam.y).toBeCloseTo(before.y, 3);
});

test('relabels in Korean, Japanese and Chinese', async ({ game }) => {
  for (const [code, research, day] of [['ko', '연구', 'Day 1'], ['ja', '研究', 'Day 1'], ['zh_CN', '研究', '第 1 天']]) {
    await game.query('set_language', code);
    await game.page.waitForTimeout(150);
    const info = await game.query('hud');
    expect(info.locale).toBe(code);
    expect(info.labels).toContain(research);
    expect(info.day).toBe(day);
  }
  await game.query('set_language', 'en');
});

test('fits a small phone without overlaps', async ({ game }, info) => {
  test.skip(!info.project.use.hasTouch, 'phone layout');
  await game.page.setViewportSize({ width: 320, height: 568 });
  await game.page.waitForTimeout(500);
  const hud = await game.query('hud');
  const box = await game.canvas.boundingBox();
  const rects = await Promise.all(Object.values(hud.buttons).map((r) => toCss(game, r, hud)));
  for (const r of rects) {
    expect(r.left).toBeGreaterThanOrEqual(0);
    expect(r.top).toBeGreaterThanOrEqual(0);
    expect(r.left + r.w).toBeLessThanOrEqual(box.width + 0.5);
    expect(r.top + r.h).toBeLessThanOrEqual(box.height + 0.5);
  }
  for (let i = 0; i < rects.length; i++) {
    for (let j = i + 1; j < rects.length; j++) {
      const a = rects[i], b = rects[j];
      const overlap = a.left < b.left + b.w && b.left < a.left + a.w && a.top < b.top + b.h && b.top < a.top + a.h;
      expect(overlap, `buttons ${i} and ${j} overlap`).toBe(false);
    }
  }
});
