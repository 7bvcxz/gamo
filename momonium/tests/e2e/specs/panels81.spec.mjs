// Step 81: the Research and Status panels in the real web build, by real taps
// (a finger on phones -- also the 720x1280 baseline -- the mouse on desktop):
// in four languages at every UI scale the card stays inside the window and
// clear of every HUD piece, the tabs are whole in their own row (the chosen
// one never cut), nothing is drawn under a scroll bar and one vertical bar
// shows at a time; the tab row scrolls on its own, the tree and the details
// scroll inside the card and the island never moves under it; a touch on the
// card reaches nothing behind it; ✕, the scrim and Escape close it; turned
// from upright to sideways and back, it lays itself out again.
// With MOMONIUM_SHOTS set, saves the panels it looks at.
import { test, expect } from '../lib/fixtures.mjs';
import { touchDrag } from '../lib/touch.mjs';

test.describe.configure({ timeout: 300_000 });

const inter = (a, b) => Math.max(0, Math.min(a[0] + a[2], b[0] + b[2]) - Math.max(a[0], b[0])) * Math.max(0, Math.min(a[1] + a[3], b[1] + b[3]) - Math.max(a[1], b[1]));

// What is wrong with the open panel (window pixels), as the player would see it.
// `swiped`: the player has scrolled the tab row, so the chosen tab may be off.
function problems(L, swiped = false) {
  const out = [];
  if (!L.open) return ['not open'];
  const [W, H] = L.window;
  const c = L.card;
  if (c[0] < -0.5 || c[1] < -0.5 || c[0] + c[2] > W + 0.5 || c[1] + c[3] > H + 0.5) out.push(`card off the window ${c.map(Math.round)}`);
  for (const h of L.hud) if (inter(c, h) > 1) out.push(`card over the HUD ${h.map(Math.round)}`);
  const ts = L.tab_scroll;
  for (const t of L.tabs.filter((x) => x.visible)) {
    const r = t.rect;
    if (ts.length) {
      if (r[1] < ts[1] - 0.5 || r[1] + r[3] > ts[1] + ts[3] + 0.5) out.push(`tab ${t.text} cut top or bottom`);
      const shown = Math.min(r[0] + r[2], ts[0] + ts[2]) - Math.max(r[0], ts[0]);
      if (shown > 0 && shown < r[2] - 0.5 && ((t.selected && !swiped) || !L.tab_overflow)) out.push(`tab ${t.text} cut sideways`);
      if (shown > 1 && inter(r, L.close) > 1) out.push(`tab ${t.text} under the close button`);
    }
    if (inter(r, L.scroll) > 1) out.push(`tab ${t.text} over the body`);
  }
  for (const u of L.under_bar) out.push(`${u.node} "${String(u.text || '').slice(0, 16)}" under a scroll bar`);
  if (L.bar_visible) for (const h of L.hud) if (inter(L.bar, h) > 0) out.push("the body's bar on the HUD");
  if (L.tree_bar_visible && L.bar_visible) out.push('two vertical bars');
  if (L.tree_bar_visible && L.detail && inter(L.tree_bar, L.detail) > 0) out.push("the tree's bar over the details");
  return out;
}

async function setup(game) {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_grow_island', 4);
  await game.query('dev_level', 20);
  await game.query('dev_add_money', 100000);
  for (const [t, x, y] of [['farm', 0, 0], ['research', 1, 0], ['mine', 2, 0], ['lumberyard', 0, 1]]) await game.query('dev_place_building', [t, x, y]);
  for (let i = 0; i < 4; i++) await game.query('dev_add_momo', [1.5 + i * 0.3, 1.5]);
  await game.page.waitForTimeout(200);
}

// The centre of a window-pixel rectangle, in canvas CSS pixels.
async function at(game, rect, win) {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
}

async function tapRect(game, rect, win, settle = 300) {
  const p = await at(game, rect, win);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(settle);
}

async function hudTap(game, key) {
  const hud = await game.query('hud');
  await tapRect(game, hud.buttons[key], hud.window, 450);
}

// A swipe (phone) or the wheel (desktop) over a window-pixel point; dx/dy is
// which way the content should go on (positive: further right / down).
async function scrollAt(game, info, rect, win, dx, dy) {
  const box = await game.canvas.boundingBox();
  const p = await at(game, rect, win);
  const from = { x: box.x + p.x, y: box.y + p.y };
  if (info.project.use.hasTouch) {
    await touchDrag(game.page, from, { x: from.x - dx, y: from.y - dy }, 12);
  } else {
    // A row that only scrolls sideways takes the plain wheel sideways.
    await game.page.mouse.move(from.x, from.y);
    const d = Math.sign(dy || dx) * 120;
    for (let i = 0; i < 4; i++) await game.page.mouse.wheel(0, d);
  }
  await game.page.waitForTimeout(400);
}

async function shot(game, info, name) {
  if (process.env.MOMONIUM_SHOTS) await game.page.screenshot({ path: `${process.env.MOMONIUM_SHOTS}/panels81_${info.project.name}_${name}.png` });
}

for (const shape of ['default', '720x1280']) {
  test.describe(shape, () => {
    if (shape === '720x1280') test.use({ viewport: { width: 360, height: 640 } });

    test('every language and UI scale: clear of the HUD, tabs whole, nothing under a bar', async ({ game }, info) => {
      test.skip(shape === '720x1280' && !info.project.use.hasTouch, 'the portrait baseline is a phone');
      await setup(game);
      const bad = [];
      let seen = 0;
      for (const lang of ['en', 'ko', 'ja', 'zh_CN']) {
        for (const scale of [0.85, 1, 1.25]) {
          await game.query('set_language', lang);
          await game.query('dev_set_option', ['ui_scale', scale]);
          await game.page.waitForTimeout(350);
          // Research by its button, then two topics deep in long trees.
          await hudTap(game, 'research');
          for (const topic of ['', 'momo_training', 'seed_drill']) {
            if (topic) await game.query('dev_research_open', topic);
            await game.page.waitForTimeout(topic ? 350 : 50);
            const L = await game.query('panel_layout');
            expect(L.name, 'Research is the one open').toBe('ResearchFrame');
            const p = problems(L);
            seen++;
            if (p.length) bad.push(`${lang} x${scale} research ${topic || 'first'}: ${p.join(' | ')}`);
          }
          if (lang === 'ko' && scale === 1.25) await shot(game, info, `${shape}_ko_x125_research`);
          // ✕ closes it.
          let L = await game.query('panel_layout');
          await tapRect(game, L.close, L.window);
          expect((await game.query('panel_layout')).open, '✕ closes Research').toBe(false);
          // Status by its button; every tab, tapped where it shows.
          await hudTap(game, 'status');
          L = await game.query('panel_layout');
          for (let t = 0; t < L.tabs.length; t++) {
            const tab = L.tabs[t];
            const r = tab.rect;
            const ts = L.tab_scroll;
            if (r[0] >= ts[0] - 0.5 && r[0] + r[2] <= ts[0] + ts[2] + 0.5) await tapRect(game, r, L.window, 350);
            else { await game.query('dev_status_tab', t); await game.page.waitForTimeout(350); }
            L = await game.query('panel_layout');
            expect(L.tabs[t].selected, `${lang} x${scale}: tab ${tab.text} chosen`).toBe(true);
            const p = problems(L);
            seen++;
            if (p.length) bad.push(`${lang} x${scale} status ${tab.text}: ${p.join(' | ')}`);
          }
          if (lang === 'ja' && scale === 1.25) await shot(game, info, `${shape}_ja_x125_status`);
          await game.page.keyboard.press('Escape');
          await game.page.waitForTimeout(250);
          expect((await game.query('panel_layout')).open, 'Escape closes Status').toBe(false);
        }
      }
      console.log(`panels81 ${info.project.name} ${shape}: ${seen} panel states, ${bad.length} with a problem`);
      expect(bad, 'no problem in any state').toEqual([]);
      expect(seen).toBeGreaterThanOrEqual(4 * 3 * 10);
    });

    test('scrolls inside the card, never through it; a touch on the card reaches nothing', async ({ game }, info) => {
      test.skip(shape === '720x1280' && !info.project.use.hasTouch, 'the portrait baseline is a phone');
      await setup(game);
      await game.query('dev_set_option', ['ui_scale', 1.25]);
      await game.page.waitForTimeout(350);
      // A Momo selected first: a touch reaching the island would put it down.
      const momos = await game.query('momos');
      const mo = Object.values(momos.momos)[0];
      await tapRect(game, [mo.body[0] - 1, mo.body[1] - 1, 2, 2], momos.window);
      // (They stand close together: whichever the finger found.)
      const picked = (await game.query('watch')).momo;
      expect(picked, 'a Momo selected').toBeGreaterThan(0);
      const cam0 = await game.query('camera');
      // Research, the farm's long tree with a deep topic picked.
      await hudTap(game, 'research');
      let L = await game.query('panel_layout');
      // As it opens, the new topics' tabs have their dots, inside the tab.
      const dotted = L.tabs.filter((t) => t.visible && t.dot);
      expect(dotted.length, 'new topics: dots on the tabs').toBeGreaterThan(0);
      for (const t of dotted) {
        const r = t.rect;
        const shown = Math.min(r[0] + r[2], L.tab_scroll[0] + L.tab_scroll[2]) - Math.max(r[0], L.tab_scroll[0]);
        if (shown >= r[2] - 0.5) expect(r[1] >= L.tab_scroll[1] - 0.5 && r[1] + r[3] <= L.tab_scroll[1] + L.tab_scroll[3] + 0.5, `${t.text}: its dot in the row`).toBe(true);
      }
      await game.query('dev_research_open', 'seed_drill');
      await game.page.waitForTimeout(400);
      L = await game.query('panel_layout');
      expect(problems(L)).toEqual([]);
      if (L.tree_scrolls) {
        const y0 = L.tree_scroll_y;
        const detail0 = L.detail;
        await scrollAt(game, info, L.tree_scroll, L.window, 0, -160);
        const L2 = await game.query('panel_layout');
        expect(L2.tree_scroll_y, 'the tree scrolled').not.toBe(y0);
        expect(L2.detail, 'the details stay').toEqual(detail0);
        expect(L2.body_scroll_y, 'the card itself does not scroll').toBe(0);
        L = L2;
      }
      if (L.detail_scrolls) {
        const y0 = L.detail_scroll_y;
        await scrollAt(game, info, L.detail, L.window, 0, 160);
        L = await game.query('panel_layout');
        expect(L.detail_scroll_y, 'the details scrolled in their own view').not.toBe(y0);
      }
      // A touch on the card's padding and on the gap above the body.
      for (const r of [[L.card[0] + 2, L.card[1] + L.card[3] / 2, 2, 2], [L.card[0] + L.card[2] / 2, (L.tab_scroll[1] + L.tab_scroll[3] + L.scroll[1]) / 2, 1, 1]]) {
        await tapRect(game, r, L.window);
        expect((await game.query('panel_layout')).open, 'the panel stays').toBe(true);
      }
      await shot(game, info, `${shape}_research_scrolled`);
      await tapRect(game, L.close, L.window);
      // Status: the tab row scrolls on its own; the body scrolls in its view.
      await hudTap(game, 'status');
      L = await game.query('panel_layout');
      expect(problems(L), 'Status as it opens').toEqual([]);
      if (L.tab_overflow) {
        const x0 = L.tab_scroll_x;
        await scrollAt(game, info, L.tab_scroll, L.window, 160, 0);
        const L2 = await game.query('panel_layout');
        expect(L2.tab_scroll_x, 'the tab row scrolled').not.toBe(x0);
        expect(L2.body_scroll_y, 'the body did not').toBe(L.body_scroll_y);
        L = L2;
      }
      if (L.body_scrolls) {
        await scrollAt(game, info, L.scroll, L.window, 0, 160);
        L = await game.query('panel_layout');
        expect(L.body_scroll_y, 'the body scrolled').toBeGreaterThan(0);
      }
      expect(problems(L, true)).toEqual([]);
      const cam1 = await game.query('camera');
      expect([cam1.x, cam1.y, cam1.zoom], 'the island never moved under the card').toEqual([cam0.x, cam0.y, cam0.zoom]);
      expect((await game.query('watch')).momo, 'the Momo still selected: nothing reached the island').toBe(picked);
      // The scrim (outside the card) closes it.
      const below = [L.card[0] + 20, Math.min(L.card[1] + L.card[3] + 30, L.window[1] - 160), 2, 2];
      if (below[1] > L.card[1] + L.card[3] + 4) {
        await tapRect(game, below, L.window);
        expect((await game.query('panel_layout')).open, 'the scrim closes it').toBe(false);
      }
    });
  });
}

test('turned sideways and back, the panel lays itself out again', async ({ game }, info) => {
  test.skip(!info.project.use.hasTouch, 'a phone turns');
  await setup(game);
  await hudTap(game, 'research');
  await game.query('dev_research_open', 'momo_training');
  await game.page.waitForTimeout(400);
  const upright = await game.query('panel_layout');
  expect(problems(upright)).toEqual([]);
  const vp = game.page.viewportSize();
  await game.page.setViewportSize({ width: vp.height, height: vp.width });
  await game.page.waitForTimeout(900);
  const sideways = await game.query('panel_layout');
  expect(sideways.open, 'still open').toBe(true);
  expect(sideways.window[0], 'the window turned').toBeGreaterThan(sideways.window[1]);
  expect(problems(sideways), 'sideways: clear').toEqual([]);
  await shot(game, info, 'sideways_research');
  await game.page.setViewportSize(vp);
  await game.page.waitForTimeout(900);
  const back = await game.query('panel_layout');
  expect(problems(back), 'upright again: clear').toEqual([]);
  expect(back.card.map(Math.round), 'where it was').toEqual(upright.card.map(Math.round));
});
