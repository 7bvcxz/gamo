// Step 21: Momo's unattended work brings a letter. Step 57: the mailbox button
// alone tells it -- a red dot that pulses (once) -- and the letter's research is
// discovered at once: the Research button gets a red dot of its own, without
// the letter being opened. Opened, the letter shows what that research needs
// (the real rules) and the way to it; Research opens on the news and the dot
// goes.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

// Step 53: about what a Momo does -- the old starter Momo, explicitly.
test.use({ starterMomo: true });

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

// Red pixels in a button's top-right corner (its dot), in the WebGL canvas.
async function dotPixels(game, rect, win) {
  const png = decodePng(await game.canvas.screenshot());
  const sx = png.width / win[0];
  const sy = png.height / win[1];
  let n = 0;
  for (let y = rect[1]; y < rect[1] + rect[3] * 0.35; y += 1) {
    for (let x = rect[0] + rect[2] * 0.65; x < rect[0] + rect[2]; x += 1) {
      const [r, g, b] = pixel(png, x * sx, y * sy);
      if (r > 200 && g < 120 && b < 110) n += 1;
    }
  }
  return n;
}

test('a letter from Momo: news on the buttons, its research found without opening it', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  await game.command({ type: 'momo.assign', momo: 1, building: id });
  let m = await game.query('mail');
  expect(m.research_badge, 'nothing new yet').toBe(false);
  // Ten farm stages by the Momo (Step 57). Step 69: a stage is 6.25 s of work
  // now, so that is about two minutes of play -- the loop stops at the letter.
  for (let i = 0; i < 120 && m.unread === 0; i++) {
    await game.query('dev_advance_ms', 2000);
    m = await game.query('mail');
  }
  await game.page.waitForTimeout(250);
  m = await game.query('mail');
  expect(m.unread).toBe(1);
  expect(m.badge).toBe(true);
  expect(m.pulses, 'the mailbox played its news, once').toBe(1);
  expect(m.envelopes, 'nothing over the Momo any more').toBeUndefined();
  expect(m.research_badge, 'the research is news before the letter is read').toBe(true);
  expect(m.new_topics).toEqual(['farm_expansion']);
  const hud = await game.query('hud');
  expect(await dotPixels(game, hud.buttons.research, hud.window), 'a red dot drawn on Research').toBeGreaterThan(6);
  // Research first, letter unread: it opens on the news.
  let btn = await centre(game, hud.buttons.research, hud.window);
  await game.tap(btn.x, btn.y);
  await game.page.waitForTimeout(300);
  let r = await game.query('research');
  expect(r.open).toBe(true);
  expect(r.tab).toBe('mastery.farm');
  expect(r.selected).toBe('farm_expansion');
  expect(r.nodes.farm_expansion.state).toBe('available');
  expect(r.fresh).toEqual(['farm_expansion']);
  expect(r.tab_dots).toEqual(['mastery.farm']);
  expect(r.badge, 'shown: the dot goes').toBe(false);
  await game.tap(btn.x, btn.y);
  await game.page.waitForTimeout(250);
  expect(await dotPixels(game, hud.buttons.research, hud.window), 'and is gone from the screen').toBe(0);
  expect((await game.state()).mail.letters[0].read_ms, 'the letter still unread').toBe(-1);
  // Now the letter: what its research needs, and the way to it.
  btn = await centre(game, hud.buttons.mailbox, hud.window);
  await game.tap(btn.x, btn.y);
  await game.page.waitForTimeout(250);
  m = await game.query('mail');
  expect(m.rows[0].unread).toBe(true);
  const row = await centre(game, m.rows[0].rect, m.window);
  await game.tap(row.x, row.y);
  await game.page.waitForTimeout(250);
  m = await game.query('mail');
  expect(m.reading).toBe(1);
  expect(m.title).toBe('What if we widened the field?');
  expect(m.badge).toBe(false);
  expect(m.footer.visible).toBe(true);
  expect(m.footer.title).toBe('To research Field expansion');
  expect(m.footer.lines).toContain('✓ Now on the Research list');
  expect(m.footer.lines).toContain('· A research lab');
  expect(m.footer.button_text).toBe('See it in Research');
  const go = await centre(game, m.footer.button, m.window);
  await game.tap(go.x, go.y);
  await game.page.waitForTimeout(300);
  r = await game.query('research');
  expect(r.open, 'the letter leads to its research').toBe(true);
  expect(r.selected).toBe('farm_expansion');
  const s = await game.state();
  expect(s.mail.letters[0].research).toBe('farm_expansion');
  expect(s.mail.letters[0].read_ms).toBeGreaterThanOrEqual(0);
});
