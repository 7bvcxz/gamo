// Step 07: one finger pans, two fingers pinch-zoom on phones; wheel zooms and
// drag pans on desktop; the island cannot be flung out of reach.
import { test, expect } from '../lib/fixtures.mjs';
import { touchDrag, pinch } from '../lib/touch.mjs';

test('phone: drag pans and pinch zooms', async ({ game }, info) => {
  test.skip(!info.project.use.hasTouch, 'touch only');
  const box = await game.canvas.boundingBox();
  const c0 = await game.query('camera');
  await touchDrag(game.page, { x: box.width * 0.5, y: box.height * 0.8 }, { x: box.width * 0.3, y: box.height * 0.8 });
  const c1 = await game.query('camera');
  expect(c1.x).toBeGreaterThan(c0.x + 5);
  expect(c1.zoom).toBeCloseTo(c0.zoom, 5);
  await pinch(game.page, { x: box.width * 0.5, y: box.height * 0.7 }, 80, 220);
  const c2 = await game.query('camera');
  expect(c2.zoom).toBeGreaterThan(c1.zoom * 1.3);
});

test('desktop: wheel zooms, drag pans', async ({ game }, info) => {
  test.skip(info.project.use.hasTouch, 'mouse only');
  const box = await game.canvas.boundingBox();
  const c0 = await game.query('camera');
  await game.page.mouse.move(box.width * 0.5, box.height * 0.7);
  await game.page.mouse.wheel(0, -300);
  await expect.poll(async () => (await game.query('camera')).zoom).toBeGreaterThan(c0.zoom);
  const c1 = await game.query('camera');
  await game.page.mouse.move(box.width * 0.5, box.height * 0.75);
  await game.page.mouse.down();
  await game.page.mouse.move(box.width * 0.35, box.height * 0.75, { steps: 8 });
  await game.page.mouse.up();
  const c2 = await game.query('camera');
  expect(c2.x).toBeGreaterThan(c1.x + 5);
});

test('zoom and pan stay within limits', async ({ game }, info) => {
  const box = await game.canvas.boundingBox();
  if (info.project.use.hasTouch) {
    for (let i = 0; i < 3; i++) await pinch(game.page, { x: box.width / 2, y: box.height * 0.7 }, 300, 40, 6);
  } else {
    await game.page.mouse.move(box.width / 2, box.height * 0.7);
    for (let i = 0; i < 12; i++) await game.page.mouse.wheel(0, 400);
  }
  const c = await game.query('camera');
  expect(c.zoom).toBeGreaterThanOrEqual(c.min - 1e-6);
  expect(c.zoom).toBeLessThan(c.fit);
});
