// Step 71: research eight tiers deep, shown a little at a time. A new island
// shows two disciplines and one farm topic; at Lv 5 every tab is there but
// nothing past the middle tiers; at Lv 11 the farm's eighth tier (the combine
// harvester) is on the screen -- opened on it, the tree scrolls to the card
// and the details name it -- and every card stays inside the tree's view.
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

const close = async (game, r) => {
  const c = await centre(game, r.close, r.window);
  await game.tap(c.x, c.y);
  await game.page.waitForTimeout(250);
};

const shown = (r) => Object.entries(r.nodes).filter(([, n]) => n.shown);

const insideView = (r) => {
  const v = r.tree_view;
  for (const [id, n] of shown(r)) {
    const [x, , w] = n.rect;
    expect(x >= v[0] - 1 && x + w <= v[0] + v[2] + 1, `${id} inside the tree's width`).toBe(true);
  }
};

test('the research tree grows with the level and reaches tier 8', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');

  let r = await openResearch(game);
  expect(r.tabs_shown, 'a new island: two disciplines (and the points)').toEqual(['mastery.farm', 'research.tab.research', 'rp.tab']);
  expect(shown(r).map(([id]) => id), 'one farm topic').toEqual(['farm_expansion']);
  await game.page.screenshot({ path: info.outputPath('lv1.png') });
  await close(game, r);

  await game.query('dev_level', 5);
  r = await openResearch(game);
  expect(r.tabs_shown.length, 'Lv 5: every tab').toBe(7);
  const mid = shown(r);
  expect(mid.length, 'more of the farm').toBeGreaterThan(4);
  expect(Math.max(...mid.map(([, n]) => n.tier)), 'but not the deep tiers yet').toBeLessThan(6);
  insideView(r);
  await game.page.screenshot({ path: info.outputPath('lv5.png') });
  await close(game, r);

  await game.query('dev_level', 11);
  await game.query('dev_research_open', 'combine_harvester');
  await game.page.waitForTimeout(500);
  r = await game.query('research');
  expect(r.selected).toBe('combine_harvester');
  expect(r.name, 'the details name it').toBe('Combine harvester');
  const top = r.nodes.combine_harvester;
  expect(top.shown && top.tier === 8, 'the eighth tier is on the screen').toBe(true);
  const v = r.tree_view;
  expect(top.rect[1] >= v[1] - 1 && top.rect[1] + top.rect[3] <= v[1] + v[3] + 1, 'scrolled to its card').toBe(true);
  insideView(r);
  await game.page.screenshot({ path: info.outputPath('lv11.png') });

  // The Mine tab too: its eighth tier, the rock drill.
  const tab = await centre(game, r.tabs['mastery.mine'], r.window);
  await game.tap(tab.x, tab.y);
  await game.page.waitForTimeout(300);
  r = await game.query('research');
  expect(r.tab).toBe('mastery.mine');
  expect(r.nodes.rock_drill.shown && r.nodes.rock_drill.tier === 8, "the mine's eighth tier").toBe(true);
  insideView(r);
});
