// Step 86: the Fun Lab's web build -- a launcher with six tiles, an
// experiment opened by a finger or the mouse, its direct link kept through a
// reload and the browser's back button, Restart from nothing, play time that
// stops in a hidden tab or an unfocused window, the local report as a real
// download, and the game's own save untouched by any of it.
// FUNLAB_SHOTS=<dir> keeps a screenshot of each screen.
import { test, expect, INIT, wrap } from '../lib/lab.mjs';

test('the launcher: six tiles with PLAY or SOON, all on screen', async ({ lab }) => {
  await lab.open('./');
  const s = await lab.state();
  expect(s.screen).toBe('launcher');
  expect(Object.keys(s.tiles).sort()).toEqual(['evolution', 'harvest', 'island', 'rock', 'tree', 'tycoon']);
  for (const [id, r] of Object.entries(s.tiles)) {
    expect(r[0] >= 0 && r[1] >= 0 && r[0] + r[2] <= s.window[0] + 0.5 && r[1] + r[3] <= s.window[1] + 0.5, `${id}'s tile is on screen ${r}`).toBe(true);
  }
  const v = await lab.page.evaluate(() => fetch('version.json', { cache: 'no-store' }).then((r) => r.json()));
  expect(s.version, 'the build version.json names').toBe(v.version);
  await lab.shot('funlab86_launcher');
});

test('a tile opens its experiment, Back comes home, a direct link survives a reload and the back button', async ({ lab }) => {
  await lab.open('./');
  let s = await lab.state();
  await lab.tapRect(s.tiles.island);
  s = await lab.state();
  expect(s.screen, 'the tile opened an experiment').toBe('experiment');
  expect(s.route).toBe('island');
  expect(await lab.hash(), 'its direct link is in the address').toBe('#island');
  await lab.shot('funlab86_island_stub');
  await lab.tapRect(s.host.rects.back);
  s = await lab.state();
  expect(s.screen, 'Back').toBe('launcher');
  expect(await lab.hash()).toBe('');

  await lab.open('./#rock');
  expect((await lab.state()).route, 'a direct link opens the experiment').toBe('rock');
  await lab.page.reload();
  await lab.ready();
  expect((await lab.state()).route, 'and a reload keeps it').toBe('rock');
  // The browser's own back and forward (a page load or a hash change: either way).
  const now = async (k) => { try { return (await lab.state())[k]; } catch { return null; } };
  await lab.page.goBack();
  await expect.poll(() => now('screen'), { timeout: 30_000 }).toBe('launcher');
  await lab.page.goForward();
  await expect.poll(() => now('route'), { timeout: 30_000 }).toBe('rock');
});

test('Restart starts from nothing; one finger or click is one press', async ({ lab }) => {
  await lab.open('./#stub');
  await lab.call('dev_advance', 30);
  let s = await lab.state();
  expect(s.host.experiment.coins).toBeGreaterThanOrEqual(30);
  await lab.tapRect(s.host.rects.action);
  s = await lab.state();
  expect(s.host.session.actions_by_kind.button, 'one tap, one press').toBe(1);
  expect(s.host.experiment.level, 'one upgrade').toBe(1);
  await lab.tapRect(s.host.rects.restart);
  s = await lab.state();
  expect(s.host.runs, 'a second run').toBe(2);
  expect(s.host.experiment.level, 'from level 0').toBe(0);
  expect(s.host.experiment.coins, 'no coins carried over').toBeLessThan(2);
  expect(s.host.finished, 'the first run kept in the visit').toBe(1);
});

test('a hidden tab or an unfocused window stops play time; nothing is caught up', async ({ lab }) => {
  await lab.open('./#tree');
  await lab.page.waitForTimeout(1000);
  let s = await lab.state();
  const t0 = s.host.session.active_seconds;
  expect(t0, 'play time runs while visible').toBeGreaterThan(0.3);
  await lab.tab(true);
  s = await lab.state();
  const hiddenAt = s.host.session.active_seconds;
  expect(s.host.paused).toBe(true);
  await lab.page.waitForTimeout(4000);
  await lab.tab(false);
  await lab.page.waitForTimeout(300);
  s = await lab.state();
  expect(s.host.paused, 'running again').toBe(false);
  const gained = s.host.session.active_seconds - hiddenAt;
  expect(gained, `4 s hidden added ${gained} s`).toBeLessThan(1.2);

  await lab.blur();
  s = await lab.state();
  expect(s.host.paused, 'an unfocused window pauses').toBe(true);
  const blurredAt = s.host.session.active_seconds;
  await lab.page.waitForTimeout(2000);
  expect((await lab.state()).host.session.active_seconds, 'and stays put').toBe(blurredAt);
  await lab.shot('funlab86_paused');
  await lab.tapCss(100, 400);
  s = await lab.state();
  expect(s.host.paused, 'a tap on the paused card resumes').toBe(false);
  expect(s.host.session.pauses, 'both pauses recorded').toBe(2);
});

test('dev mode: the play clock and the run report as a real download', async ({ lab }) => {
  await lab.open('./?dev=1#stub');
  await lab.call('dev_advance', 12);
  let s = await lab.state();
  expect(s.dev).toBe(true);
  expect(s.host.rects.report, 'the report button shows in dev mode').toBeTruthy();
  await lab.tapRect(s.host.rects.report);
  s = await lab.state();
  expect(s.host.rects.report_json, 'the report is open').toBeTruthy();
  await lab.shot('funlab86_report');
  const [json] = await Promise.all([lab.page.waitForEvent('download'), lab.tapRect(s.host.rects.report_json)]);
  expect(json.suggestedFilename()).toMatch(/^funlab-stub-.*\.json$/);
  const data = JSON.parse(await (await json.createReadStream()).toArray().then((c) => Buffer.concat(c).toString()));
  expect(data.experiment).toBe('stub');
  expect(data.active_seconds).toBeGreaterThanOrEqual(12);
  const [csv] = await Promise.all([lab.page.waitForEvent('download'), lab.tapRect(s.host.rects.report_csv)]);
  const text = await (await csv.createReadStream()).toArray().then((c) => Buffer.concat(c).toString());
  expect(text.split('\n')[0]).toBe('t_seconds,kind,detail');
});

test('without dev mode the hooks that change a run are closed', async ({ page }, info) => {
  const lab = wrap(page, info);
  await page.goto('./#stub');
  await lab.ready();
  expect((await lab.state()).host.rects.report, 'no report button').toBeFalsy();
  const r = await lab.call('dev_advance', 30);
  expect(r.ok, 'dev hooks need ?dev=1').toBe(false);
  expect(lab.errors).toEqual([]);
});

// Godot keeps user:// in the page's IndexedDB ('/userfs'), one database for
// the whole origin -- the game's and the Lab's folders side by side.
async function userfs(page) {
  return page.evaluate(() => new Promise((resolve) => {
    const req = indexedDB.open('/userfs');
    req.onerror = () => resolve({});
    req.onsuccess = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains('FILE_DATA')) { db.close(); resolve({}); return; }
      const out = {};
      const cur = db.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA').openCursor();
      cur.onsuccess = (e) => {
        const c = e.target.result;
        if (!c) { db.close(); resolve(out); return; }
        const bytes = c.value && c.value.contents ? new Uint8Array(c.value.contents) : null;
        let sum = 0;
        if (bytes) for (let i = 0; i < bytes.length; i++) sum = (sum * 31 + bytes[i]) >>> 0;
        out[c.key] = bytes ? `${bytes.length}:${sum}` : 'dir';
        c.continue();
      };
    };
  }));
}

test("the game's save and settings are never touched", async ({ page }, info) => {
  // The game first, in the same browser: it saves.
  const game = await page.context().newPage();
  await game.addInitScript(() => { window.MOMONIUM_E2E = true; });
  await game.goto('../momonium/');
  await game.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.call === 'function', null, { timeout: 90_000 });
  await game.waitForTimeout(1000);
  const saved = await game.evaluate(() => window.momonium.call('save_now', null));
  expect(saved.err, 'the game saved').toBe(0);
  await expect.poll(async () => Object.keys(await userfs(game)).some((k) => k.endsWith('/Momonium/momonium_save.json')), { timeout: 20_000 }).toBe(true);
  await game.waitForTimeout(1500);
  // The game saves once more on the way out (pagehide), so the picture is
  // taken after it has gone, from a plain page of the same origin.
  await game.close();
  await page.goto('version.json');
  await page.waitForTimeout(500);
  const before = await userfs(page);
  const local = () => { const o = {}; for (let i = 0; i < localStorage.length; i++) { const k = localStorage.key(i); o[k] = localStorage.getItem(k); } return o; };
  const storageBefore = await page.evaluate(local);
  expect(Object.keys(storageBefore), "the game's localStorage mirror is there").toContain('momonium_save');

  // Then the Lab: every experiment, an action, a restart, back home.
  await page.addInitScript(INIT);
  const lab = wrap(page, info);
  await lab.open('./');
  for (const id of ['island', 'rock', 'tree', 'evolution']) {
    await lab.call('dev_open', id);
    await lab.call('dev_advance', 40);
    await lab.call('dev_action', null);
    await lab.call('dev_restart', null);
    await lab.call('dev_back', null);
  }
  await page.waitForTimeout(2500);
  const after = await userfs(page);
  const game_keys = Object.keys(before).filter((k) => k.includes('/Momonium/'));
  expect(game_keys.some((k) => k.endsWith('/momonium_save.json')), `the game's save is there: ${game_keys}`).toBe(true);
  for (const k of game_keys) expect(after[k], `${k} unchanged`).toBe(before[k]);
  const added = Object.keys(after).filter((k) => !(k in before));
  expect(added.filter((k) => !k.includes('/app_userdata/Momonium Fun Lab')), `the Lab wrote nothing outside its own folder: ${added}`).toEqual([]);
  // In its own folder only the engine's shader cache (Godot writes one for
  // every web game): no file of the Lab's.
  const own = added.filter((k) => after[k] !== 'dir' && !k.includes('/shader_cache/'));
  expect(own, `no Lab file: ${own}`).toEqual([]);
  expect(await page.evaluate(local), "localStorage (the game's save mirror) unchanged").toEqual(storageBefore);
  console.log(`funlab86 ${info.project.name}: game keys ${game_keys.length} unchanged; the Lab added ${added.length} (${added.filter((k) => after[k] !== 'dir').length} engine cache files)`);
  expect(lab.errors).toEqual([]);
});
