// Step 70: research opens at the player level. A new island: the research
// panel shows Field expansion locked with a plain "Lv 2" on its card and
// "Unlocks at Lv. 2" when picked, nothing counted as news. The player's EXP
// goes up past Lv 2 (the same add_exp the work pays into): the card opens, its
// Lv cue goes, the Research button counts exactly the topics that opened, and
// no tutorial bubble or other new window appears for it.
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

const openResearch = async (game) => {
  const hud = await game.query('hud');
  const btn = await centre(game, hud.buttons.research, hud.window);
  await game.tap(btn.x, btn.y);
  await game.page.waitForTimeout(300);
  return game.query('research');
};

test('a research topic opens at its level, with a visible Lv cue', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const start = await game.query('dev_add_exp', 0);
  expect(start.level, 'a new island is Lv 1').toBe(1);

  let r = await openResearch(game);
  expect(r.open).toBe(true);
  expect(r.tab, 'the farm branch').toBe('mastery.farm');
  expect(r.new_topics, 'Lv 1: no topic is news').toEqual([]);
  expect(r.badge_count, 'and the Research button counts nothing').toBe(0);
  expect(r.badge).toBe(false);
  expect(r.nodes.farm_expansion.state).toBe('locked');
  expect(r.nodes.farm_expansion.gate, 'the card says the level it opens at').toBe('Lv 2');
  expect(r.nodes.harvest_boost.gate, 'a later one says its own').toBe('Lv 3');
  const node = await centre(game, r.nodes.farm_expansion.rect, r.window);
  await game.tap(node.x, node.y);
  await game.page.waitForTimeout(250);
  r = await game.query('research');
  expect(r.selected).toBe('farm_expansion');
  expect(r.needs, 'picked: one plain line').toEqual(['Unlocks at Lv. 2']);
  expect(r.button_disabled).toBe(true);
  await game.page.screenshot({ path: info.outputPath('lv1.png') });

  // Close it, and the EXP goes up -- most of the way first: still Lv 1.
  const close = await centre(game, r.close, r.window);
  await game.tap(close.x, close.y);
  await game.page.waitForTimeout(250);
  expect((await game.query('research')).open, 'closed by its ✕').toBe(false);
  const part = await game.query('dev_add_exp', Math.floor(start.next / 2));
  expect(part.level).toBe(1);
  r = await game.query('research');
  expect(r.new_topics, 'half way: still nothing').toEqual([]);
  const lv2 = await game.query('dev_add_exp', start.next);
  expect(lv2.level, 'Lv 2').toBe(2);
  await game.page.waitForTimeout(400);
  const tut = await game.query('tutorial');
  expect(tut.running, 'no tutorial for it').toBe(false);
  expect(tut.text, 'and no tutorial words').toBe('');
  r = await game.query('research');
  expect(r.open, 'no window opened by itself').toBe(false);
  expect([...r.new_topics].sort(), 'exactly the topics Lv 2 opened are news').toEqual(['farm_expansion', 'field_notebook']);
  expect(r.badge_count, 'the Research button counts them').toBe(2);
  expect(r.badge).toBe(true);

  r = await openResearch(game);
  expect(r.open).toBe(true);
  expect(r.nodes.farm_expansion.state, 'open now').toBe('available');
  expect(r.nodes.farm_expansion.gate, 'and its Lv cue is gone').toBe('');
  expect(r.fresh, 'marked as news in the panel').toContain('farm_expansion');
  expect(r.nodes.harvest_boost.gate, 'the Lv 3 one still says Lv 3').toBe('Lv 3');
  expect(r.nodes.watering_efficiency.gate, 'a child that now waits only for its parent shows no level').toBe('');
  await game.page.screenshot({ path: info.outputPath('lv2.png') });
  await game.page.waitForTimeout(300);
  r = await game.query('research');
  expect(r.badge_count, 'seen: the count goes out').toBe(0);
});
