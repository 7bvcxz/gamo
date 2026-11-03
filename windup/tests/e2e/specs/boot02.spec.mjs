// Step 02: the web build boots through the shared runner, keeps the address's
// options, draws, takes the key from a click, a tap and Space, and stops its
// clock while paused. Screenshots go to windup/evidence/step02/.
import { test, expect } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import { openGame, state, call, events, keyPoint } from '../lib/game.mjs';

const evidence = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../evidence/step02');

test('boots, keeps options, winds, pauses', async ({ page }, info) => {
  const version = fs.readFileSync(path.resolve(evidence, '../../project.godot'), 'utf8').match(/config\/version="([^"]+)"/)[1];
  const { errors } = await openGame(page, '?fresh=1&seed=7');
  const s0 = await state(page);
  expect(s0.version).toBe(version);
  expect(s0.config.seed).toBe(7);
  expect(s0.config.fresh).toBe(true);
  expect(s0.session).toBe(1);
  expect(page.url()).not.toContain('pack=');   // the runner tidied the address
  fs.mkdirSync(evidence, { recursive: true });
  await page.screenshot({ path: path.join(evidence, `web_startup_${info.project.name}.png`) });

  const k = await keyPoint(page);
  if (info.project.use.hasTouch) await page.touchscreen.tap(k.x, k.y);
  else await page.mouse.click(k.x, k.y);
  await expect.poll(async () => (await state(page)).winds).toBe(1);
  await page.mouse.click(5, 5);                 // off the key: nothing
  await page.keyboard.press('Space');
  await expect.poll(async () => (await state(page)).winds).toBe(2);
  const ev = await events(page);
  expect(ev[0].ev).toBe('session_start');
  expect(ev.filter((e) => e.ev === 'wind').map((e) => e.source)).toEqual([info.project.use.hasTouch ? 'click' : 'click', 'key']);

  await call(page, 'dev_pause', ['manual', true]);
  const t = (await state(page)).t;
  await page.waitForTimeout(600);
  expect((await state(page)).t).toBe(t);
  await call(page, 'dev_pause', ['manual', false]);
  await page.waitForTimeout(300);
  expect((await state(page)).t).toBeGreaterThan(t);
  await page.screenshot({ path: path.join(evidence, `web_after_winds_${info.project.name}.png`) });
  expect(errors).toEqual([]);
});
