// Step 80: Settings > Advanced > Reset All Data in the real web build, by
// real taps (a finger on phones -- also the 720x1280 baseline -- the mouse on
// desktop), with a Momo selected (its Schedule button up) and the settings
// scrolled down: the dialog asks above everything, Cancel at either step and
// the red button before it is armed change nothing; confirmed, the game
// starts over as a brand-new player's -- the starting farm and money, no
// Momo, no research, default settings, the tutorial due -- the save and the
// settings and both localStorage mirrors are this new install's, and another
// game's keys are untouched; opened again in a new tab, still brand new.
// With MOMONIUM_SHOTS set, saves the dialog's two steps and the new island.
import { test, expect } from '@playwright/test';

test.describe.configure({ timeout: 240_000 });

async function open(context) {
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript(() => {
    window.MOMONIUM_E2E = true;
    // The real first island when the game starts over (not the bare test world).
    window.MOMONIUM_E2E_ISLAND = true;
    if (!localStorage.getItem('motorio_save')) localStorage.setItem('motorio_save', 'another game');
  });
  await page.goto('./');
  await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.state === 'function', null, { timeout: 90_000 });
  await page.waitForTimeout(500);
  const call = (name, arg) => page.evaluate(([n, a]) => window.momonium.call(n, a), [name, arg]);
  return { page, errors, call, state: () => page.evaluate(() => window.momonium.state()), command: (c) => page.evaluate((cmd) => window.momonium.command(cmd), c) };
}

async function tapRect(g, rect, win, info, settle = 350, canvasBox = null) {
  const box = canvasBox || await g.page.locator('canvas').boundingBox();
  const x = box.x + (rect[0] + rect[2] / 2) * (box.width / win[0]);
  const y = box.y + (rect[1] + rect[3] / 2) * (box.height / win[1]);
  if (info.project.use.hasTouch) await g.page.touchscreen.tap(x, y);
  else await g.page.mouse.click(x, y);
  if (settle) await g.page.waitForTimeout(settle);
}

async function shot(g, name, info, shape) {
  if (process.env.MOMONIUM_SHOTS) await g.page.screenshot({ path: `${process.env.MOMONIUM_SHOTS}/reset80_${info.project.name}_${shape}_${name}.png` });
}

// Cancel erases nothing: every store there before is still there. (The game
// autosaves every 15 s while on screen, and a save keeps the one before it as
// its backup -- a `.bak` may appear during a slow run; none may go.)
const kept = (before, now) => Object.fromEntries(Object.entries(before).filter(([, v]) => v).map(([k]) => [k, now[k]]));

const fresh = (s) => ({ money: s.economy.money, level: s.progression.level, exp: s.progression.exp, momo: s.momo.momos.length,
  buildings: s.buildings.buildings.map((b) => b.type), research: Object.keys(s.research.completed).length, rp: s.research.rp_earned,
  points: s.prestige.points });

for (const shape of ['default', '720x1280']) {
  test.describe(shape, () => {
    if (shape === '720x1280') test.use({ viewport: { width: 360, height: 640 } });

    test('two steps to erase; Cancel changes nothing; confirmed, a brand-new player', async ({ context }, info) => {
      test.skip(shape === '720x1280' && !info.project.use.hasTouch, 'the portrait baseline is a phone');
      const g = await open(context);
      await g.page.evaluate(() => window.momonium.setTimeScale(0));
      await g.call('set_language', 'en');
      // A played island: money, a level, two Momo, a lab, a research, a schedule; saved.
      await g.call('dev_add_money', 5000);
      await g.call('dev_add_exp', 3000);
      const m1 = (await g.call('dev_add_momo', [0.5, 1.4])).id;
      await g.call('dev_add_momo', [1.4, 0.5]);
      await g.call('dev_place_building', ['research', 0, 1]);
      await g.call('dev_research_done', ['farm_expansion']);
      await g.command({ type: 'momo.watch', momo: m1, cells: [[0, 0]], op: 'add' });
      expect((await g.call('save_now')).err).toBe(0);
      await g.call('dev_set_option', ['tips', false]);
      const played = fresh(await g.state());
      const before = await g.call('local_data');
      expect(Object.values(before.stores).filter(Boolean).length, 'a save, its mirror, settings and theirs').toBeGreaterThanOrEqual(4);
      // A Momo selected: its Schedule button up, under where the dialog goes.
      const mo = (await g.call('momos')).momos[String(m1)];
      const win = (await g.call('momos')).window;
      await tapRect(g, [mo.body[0] - 1, mo.body[1] - 1, 2, 2], win, info);
      expect((await g.call('watch')).momo, 'a Momo selected').toBe(m1);
      // Settings, scrolled to its end: Advanced, then Reset All Data.
      const hud = await g.call('hud');
      await tapRect(g, hud.buttons.settings, hud.window, info);
      await g.call('dev_settings_reveal', 'Advanced');
      let ui = await g.call('reset_ui');
      expect(ui.settings_open).toBe(true);
      expect(ui.reset, 'folded: no reset on show').toEqual([]);
      await tapRect(g, ui.advanced, ui.window, info);
      await g.call('dev_settings_reveal', 'ResetAll');
      ui = await g.call('reset_ui');
      expect(ui.reset.length, 'unfolded: Reset All Data').toBe(4);
      expect(ui.reset[3], 'a finger high (window px)').toBeGreaterThanOrEqual(40);
      const ask = async () => {
        await g.call('dev_settings_reveal', 'ResetAll');
        const u = await g.call('reset_ui');
        await tapRect(g, u.reset, u.window, info);
        return g.call('reset_ui');
      };
      // Step one, Cancel.
      ui = await ask();
      expect(ui.dialog).toBe(true);
      expect(ui.stage).toBe(1);
      expect(ui.title).toBe('Reset all data?');
      await shot(g, 'step1', info, shape);
      await tapRect(g, ui.cancel, ui.window, info);
      ui = await g.call('reset_ui');
      expect(ui.dialog, 'Cancel at step one').toBe(false);
      expect(fresh(await g.state()), 'the island as it was').toEqual(played);
      expect(kept(before.stores, (await g.call('local_data')).stores), 'every store as it was').toEqual(kept(before.stores, before.stores));
      // Step two, Cancel.
      ui = await ask();
      await tapRect(g, ui.continue, ui.window, info);
      ui = await g.call('reset_ui');
      expect(ui.stage, 'Continue: step two').toBe(2);
      expect(ui.title).toBe('This cannot be undone');
      const red = ui.confirm;
      await tapRect(g, ui.cancel, ui.window, info);
      ui = await g.call('reset_ui');
      expect(ui.dialog, 'Cancel at step two').toBe(false);
      expect(fresh(await g.state()), 'still the island as it was').toEqual(played);
      // Continue and the red button straight after, where it shows (a double
      // tap going through both): it is not armed yet.
      ui = await ask();
      const box = await g.page.locator('canvas').boundingBox();
      const t0 = Date.now();
      await tapRect(g, ui.continue, ui.window, info, 0, box);
      await tapRect(g, red, ui.window, info, 0, box);
      const took = Date.now() - t0;
      await g.page.waitForTimeout(300);
      ui = await g.call('reset_ui');
      console.log(`reset80 ${info.project.name} ${shape}: Continue -> red button in ${took} ms`);
      expect(took, 'both taps inside the arming time (0.8 s)').toBeLessThan(800);
      expect(ui.dialog && ui.stage === 2, 'the red button did nothing yet').toBe(true);
      expect(fresh(await g.state()), 'the island as it was').toEqual(played);
      await tapRect(g, ui.cancel, ui.window, info);
      expect((await g.call('reset_ui')).dialog).toBe(false);
      expect(kept(before.stores, (await g.call('local_data')).stores), 'every store as it was').toEqual(kept(before.stores, before.stores));
      // Confirmed.
      ui = await ask();
      await tapRect(g, ui.continue, ui.window, info);
      await g.page.waitForTimeout(1000);
      ui = await g.call('reset_ui');
      expect(ui.confirm_disabled, 'armed').toBe(false);
      await shot(g, 'step2', info, shape);
      await tapRect(g, ui.confirm, ui.window, info);
      // The game starts over: wait for the new one.
      await g.page.waitForFunction(() => {
        try { return window.momonium.call('local_data', null).load_status === 'missing'; } catch (e) { return false; }
      }, null, { timeout: 30_000 });
      await g.page.waitForTimeout(800);
      await g.page.evaluate(() => window.momonium.setTimeScale(0));
      const after = await g.call('local_data');
      const now = fresh(await g.state());
      console.log(`reset80 ${info.project.name} ${shape}: played ${JSON.stringify(played)} -> ${JSON.stringify(now)}`);
      expect(now.momo, 'no Momo').toBe(0);
      expect(now.buildings, 'the starting farm alone').toEqual(['farm']);
      expect(now.level).toBe(1);
      expect(now.exp).toBe(0);
      expect(now.research).toBe(0);
      expect(now.rp).toBe(0);
      expect(now.points).toBe(0);
      expect(now.money, 'the starting money').toBe(10);
      expect(after.tutorial_done, 'the tutorial is due').toBe(false);
      expect(after.language, 'the language follows the device').toBe('');
      expect(after.stores['momonium_settings'], 'no old settings mirror').toBe(false);
      const mirror = await g.page.evaluate(() => localStorage.getItem('momonium_save'));
      if (mirror !== null) expect(mirror.includes('"momos":[]') || !mirror.includes('farm_expansion'), 'any save mirror is the new island').toBe(true);
      expect(await g.page.evaluate(() => localStorage.getItem('motorio_save')), "another game's key untouched").toBe('another game');
      await shot(g, 'fresh', info, shape);
      expect(g.errors).toEqual([]);
      await g.page.close();
      // Opened again in a new tab: still a brand-new island.
      const h = await open(context);
      await h.page.evaluate(() => window.momonium.setTimeScale(0));
      const again = fresh(await h.state());
      expect(again.momo, 'reopened: no Momo').toBe(0);
      expect(again.money).toBe(10);
      expect(again.research).toBe(0);
      expect(h.errors).toEqual([]);
      await h.page.close();
    });
  });
}
