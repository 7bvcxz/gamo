// Step 21: Momo's first unattended harvest brings a letter -- a red dot on the
// mailbox and an envelope over the Momo; tapping opens the list, the letter,
// accepts the proposal, and the dot goes.
import { test, expect } from '../lib/fixtures.mjs';

// Step 53: about what a Momo does -- the old starter Momo, explicitly.
test.use({ starterMomo: true });

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('a letter from Momo', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  await game.command({ type: 'momo.assign', momo: 1, building: id });
  // The Momo's first harvest is seconds away (Step 50); later milestones
  // bring more letters, so not much longer.
  await game.query('dev_advance_ms', 20000);
  await game.page.waitForTimeout(200);
  let m = await game.query('mail');
  expect(m.unread).toBe(1);
  expect(m.badge).toBe(true);
  expect(m.envelopes).toEqual([1]);
  const hud = await game.query('hud');
  const btn = await centre(game, hud.buttons.mailbox, hud.window);
  await game.tap(btn.x, btn.y);
  await game.page.waitForTimeout(250);
  m = await game.query('mail');
  expect(m.open).toBe(true);
  expect(m.rows.length).toBe(1);
  const row = await centre(game, m.rows[0].rect, m.window);
  await game.tap(row.x, row.y);
  await game.page.waitForTimeout(250);
  m = await game.query('mail');
  expect(m.reading).toBe(1);
  expect(m.title).toBe('What if we widened the field?');
  expect(m.from).toBe('From Momo');
  expect(m.badge).toBe(false);
  const claim = await centre(game, m.claim, m.window);
  await game.tap(claim.x, claim.y);
  await game.page.waitForTimeout(250);
  m = await game.query('mail');
  expect(m.claimed).toBe(true);
  const s = await game.state();
  expect(s.mail.letters[0].claimed_ms).toBeGreaterThanOrEqual(0);
  expect(s.mail.letters[0].research).toBe('farm_expansion');
});
