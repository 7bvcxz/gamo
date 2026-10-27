// Step 60: a selected Momo shows one small Schedule button under its feet --
// no card, no Assign / Release / Info / Edit. Schedule turns Schedule mode on
// (the button fills, a count shows, the tiles it could take are outlined);
// a tap toggles a tile, a stroke paints; Schedule again, the sea or another
// Momo ends it. A newly hired Momo scheduled onto a farm really works it, and
// its work can be cleared and given elsewhere without any panel. Phone (also
// at the 720x1280 baseline) and desktop, real taps and strokes.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

const toCss = async (game, p, win) => {
  const box = await game.canvas.boundingBox();
  return { x: p[0] * (box.width / win[0]), y: p[1] * (box.height / win[1]) };
};
const centre = (r) => [r[0] + r[2] / 2, r[1] + r[3] / 2];
const overlaps = (a, b) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];
const watchOf = async (game, id) => (await game.state()).momo.momos.find((m) => m.id === id).watch.map((c) => c.join(',')).sort();

async function tapAt(game, p, win) {
  const c = await toCss(game, p, win);
  await game.tap(c.x, c.y);
  await game.page.waitForTimeout(250);
}

async function tapCell(game, cell) {
  const c = await cellToCanvas(game, cell);
  await game.tap(c.x, c.y);
  await game.page.waitForTimeout(250);
}

async function stroke(game, cells, touch) {
  const pts = [];
  for (const c of cells) pts.push(await cellToCanvas(game, c));
  const box = await game.canvas.boundingBox();
  if (touch) {
    const s = await game.page.context().newCDPSession(game.page);
    const at = (p) => ({ x: box.x + p.x, y: box.y + p.y, id: 0, radiusX: 2, radiusY: 2, force: 1 });
    await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [at(pts[0])] });
    for (let i = 1; i < pts.length; i++) {
      for (let k = 1; k <= 8; k++) {
        const p = { x: pts[i - 1].x + ((pts[i].x - pts[i - 1].x) * k) / 8, y: pts[i - 1].y + ((pts[i].y - pts[i - 1].y) * k) / 8 };
        await s.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [at(p)] });
        await game.page.waitForTimeout(16);
      }
    }
    await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  } else {
    await game.page.mouse.move(box.x + pts[0].x, box.y + pts[0].y);
    await game.page.mouse.down();
    for (let i = 1; i < pts.length; i++) await game.page.mouse.move(box.x + pts[i].x, box.y + pts[i].y, { steps: 8 });
    await game.page.mouse.up();
  }
  await game.page.waitForTimeout(250);
}

async function selectMomo(game, id) {
  const m = await game.query('momos');
  await tapAt(game, m.momos[String(id)].body, m.window);
}

for (const shape of ['default', '720x1280']) {
  test.describe(shape, () => {
    test.use({ starterMomo: true });
    if (shape === '720x1280') test.use({ viewport: { width: 360, height: 640 } });

    test('one Schedule button under the Momo; tap and paint its tiles', async ({ game }, info) => {
      test.skip(shape === '720x1280' && !info.project.use.hasTouch, 'the portrait baseline is a phone');
      const touch = info.project.use.hasTouch;
      await game.setTimeScale(0);
      await game.query('set_language', 'en');
      await game.query('dev_grow_island', 3);
      const { id: farm } = await game.query('dev_place_building', ['farm', 2, 0]);
      await game.page.waitForTimeout(300);
      await selectMomo(game, 1);
      let w = await game.query('watch');
      const m = await game.query('momos');
      expect(m.selected).toBe('momo');
      expect(w.momo).toBe(1);
      expect(w.schedule.length, 'one Schedule button').toBe(4);
      expect(w.name).toBe('Schedule');
      expect(w.editing).toBe(false);
      expect(w.pressed).toBe(false);
      // Under its feet (or, where that cannot fit, close by), never on the HUD.
      const feet = m.momos['1'].feet;
      if (w.side === 'below') {
        expect(Math.abs(w.schedule[0] + w.schedule[2] / 2 - feet[0]), 'centred under the feet').toBeLessThan(2);
        expect(w.schedule[1], 'below them').toBeGreaterThan(feet[1] - 1);
      }
      const hud = await game.query('hud');
      for (const [name, r] of Object.entries(hud.buttons)) expect(overlaps(w.schedule, r), `clear of ${name}`).toBe(false);
      expect(w.schedule[0]).toBeGreaterThanOrEqual(0);
      expect(w.schedule[1] + w.schedule[3]).toBeLessThanOrEqual(w.window[1]);
      await game.page.screenshot({ path: info.outputPath('selected.png') });
      // Schedule mode.
      await tapAt(game, centre(w.schedule), w.window);
      w = await game.query('watch');
      expect(w.editing).toBe(true);
      expect(w.pressed, 'the button says it is on').toBe(true);
      expect(w.count).toBe('0 / 4 tiles');
      expect(w.eligible.length, 'the island\'s tiles it could take are outlined').toBeGreaterThanOrEqual(8);
      // One tap toggles one tile.
      await tapCell(game, [0, 0]);
      expect(await watchOf(game, 1)).toEqual(['0,0']);
      await tapCell(game, [0, 0]);
      expect(await watchOf(game, 1)).toEqual([]);
      // A stroke paints; the camera stays.
      const cam = await game.query('camera');
      await stroke(game, [[0, 0], [0, 1], [1, 1]], touch);
      expect(await watchOf(game, 1)).toEqual(['0,0', '0,1', '1,1']);
      const cam2 = await game.query('camera');
      expect([cam2.x, cam2.y]).toEqual([cam.x, cam.y]);
      w = await game.query('watch');
      expect(w.count).toBe('3 / 4 tiles');
      expect(w.eligible.map((c) => c.join(','))).not.toContain('0,0');
      // The farm's tile: real work at once.
      await tapCell(game, [2, 0]);
      expect((await game.state()).momo.momos.find((x) => x.id === 1).assigned).toBe(farm);
      await game.page.screenshot({ path: info.outputPath('schedule.png') });
      // Schedule again: done.
      w = await game.query('watch');
      await tapAt(game, centre(w.schedule), w.window);
      w = await game.query('watch');
      expect(w.editing).toBe(false);
      expect(w.pressed).toBe(false);
    });
  });
}

test.describe('work', () => {
  test('a new hire scheduled onto a farm works; its work is cleared and given elsewhere', async ({ game }) => {
    await game.setTimeScale(0);
    await game.query('set_language', 'en');
    let a = 0;
    let b = 0;
    for (const c of [[1, 0], [0, 1], [1, 1]]) {
      const id = (await game.query('dev_place_building', ['farm', ...c])).id;
      if (id && !a) a = [id, c];
      else if (id && !b) b = [id, c];
    }
    expect(a && b, 'two farms').toBeTruthy();
    await game.query('dev_add_money', 100);
    const before = await game.state();
    expect(before.momo.momos.length, 'a new island: no Momo (Step 53)').toBe(0);
    // Hire (Step 59: the right edge): the new Momo is selected, Schedule under it.
    const hud = await game.query('hud');
    await tapAt(game, centre(hud.buttons.hire), hud.window);
    const ui = await game.query('build_ui');
    await tapAt(game, centre(ui.cards.momo), ui.window);
    let s = await game.state();
    expect(s.momo.momos.length).toBe(1);
    const id = s.momo.momos[0].id;
    expect(s.momo.momos[0].assigned, 'no work yet').toBe(0);
    let w = await game.query('watch');
    expect(w.momo, 'the hire is selected').toBe(id);
    await tapAt(game, centre(w.schedule), w.window);
    await tapCell(game, a[1]);
    expect(await watchOf(game, id)).toEqual([a[1].join(',')]);
    s = await game.state();
    expect(s.momo.momos[0].assigned, 'scheduled: it goes to the farm').toBe(a[0]);
    const done0 = s.buildings.buildings.find((x) => x.id === a[0]).completed;
    await game.query('dev_advance_ms', 60000);
    s = await game.state();
    expect(s.buildings.buildings.find((x) => x.id === a[0]).completed, 'and really works it').toBeGreaterThan(done0);
    // Clear it (tap its tile again) and give it the other farm.
    await tapCell(game, a[1]);
    expect(await watchOf(game, id)).toEqual([]);
    expect((await game.state()).momo.momos[0].assigned, 'cleared').toBe(0);
    await tapCell(game, b[1]);
    expect((await game.state()).momo.momos[0].assigned, 'given elsewhere').toBe(b[0]);
  });

});

test.describe('two Momo', () => {
  test.use({ starterMomo: true });
  test('another Momo tapped in Schedule mode is chosen; the sea ends it', async ({ game }) => {
    await game.setTimeScale(0);
    await game.query('set_language', 'en');
    await game.query('dev_grow_island', 3);
    const other = (await game.query('dev_add_momo', [2.5, 2.5])).id;
    await game.page.waitForTimeout(300);
    await selectMomo(game, 1);
    let w = await game.query('watch');
    await tapAt(game, centre(w.schedule), w.window);
    expect((await game.query('watch')).editing).toBe(true);
    await selectMomo(game, other);
    w = await game.query('watch');
    expect(w.momo, 'the other Momo').toBe(other);
    expect(w.editing, 'Schedule mode ended safely').toBe(false);
    expect(await watchOf(game, 1)).toEqual([]);
    await tapAt(game, centre(w.schedule), w.window);
    expect((await game.query('watch')).editing).toBe(true);
    // The sea just beyond the island's far edge (on screen).
    await tapCell(game, [1, -1]);
    expect((await game.query('watch')).editing, 'the sea ends it').toBe(false);
    expect((await game.state()).world.land.some(([x, y]) => x === 1 && y === -1), 'and buys nothing').toBe(false);
  });
});
