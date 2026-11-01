// Step 85: the Schedule's stops worked adaptively, in the real web build.
// Four farms tapped crosswise with the real Schedule button (a finger on
// phones, the mouse on desktop): numbered 1-4 as a priority; as game time
// runs the Momo works them without once changing its destination on the way,
// and does more stages than the same island on the strict order (the route
// control's `strict`) -- with less walking. A stop that is not ready (a mine
// settling) while another has work: the Momo works the farm first and comes
// to the mine when it is ready. With MOMONIUM_SHOTS set, frames of each.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas } from '../lib/coords.mjs';

test.use({ starterMomo: true });
test.describe.configure({ timeout: 300_000 });

const toCss = async (game, p, win) => {
  const box = await game.canvas.boundingBox();
  return { x: p[0] * (box.width / win[0]), y: p[1] * (box.height / win[1]) };
};
const centre = (r) => [r[0] + r[2] / 2, r[1] + r[3] / 2];
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

// The real Schedule: the Momo, its button, the tiles, the button again.
async function schedule(game, cells) {
  const m = await game.query('momos');
  await tapAt(game, m.momos['1'].body, m.window);
  let w = await game.query('watch');
  await tapAt(game, centre(w.schedule), w.window);
  for (const c of cells) await tapCell(game, c);
  w = await game.query('watch');
  await tapAt(game, centre(w.schedule), w.window);
  return game.query('watch');
}

// Plays `minutes` of game time in steps; counts the Momo's walking and any
// change of destination while it walks.
async function play(game, minutes, shots, info, label) {
  let walking = 0;
  let retargets = 0;
  let last = null;
  const steps = Math.round((minutes * 60000) / 1000);
  for (let i = 0; i < steps; i++) {
    await game.query('dev_advance_ms', 1000);
    const s = await game.state();
    const m = s.momo.momos.find((x) => x.id === 1);
    const moving = s.now_ms < m.end;
    if (moving) walking++;
    if (last && last.moving && moving && last.assigned !== m.assigned) retargets++;
    last = { moving, assigned: m.assigned };
    if (shots && i % 15 === 0 && process.env.MOMONIUM_SHOTS) await game.page.screenshot({ path: `${process.env.MOMONIUM_SHOTS}/routes85_${info.project.name}_${label}_${String(i).padStart(3, '0')}.png` });
  }
  return { walking, retargets, s: await game.state() };
}

async function island(game) {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_set_option', ['tips', false]);
  await game.query('dev_grow_island', 6);
  const ids = [];
  for (const c of [[0, 0], [5, 5], [5, 0], [0, 5]]) ids.push((await game.query('dev_place_building', ['farm', c[0], c[1]])).id);
  await game.page.waitForTimeout(300);
  return ids;
}

// Stages the Momo started, counted on the bus by the bridge's own state:
// each farm's `completed` grows by one per stage.
const completed = (s, ids) => s.buildings.buildings.filter((b) => ids.includes(b.id)).reduce((n, b) => n + b.completed, 0);

for (const route of ['order', 'strict']) {
  test(`four farms tapped crosswise, the real Schedule button: ${route}`, async ({ game }, info) => {
    const ids = await island(game);
    const w = await schedule(game, [[0, 0], [5, 5], [5, 0], [0, 5]]);
    expect(w.route, 'the Schedule\'s own route').toBe('order');
    expect(w.stops.map(([id, n]) => [id, n]), 'numbered as tapped: a priority').toEqual([[ids[0], 1], [ids[1], 2], [ids[2], 3], [ids[3], 4]]);
    if (route === 'strict') expect((await game.command({ type: 'momo.route', momo: 1, route: 'strict' })).ok).toBe(true);
    const before = completed(await game.state(), ids);
    const r = await play(game, 6, true, info, route);
    const stages = completed(r.s, ids) - before;
    console.log(`routes85 ${info.project.name} ${route}: ${stages} stages in 6 game minutes, walking ${r.walking} s, retargets ${r.retargets}`);
    expect(r.retargets, 'never a new destination on the way').toBe(0);
    expect(stages, 'the farms are worked').toBeGreaterThan(10);
  });
}

test('the adaptive route does more on the same island than the strict order', async ({ game }, info) => {
  // Each route on its own fresh browser (nothing saved carries over), the
  // same island, the same stroke, the same game time.
  const runs = {};
  for (const route of ['order', 'strict']) {
    const ctx = await game.page.context().browser().newContext(info.project.use);
    const page = await ctx.newPage();
    await page.addInitScript(() => { window.MOMONIUM_E2E = true; });
    await page.goto(info.project.use.baseURL || './');
    await page.waitForFunction(() => window.momonium && window.momonium.ready && typeof window.momonium.state === 'function', null, { timeout: 90_000 });
    await page.waitForTimeout(500);
    const g = {
      page, canvas: page.locator('canvas'),
      state: () => page.evaluate(() => window.momonium.state()),
      command: (c) => page.evaluate((cmd) => window.momonium.command(cmd), c),
      query: (n, a) => page.evaluate(([x, y]) => window.momonium.call(x, y), [n, a]),
      setTimeScale: (x) => page.evaluate((v) => window.momonium.setTimeScale(v), x),
    };
    const momo = (await g.query('dev_add_momo', [0.55, 1.35])).id;
    const ids = await island(g);
    expect(ids.every((id) => id > 0), 'four farms placed').toBe(true);
    expect((await g.command({ type: 'momo.watch', momo, cells: [[0, 0], [5, 5], [5, 0], [0, 5]], op: 'add', schedule: true })).ok).toBe(true);
    if (route === 'strict') expect((await g.command({ type: 'momo.route', momo, route: 'strict' })).ok).toBe(true);
    const before = completed(await g.state(), ids);
    let walking = 0;
    let retargets = 0;
    let last = null;
    for (let i = 0; i < 480; i++) {
      await g.query('dev_advance_ms', 1000);
      const st = await g.state();
      const m = st.momo.momos.find((x) => x.id === momo);
      const moving = st.now_ms < m.end;
      if (moving) walking++;
      if (last && last.moving && moving && last.assigned !== m.assigned) retargets++;
      last = { moving, assigned: m.assigned };
    }
    runs[route] = { stages: completed(await g.state(), ids) - before, walking, retargets };
    await ctx.close();
  }
  console.log(`routes85 ${info.project.name}: adaptive ${JSON.stringify(runs.order)} | strict ${JSON.stringify(runs.strict)}`);
  expect(runs.strict.stages, 'the strict order works too').toBeGreaterThan(10);
  expect(runs.order.retargets).toBe(0);
  expect(runs.order.stages, 'more stages than the strict order').toBeGreaterThan(runs.strict.stages);
  expect(runs.order.walking, 'with less walking').toBeLessThan(runs.strict.walking);
});

test('a stop that is not ready: useful work elsewhere first, then the stop when ready', async ({ game }) => {
  await game.setTimeScale(0);
  await game.query('set_language', 'en');
  await game.query('dev_grow_island', 6);
  const mine = (await game.query('dev_place_building', ['mine', 5, 5])).id;
  const farm = (await game.query('dev_place_building', ['farm', 1, 1])).id;
  // The mine dug by hand: it settles for 10 s.
  expect((await game.command({ type: 'building.tap', id: mine })).ok).toBe(true);
  let s = await game.state();
  await game.query('dev_advance_ms', s.buildings.buildings.find((b) => b.id === mine).task_end - s.now_ms + 10);
  s = await game.state();
  expect(s.buildings.buildings.find((b) => b.id === mine).state, 'the mine settles').toBe('cooldown');
  expect((await game.command({ type: 'momo.watch', momo: 1, cells: [[5, 5], [1, 1]], op: 'add', schedule: true })).ok).toBe(true);
  const first = (await game.state()).momo.momos.find((m) => m.id === 1).assigned;
  expect(first, 'off to the farm that has work, not to wait at stop 1').toBe(farm);
  const worked = [];
  for (let i = 0; i < 120 && !worked.includes(mine); i++) {
    await game.query('dev_advance_ms', 1000);
    s = await game.state();
    for (const b of s.buildings.buildings) if (b.state === 'working' && b.worker === 1 && worked[worked.length - 1] !== b.id) worked.push(b.id);
  }
  expect(worked[0], 'the farm first').toBe(farm);
  expect(worked.includes(mine), `then the mine when it is ready: ${worked}`).toBe(true);
});
