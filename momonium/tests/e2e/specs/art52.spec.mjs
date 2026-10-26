// Step 52: the concept-faithful art in the real web build -- a panel you read
// is frosted white glass (WebGL pixels, not only the theme), a farm's job
// cards are the concept's cream / sky / butter cards, and at night a house's
// panes glow warm on the screen where they are painted.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng, pixel } from '../lib/png.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

// Share of sampled pixels in a window-pixel rect that pass `keep`.
function share(png, rect, scale, keep) {
  let n = 0;
  let hit = 0;
  for (let y = rect[1] + rect[3] * 0.1; y < rect[1] + rect[3] * 0.9; y += 4) {
    for (let x = rect[0] + rect[2] * 0.1; x < rect[0] + rect[2] * 0.9; x += 4) {
      n += 1;
      if (keep(pixel(png, x * scale.x, y * scale.y))) hit += 1;
    }
  }
  return hit / Math.max(n, 1);
}

async function shot(game) {
  const png = decodePng(await game.canvas.screenshot());
  const win = (await game.query('selection')).window;
  return { png, scale: { x: png.width / win[0], y: png.height / win[1] } };
}

test('white glass panels and pastel job cards', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_advance_to', [1, 0.3]);
  const hud = await game.query('hud');
  const box = await game.canvas.boundingBox();
  const s = hud.buttons.status;
  await game.tap((s[0] + s[2] / 2) * (box.width / hud.window[0]), (s[1] + s[3] / 2) * (box.height / hud.window[1]));
  await game.page.waitForTimeout(400);
  const card = (await game.query('art_info')).status_card;
  expect(card.length, 'Status opened by a tap').toBe(4);
  let { png, scale } = await shot(game);
  const light = share(png, card, scale, ([r, g, b]) => r > 200 && g > 205 && b > 210);
  expect(light, `the card is light glass (${(light * 100).toFixed(0)}% light pixels)`).toBeGreaterThan(0.55);
  await game.tap((s[0] + s[2] / 2) * (box.width / hud.window[0]), (s[1] + s[3] / 2) * (box.height / hud.window[1]));
  await game.page.waitForTimeout(300);
  // A farm, selected by a real tap: three cards, cream / sky / butter.
  await game.query('dev_place_building', ['farm', 1, 0]);
  const p = await clearPointOnCell(game, [1, 0]);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(400);
  const sel = await game.query('selection');
  expect(sel.cards.length).toBe(3);
  ({ png, scale } = await shot(game));
  const tints = [[253, 240, 220], [220, 241, 252], [255, 240, 191]];
  sel.cards.forEach((r, i) => {
    const [tr, tg, tb] = tints[i];
    // The lit card is full colour; the others are dimmed over the sea, so
    // only the first is matched to its exact tint, all of them to "pastel".
    const near = share(png, r, scale, ([pr, pg, pb]) => Math.abs(pr - tr) + Math.abs(pg - tg) + Math.abs(pb - tb) < 40);
    const pale = share(png, r, scale, ([pr, pg, pb]) => pr > 150 && pg > 150 && pb > 140);
    if (i === 0) expect(near, `card ${i} is its pastel (${(near * 100).toFixed(0)}%)`).toBeGreaterThan(0.3);
    expect(pale, `card ${i} is a pale card (${(pale * 100).toFixed(0)}%)`).toBeGreaterThan(0.4);
  });
});

test('house windows glow warm at night', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_grow_island', 3);
  const { id } = await game.query('dev_place_building', ['office', 1, 1]);
  const today = (await game.state()).day ?? 1;
  await game.query('dev_advance_to', [today, 0.3]);
  await game.page.waitForTimeout(300);
  let lit = (await game.query('art_info')).lit.find((l) => l[0] === id);
  expect(lit, 'the office has lit windows').toBeTruthy();
  expect(lit[1], 'not by day').toBe(false);
  await game.query('dev_advance_to', [today, 0.84]);
  await game.page.waitForTimeout(400);
  expect((await game.query('vfx')).phase).toBe('night');
  lit = (await game.query('art_info')).lit.find((l) => l[0] === id);
  expect(lit[1], 'lit at night').toBe(true);
  // Under the night tint everything is dim or blue; only a lit pane is both
  // bright and warm. WebGL pixels where the drawing says the panes are.
  const { png, scale } = await shot(game);
  const glow = share(png, lit[2], scale, ([r, g, b]) => r > 160 && g > 90 && r - b > 70);
  expect(glow, `warm, bright panes at night (${(glow * 100).toFixed(1)}% of the windows' box)`).toBeGreaterThan(0.03);
});
