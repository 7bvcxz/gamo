// Step 82: the layer table in the real web build, by real taps (a finger on
// phones -- also the 720x1280 baseline -- the mouse on desktop). A selected
// Momo's Schedule button is under every panel: opening Settings, Research,
// Status, the Shop or Mail hides it (the pixels where it was change to the
// panel's) and a tap there never starts a Schedule; closing gives it back and
// it works. Reset All Data's confirmation is above the HUD, the scrim and the
// Schedule, and one tap on its dim cancels it alone. Gestures, a wheel and a
// drag on an open panel leave the island where it was. The tutorial and a
// level banner give way to a panel and come back after it.
// With MOMONIUM_SHOTS set, saves before/after pictures.
import { test, expect } from '../lib/fixtures.mjs';
import { decodePng } from '../lib/png.mjs';
import { touchDrag, pinch } from '../lib/touch.mjs';

test.describe.configure({ timeout: 240_000 });
test.use({ starterMomo: true });

async function at(game, rect, win) {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
}

async function tapRect(game, rect, win, settle = 350) {
  const p = await at(game, rect, win);
  await game.tap(p.x, p.y);
  await game.page.waitForTimeout(settle);
}

async function hudTap(game, key) {
  const hud = await game.query('hud');
  await tapRect(game, hud.buttons[key], hud.window, 450);
}

// The canvas pixels inside a window-pixel rectangle (RGBA rows).
async function crop(game, rect, win) {
  const box = await game.canvas.boundingBox();
  const png = decodePng(await game.page.screenshot({ clip: { x: box.x + rect[0] * (box.width / win[0]), y: box.y + rect[1] * (box.height / win[1]), width: rect[2] * (box.width / win[0]), height: rect[3] * (box.height / win[1]) } }));
  return png;
}

// Mean absolute difference per channel (0-255) of two same-size crops.
function diff(a, b) {
  const n = Math.min(a.data.length, b.data.length);
  let s = 0;
  let c = 0;
  for (let i = 0; i < n; i += 4) {
    s += Math.abs(a.data[i] - b.data[i]) + Math.abs(a.data[i + 1] - b.data[i + 1]) + Math.abs(a.data[i + 2] - b.data[i + 2]);
    c += 3;
  }
  return s / Math.max(c, 1);
}

async function shot(game, info, name) {
  if (process.env.MOMONIUM_SHOTS) await game.page.screenshot({ path: `${process.env.MOMONIUM_SHOTS}/layers82_${info.project.name}_${name}.png` });
}

async function selectMomo(game) {
  const m = await game.query('momos');
  const mo = Object.values(m.momos)[0];
  await tapRect(game, [mo.body[0] - 1, mo.body[1] - 1, 2, 2], m.window);
  const w = await game.query('watch');
  expect(w.momo, 'a Momo selected').toBeGreaterThan(0);
  expect(w.schedule_shown, 'its Schedule button shows').toBe(true);
  return w;
}

async function closeAll(game) {
  await game.page.keyboard.press('Escape');
  await game.page.waitForTimeout(300);
}

for (const shape of ['default', '720x1280']) {
  test.describe(shape, () => {
    if (shape === '720x1280') test.use({ viewport: { width: 360, height: 640 } });

    test('the Schedule button never shows or works through a panel', async ({ game }, info) => {
      test.skip(shape === '720x1280' && !info.project.use.hasTouch, 'the portrait baseline is a phone');
      await game.setTimeScale(0);
      await game.query('set_language', 'en');
      await game.query('dev_set_option', ['tips', false]);
      const w0 = await selectMomo(game);
      const win = w0.window;
      const rect = w0.schedule;
      const before = await crop(game, rect, win);
      await shot(game, info, `${shape}_selected`);
      for (const key of ['settings', 'research', 'status', 'shop', 'mailbox']) {
        await hudTap(game, key);
        const L = await game.query('layers');
        expect(L.busy, `${key}: a panel is open`).toBe(true);
        expect(L.open.length, `${key}: one panel`).toBe(1);
        expect(L.shown.Context, `${key}: the world's controls give way`).toBe(false);
        const w = await game.query('watch');
        expect(w.schedule_shown, `${key}: the Schedule button is not drawn`).toBe(false);
        expect(w.momo, `${key}: the Momo stays selected`).toBe(w0.momo);
        // The pixels where it was are the panel's (or its scrim's) now.
        const after = await crop(game, rect, win);
        const d = diff(before, after);
        console.log(`layers82 ${info.project.name} ${shape} ${key}: Schedule pixels changed by ${d.toFixed(1)}`);
        // 0.81 (the button drawn over the panel) measured 7-29 here -- the
        // scrim darkening its edges; hidden under the panel, 63-120.
        expect(d, `${key}: the button's pixels are gone`).toBeGreaterThan(45);
        if (key === 'settings') await shot(game, info, `${shape}_settings_over_schedule`);
        // A finger where the button was: no Schedule.
        await tapRect(game, rect, win);
        const w2 = await game.query('watch');
        expect(w2.editing, `${key}: no Schedule through the panel`).toBe(false);
        expect(w2.momo, `${key}: still selected`).toBe(w0.momo);
        if ((await game.query('layers')).busy) await closeAll(game);
        const back = await game.query('watch');
        expect((await game.query('layers')).busy, `${key}: closed`).toBe(false);
        expect(back.schedule_shown, `${key}: closed, the Schedule button is back`).toBe(true);
      }
      const w3 = await game.query('watch');
      await tapRect(game, w3.schedule, w3.window);
      expect((await game.query('watch')).editing, 'closed: the Schedule button works again').toBe(true);
    });

    test('the reset confirmation is above everything; one tap on its dim cancels it alone', async ({ game }, info) => {
      test.skip(shape === '720x1280' && !info.project.use.hasTouch, 'the portrait baseline is a phone');
      await game.setTimeScale(0);
      await game.query('set_language', 'en');
      await game.query('dev_set_option', ['tips', false]);
      const w0 = await selectMomo(game);
      await hudTap(game, 'settings');
      await game.query('dev_settings_reveal', 'Advanced');
      let ui = await game.query('reset_ui');
      await tapRect(game, ui.advanced, ui.window);
      const ask = async () => {
        await game.query('dev_settings_reveal', 'ResetAll');
        const u = await game.query('reset_ui');
        await tapRect(game, u.reset, u.window);
        return game.query('reset_ui');
      };
      ui = await ask();
      expect(ui.dialog, 'the confirmation is up').toBe(true);
      const L = await game.query('layers');
      expect(L.modal_open).toBe(true);
      expect(L.modal_layer, 'its own layer above the UI').toBeGreaterThan(L.ui_layer);
      await shot(game, info, `${shape}_reset_over_all`);
      // The HUD's Research button under the dim: the dim takes the tap, cancels, and that is all.
      const hud = await game.query('hud');
      await tapRect(game, hud.buttons.research, hud.window, 500);
      ui = await game.query('reset_ui');
      expect(ui.dialog, 'the dim cancels').toBe(false);
      expect((await game.query('layers')).open, 'Settings stays -- the rest of the tap did not close it -- and Research never opened').toEqual(['SettingsFrame']);
      // Where the Schedule button is, under the confirmation: its dim (which
      // cancels) or its card (which keeps it) takes the tap -- never the button.
      ui = await ask();
      await tapRect(game, w0.schedule, w0.window, 500);
      expect((await game.query('watch')).editing, 'no Schedule under the confirmation').toBe(false);
      if ((await game.query('reset_ui')).dialog) {
        await game.page.keyboard.press('Escape');
        await game.page.waitForTimeout(300);
      }
      expect((await game.query('layers')).open, 'Settings stays').toEqual(['SettingsFrame']);
      // Escape: the confirmation first, then Settings.
      ui = await ask();
      await game.page.keyboard.press('Escape');
      await game.page.waitForTimeout(300);
      expect((await game.query('reset_ui')).dialog, 'Escape: the confirmation goes').toBe(false);
      expect((await game.query('layers')).open).toEqual(['SettingsFrame']);
      await game.page.keyboard.press('Escape');
      await game.page.waitForTimeout(300);
      expect((await game.query('layers')).busy, 'Escape again: Settings goes').toBe(false);
      expect((await game.query('watch')).schedule_shown, 'the Schedule button is back').toBe(true);
    });
  });
}

test('gestures, a wheel and a drag on an open panel leave the island where it was', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_set_option', ['tips', false]);
  const money = (await game.state()).economy.money;
  await hudTap(game, 'status');
  const P = await game.query('panel_layout');
  const cam0 = await game.query('camera');
  const box = await game.canvas.boundingBox();
  const sx = box.width / P.window[0];
  const sy = box.height / P.window[1];
  // A point on the scrim beside the card and one on the card.
  const scrim = { x: box.x + (P.card[0] + P.card[2] / 2) * sx, y: box.y + Math.min(P.card[1] + P.card[3] + 40, P.window[1] - 170) * sy };
  const card = { x: box.x + (P.card[0] + P.card[2] / 2) * sx, y: box.y + (P.card[1] + P.card[3] * 0.6) * sy };
  if (info.project.use.hasTouch) {
    await pinch(game.page, card, 60, 200);
    await game.page.waitForTimeout(300);
    await touchDrag(game.page, card, { x: card.x + 80, y: card.y + 60 });
    await game.page.waitForTimeout(300);
  } else {
    await game.page.mouse.move(scrim.x, scrim.y);
    for (let i = 0; i < 4; i++) await game.page.mouse.wheel(0, -120);
    await game.page.waitForTimeout(300);
    expect((await game.query('layers')).busy, 'a wheel on the scrim leaves the panel open').toBe(true);
    await game.page.mouse.move(card.x, card.y);
    for (let i = 0; i < 4; i++) await game.page.mouse.wheel(0, -120);
    await game.page.waitForTimeout(300);
  }
  const cam1 = await game.query('camera');
  expect([cam1.x, cam1.y, cam1.zoom], 'the island did not move or zoom').toEqual([cam0.x, cam0.y, cam0.zoom]);
  expect((await game.state()).economy.money, 'no land bought').toBe(money);
  await closeAll(game);
  // Closed: the island takes the same gesture again.
  const c2 = await game.query('camera');
  if (info.project.use.hasTouch) {
    await touchDrag(game.page, card, { x: card.x + 80, y: card.y + 60 });
  } else {
    await game.page.mouse.move(card.x, card.y);
    for (let i = 0; i < 4; i++) await game.page.mouse.wheel(0, -120);
  }
  await game.page.waitForTimeout(400);
  const c3 = await game.query('camera');
  expect([c3.x, c3.y, c3.zoom], 'closed: the island answers again').not.toEqual([c2.x, c2.y, c2.zoom]);
});

test('the tutorial and a level banner give way to a panel and come back', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('tutorial_start');
  await game.page.waitForTimeout(400);
  expect((await game.query('layers')).tutorial_shown, 'the tutorial shows').toBe(true);
  await hudTap(game, 'research');
  let L = await game.query('layers');
  expect(L.tutorial_shown, 'not over the panel').toBe(false);
  // A level that opens buildings, reached while the panel is open.
  await game.query('dev_level', 2);
  await game.page.waitForTimeout(300);
  L = await game.query('layers');
  expect(L.banner, 'the banner waits').toBe(false);
  expect(L.pending_banner, 'for the panel to close').toBeGreaterThan(0);
  await shot(game, info, 'research_level_up_waits');
  await closeAll(game);
  L = await game.query('layers');
  expect(L.busy).toBe(false);
  expect(L.banner, 'closed: the banner shows').toBe(true);
  expect(L.tutorial_shown, 'and the tutorial is back').toBe(true);
  expect(L.fx_layer, "the world's effects are on the world's canvas").toBeLessThan(L.ui_layer);
  await shot(game, info, 'banner_after_close');
});
