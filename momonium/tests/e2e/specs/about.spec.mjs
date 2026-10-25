// Step 44: Settings says what the game is -- the build and the platform, a
// solo game with no account, server or leaderboard, saved in this browser.
import { test, expect } from '../lib/fixtures.mjs';

const centre = async (game, rect, win) => {
  const box = await game.canvas.boundingBox();
  return { x: (rect[0] + rect[2] / 2) * (box.width / win[0]), y: (rect[1] + rect[3] / 2) * (box.height / win[1]) };
};

test('about the game, in Settings', async ({ game }) => {
  await game.query('set_language', 'en');
  const hud = await game.query('hud');
  const gear = await centre(game, hud.buttons.settings, hud.window);
  await game.tap(gear.x, gear.y);
  await game.page.waitForTimeout(300);
  await game.query('dev_settings_reveal', 'About');
  await game.page.waitForTimeout(200);
  const st = await game.query('settings_ui');
  expect(st.about_rect.length).toBe(4);
  expect(st.about).toContain('no account, no server, no leaderboards');
  expect(st.about).toContain('Saved in this browser');
  expect(st.build).toBe(`v${await game.version()} · Web`);
  // The language buttons at the top of Settings, by a real tap.
  await game.query('dev_settings_reveal', 'Lang_ko');
  await game.page.waitForTimeout(200);
  const langs = (await game.query('settings_ui')).langs;
  const ko_button = await centre(game, langs.ko, st.window);
  await game.tap(ko_button.x, ko_button.y);
  await game.page.waitForTimeout(300);
  const ko = await game.query('settings_ui');
  expect(ko.locale).toBe('ko');
  expect(ko.about).toContain('계정·서버·순위표 없이');
  expect(ko.build).toContain('· 웹');
});
