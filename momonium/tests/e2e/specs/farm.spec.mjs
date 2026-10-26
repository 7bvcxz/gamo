// Step 14, Step 50: real taps run the whole farm -- sow, water, the short
// wait while the crop ripens, harvest -- and the harvest is money at once:
// sold the moment it is picked (no crop waits in the store for dawn); a tap
// during the wait is refused.
import { test, expect } from '../lib/fixtures.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

test('sow, water, harvest: paid at once', async ({ game }) => {
  await game.setTimeScale(0);
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  const tapFarm = async () => { const p = await clearPointOnCell(game, [1, 0]); await game.tap(p.x, p.y); };
  const b = async () => (await game.state()).buildings.buildings.find((x) => x.id === id);
  // Game time is moved exactly to where the stage (and its wait) ends: no
  // real-time polling at high speed.
  const waitIdle = async () => {
    for (let i = 0; i < 4 && (await b()).state !== 'idle'; i++) {
      const s = await game.state();
      const f = s.buildings.buildings.find((x) => x.id === id);
      const end = f.state === 'working' ? f.task_end : f.ready_at;
      await game.query('dev_advance_ms', Math.max(end - s.now_ms, 0) + 5);
    }
    expect((await b()).state).toBe('idle');
  };
  const money0 = (await game.state()).economy.money;
  await tapFarm();
  expect((await b()).state).toBe('working');
  await waitIdle();
  await tapFarm();
  {
    const s = await game.state();
    const f = s.buildings.buildings.find((x) => x.id === id);
    await game.query('dev_advance_ms', f.task_end - s.now_ms + 5);
  }
  expect((await b()).state).toBe('cooldown');
  await tapFarm();
  expect((await game.query('selection')).result.reason).toBe('err.cooldown');
  await waitIdle();
  expect((await b()).stage).toBe(2);
  await tapFarm();
  await waitIdle();
  const s = await game.state();
  expect(s.inventory.items.crop || 0).toBe(0);
  expect(s.economy.money).toBeGreaterThan(money0);
  expect((await b()).stage).toBe(0);
});
