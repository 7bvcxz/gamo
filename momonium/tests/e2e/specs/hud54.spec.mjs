// Step 54: in the real web build, money and the level lead the HUD -- the EXP
// bar is filled in gold exactly as far as the level is (WebGL pixels), a gain
// pops large at once, and a level gained shows "LEVEL UP!" at the card, once,
// with the level reached. A desktop window gets a larger UI than the design's
// portrait size would give it.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

const gold = ([r, g, b]) => r > 200 && g > 160 && b < 130;

async function shot(game) {
  const png = decodePng(await game.canvas.screenshot());
  const win = (await game.query('hud')).window;
  return { png, sx: png.width / win[0], sy: png.height / win[1] };
}

// Share of gold along the bar's middle row, in its left and right parts.
function goldAlong(s, r, from, to) {
  let n = 0;
  let hit = 0;
  const y = r[1] + r[3] / 2;
  for (let x = r[0] + r[2] * from; x < r[0] + r[2] * to; x += 1) {
    n += 1;
    if (gold(pixel(s.png, x * s.sx, y * s.sy))) hit += 1;
  }
  return hit / Math.max(n, 1);
}

test('a gold bar as far as the level is, and a level-up you cannot miss', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  let h = await game.query('hud');
  expect(h.content_scale, 'a wide window gets a larger UI').toBeCloseTo(info.project.use.hasTouch ? 1.0 : 1.3, 2);
  // Half a level.
  const half = Math.floor((await game.query('dev_add_exp', 0)).next * 0.6);
  await game.query('dev_add_exp', half);
  await game.page.waitForTimeout(700);
  h = await game.query('hud');
  expect(h.exp_bar.value).toBeCloseTo(h.exp_bar.target, 3);
  expect(h.exp_bar.target).toBeGreaterThan(0.55);
  let s = await shot(game);
  const left = goldAlong(s, h.exp_bar.rect, 0.08, 0.45);
  const right = goldAlong(s, h.exp_bar.rect, 0.75, 0.95);
  expect(left, `gold where the bar is filled (${(left * 100).toFixed(0)}%)`).toBeGreaterThan(0.6);
  expect(right, `and not past it (${(right * 100).toFixed(0)}%)`).toBeLessThan(0.2);
  // Money pops large, at once.
  await game.query('dev_add_money', 25);
  await game.page.waitForTimeout(250);
  h = await game.query('hud');
  expect(h.pops).toContain('+$25');
  // Over the level: the burst and the words, once.
  const r = await game.query('dev_add_exp', 0);
  await game.query('dev_add_exp', r.next - r.exp + 5);
  await game.page.waitForTimeout(450);
  h = await game.query('hud');
  expect(h.level_up.playing).toBe(true);
  expect(h.level_up.title).toBe('LEVEL UP!');
  expect(h.level_up.line).toBe('Lv 2!');
  expect(h.level).toBe('Lv 2');
  expect(h.pops.filter((p) => p === 'Lv 2!').length, 'once').toBe(1);
  const t = h.level_up.title_rect;
  // Polled: on a loaded machine the words can still be fading in at the
  // first look (they show for two seconds). When they are not found, the
  // screen and the HUD's own account are attached: it failed twice in long
  // runs on a busy machine and passed every time alone (Step 56).
  info.attachments.push({ name: 'hud at the level-up', contentType: 'application/json', body: Buffer.from(JSON.stringify(h)) });
  const words = expect.poll(async () => {
    s = await shot(game);
    let lit = 0;
    for (let y = t[1] + t[3] * 0.3; y < t[1] + t[3] * 0.7; y += 2) {
      for (let x = t[0]; x < t[0] + t[2]; x += 2) if (gold(pixel(s.png, x * s.sx, y * s.sy))) lit += 1;
    }
    return lit;
  }, { message: 'the gold words are on the screen', timeout: 1500, intervals: [100, 200, 300] }).toBeGreaterThan(20);
  await words.catch(async (e) => {
    await game.page.screenshot({ path: info.outputPath('level-up.png') });
    info.attachments.push({ name: 'hud after', contentType: 'application/json', body: Buffer.from(JSON.stringify(await game.query('hud'))) });
    throw e;
  });
  await game.page.waitForTimeout(2200);
  h = await game.query('hud');
  expect(h.level_up.playing, 'then gone').toBe(false);
  expect(h.exp_bar.level).toBe(2);
  expect(h.exp_bar.value).toBeCloseTo(h.exp_bar.target, 3);
});
