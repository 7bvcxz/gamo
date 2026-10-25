// Step 04: the exported build carries the sprite atlas, its metadata and pivots.
// Step 46: the painted assets are live in the browser -- props dressing the
// island, the painted cloud band in the sky, and panels clear of the HUD.
import { readFileSync } from 'node:fs';
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

const atlas = JSON.parse(readFileSync(new URL('../../../assets/atlas/sprites.json', import.meta.url), 'utf8'));

test('atlas and pivots load in the browser', async ({ game }) => {
  const info = await game.query('art_info');
  expect(info.sprites).toBe(Object.keys(atlas.sprites).length);
  expect(info.size).toEqual(atlas.size);
  expect(info.texture).toEqual(atlas.size);
  expect(info.momo_origin).toEqual(atlas.sprites.momo_front.pivots.origin);
});

test('painted island, clouds and a clear research card', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_advance_to', [1, 0.3]);
  await game.page.waitForTimeout(300);
  const info = await game.query('art_info');
  expect(info.props, 'the start island is dressed with painted props').toBeGreaterThan(0);
  expect(info.painted_clouds, 'the sky draws the painted cloud band').toBe(true);
  // The cloud band sits in the lower half of the sky (top 2/5 of the screen):
  // a row through it is partly white cloud, partly blue sky.
  const png = decodePng(await game.canvas.screenshot());
  let cloud = 0;
  let blue = 0;
  const y = png.height * 0.34;
  for (let x = png.width * 0.05; x < png.width * 0.6; x += 3) {
    const [r, g, b] = pixel(png, x, y);
    if (r > 215 && g > 215 && b > 215) cloud += 1;
    else if (b > r + 50) blue += 1;
  }
  expect(cloud, `white cloud along the band (${cloud} vs ${blue} blue)`).toBeGreaterThan(5);
  // Research, opened by a real tap: the card leaves the side buttons free.
  const hud = await game.query('hud');
  const box = await game.canvas.boundingBox();
  const r = hud.buttons.research;
  await game.tap((r[0] + r[2] / 2) * (box.width / hud.window[0]), (r[1] + r[3] / 2) * (box.height / hud.window[1]));
  await game.page.waitForTimeout(400);
  const open = await game.query('art_info');
  expect(open.research_card.length).toBe(4);
  expect(open.research_card[0] + open.research_card[2], 'the research card ends left of the side buttons').toBeLessThanOrEqual(hud.window[0] - open.side_reserved + 2);
});
