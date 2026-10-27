// Step 66: in the real web build a Momo at work holds the tool of its job --
// the seed pouch, the watering can and the basket at a farm, the pickaxe at
// a mine, the axe and the trowel at a lumberyard, the flask at a lab -- drawn
// from the work atlas (not the 5x5 sheet), its pixels on screen; off work it
// is back on the sheet.
import { test, expect } from '../lib/fixtures.mjs';

test.use({ starterMomo: true });

const momo = async (game) => (await game.query('momos')).momos['1'];

async function drawn(game, m) {
  const box = await game.canvas.boundingBox();
  const win = (await game.query('momos')).window;
  const sx = box.width / win[0];
  const sy = box.height / win[1];
  const clip = { x: box.x + (m.body[0] - 40) * sx, y: box.y + (m.body[1] - 55) * sy, width: 80 * sx, height: 100 * sy };
  const png = await game.page.screenshot({ clip });
  return game.page.evaluate(async (b64) => {
    const img = new Image();
    img.src = 'data:image/png;base64,' + b64;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const g = c.getContext('2d');
    g.drawImage(img, 0, 0);
    const d = g.getImageData(0, 0, c.width, c.height).data;
    let cream = 0, outline = 0;
    for (let i = 0; i < d.length; i += 4) {
      const [r, gg, b] = [d[i], d[i + 1], d[i + 2]];
      if (r > 225 && gg > 215 && b > 195 && r >= b) cream++;
      if (r < 110 && gg < 80 && b < 70) outline++;
    }
    return { cream: cream / (d.length / 4), outline };
  }, png.toString('base64'));
}

test('every job shows its tool from the work atlas', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('dev_grow_island', 3);
  // The job each stage shows (Step 67: its frames are <job>_0 .. _3).
  const want = {
    farm: ['sow', 'water', 'harvest'],
    mine: ['dig'],
    lumberyard: ['chop', 'replant'],
    research: ['study'],
  };
  const spots = { farm: [2, 0], mine: [2, 1], lumberyard: [2, 2], research: [1, 2] };
  for (const [type, cells] of Object.entries(want)) {
    // Each job from a morning: at night the island is tinted dark blue and
    // the fur is not light enough to count.
    const { day } = await game.query('dev_advance_ms', 0);
    await game.query('dev_advance_to', [day + 1, 0.05]);
    const { id } = await game.query('dev_place_building', [type, ...spots[type]]);
    expect(id, `${type} placed`).toBeGreaterThan(0);
    expect((await game.command({ type: 'momo.assign', momo: 1, building: id })).ok).toBe(true);
    const seen = new Set();
    let m;
    for (let i = 0; i < 400 && seen.size < cells.length; i++) {
      await game.query('dev_advance_ms', 400);
      m = await momo(game);
      const job = String(m.cell).replace(/_[0-3]$/, '');
      if (m.state === 'work' && !seen.has(job)) {
        expect(m.cell, 'a frame of the job').toMatch(/_[0-3]$/);
        seen.add(job);
        await game.page.waitForTimeout(80);
        m = await momo(game);
        expect(m.sheet, `${m.cell}: drawn from the work atlas`).toEqual([1024, 720]);
        const px = await drawn(game, m);
        expect(px.cream, `${m.cell}: Momo's fur on screen`).toBeGreaterThan(0.06);
        expect(px.outline, `${m.cell}: and its outline`).toBeGreaterThan(10);
      }
    }
    expect([...seen].sort(), `${type}: every stage with its tool`).toEqual([...cells].sort());
    expect((await game.command({ type: 'momo.unassign', momo: 1 })).ok).toBe(true);
    await game.query('dev_advance_ms', 200);
    m = await momo(game);
    expect(m.state).not.toBe('work');
    expect(m.sheet, 'off work: back on the sheet').toEqual([1280, 1280]);
  }
});
