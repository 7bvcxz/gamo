// Evidence, not a check: real web screenshots (phone and desktop) of a few
// fixed scenes, for the before/after sheets in the design notes. Runs only
// with MOMONIUM_SHOTS=<directory>; point MOMONIUM_E2E_BASE at the public build
// to shoot what players get (before a release: the old one).
//   MOMONIUM_SHOTS=/abs/dir MOMONIUM_E2E_BASE=https://7bvcxz.github.io/gamo/momonium/ \
//     npx playwright test specs/shots.spec.mjs
import fs from 'node:fs';
import path from 'node:path';
import { test } from '../lib/fixtures.mjs';

const dir = process.env.MOMONIUM_SHOTS;
test.skip(!dir, 'evidence shots only on request (MOMONIUM_SHOTS)');

async function save(game, info, scene, label) {
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, `${scene}_${info.project.name}_${label}.png`);
  await game.page.screenshot({ path: file });
}

// Queries a build may not have yet (an old build for the "before" shots).
async function maybe(game, name, arg) {
  try {
    return await game.query(name, arg);
  } catch {
    return null;
  }
}

test('hud: at rest, a gain, a level gained', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.page.waitForTimeout(600);
  await save(game, info, 'hud', 'rest');
  await game.query('dev_add_money', 25);
  await game.page.waitForTimeout(450);
  await save(game, info, 'hud', 'reward');
  await game.page.waitForTimeout(1500);
  const r = await maybe(game, 'dev_add_exp', 0);
  if (r && r.next) {
    await game.query('dev_add_exp', r.next - r.exp + 5);
    await game.page.waitForTimeout(450);
    await save(game, info, 'hud', 'levelup');
  }
});

test('depth: Momo around a lab', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  let at = null;
  for (const c of [[1, 1], [0, 1], [1, 0], [0, 0]]) {
    if ((await game.query('dev_place_building', ['research', ...c])).id) {
      at = c;
      break;
    }
  }
  const cx = at[0] + 0.5;
  const cy = at[1] + 0.5;
  for (const d of [[0.62, 0.62], [-0.55, 0.62], [0.62, -0.55], [0.18, -0.45], [-0.45, 0.18], [-0.9, -0.9]]) {
    await game.query('dev_add_momo', [cx + d[0], cy + d[1]]);
  }
  if (!info.project.use.hasTouch) {
    const p = await game.query('logical_screen', [cx, cy, 0]);
    const box = await game.canvas.boundingBox();
    await game.page.mouse.move(box.x + p.x * (box.width / p.window[0]), box.y + p.y * (box.height / p.window[1]));
    for (let i = 0; i < 4; i++) {
      await game.page.mouse.wheel(0, -240);
      await game.page.waitForTimeout(120);
    }
  }
  await game.page.waitForTimeout(800);
  await save(game, info, 'depth', 'lab');
});

test('time of day: day, sunset, night', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  for (const [label, t] of [['day', 0.3], ['sunset', 0.62], ['night', 0.86]]) {
    await game.query('dev_advance_to', [1, t]);
    await game.page.waitForTimeout(500);
    await save(game, info, 'time', label);
  }
});

// Step 57: a letter arrives (the HUD, the Momo who wrote it), the mailbox,
// the letter, and Research -- without accepting anything.
test('mail: a letter arrives, the letter, research', async ({ game }, info) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  const momo = (await game.query('dev_add_momo', [0.55, 1.35])).id;
  let farm = 0;
  for (const c of [[1, 0], [0, 1], [1, 1]]) {
    farm = (await game.query('dev_place_building', ['farm', ...c])).id;
    if (farm) break;
  }
  await game.command({ type: 'momo.assign', momo, building: farm });
  for (let i = 0; i < 80 && (await game.query('mail')).unread === 0; i++) await game.query('dev_advance_ms', 2500);
  await game.page.waitForTimeout(350);
  await save(game, info, 'mail', 'arrive');
  const tap = async (r, win) => {
    const box = await game.canvas.boundingBox();
    await game.tap((r[0] + r[2] / 2) * (box.width / win[0]), (r[1] + r[3] / 2) * (box.height / win[1]));
    await game.page.waitForTimeout(400);
  };
  let h = await game.query('hud');
  await tap(h.buttons.mailbox, h.window);
  await save(game, info, 'mail', 'list');
  const m = await game.query('mail');
  await tap(m.rows[0].rect, m.window);
  await save(game, info, 'mail', 'letter');
  await tap(h.buttons.mailbox, h.window);
  h = await game.query('hud');
  await tap(h.buttons.research, h.window);
  await save(game, info, 'mail', 'research');
});
