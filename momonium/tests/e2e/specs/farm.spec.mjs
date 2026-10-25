// Step 14: real taps run the whole farm: sow, water three times with the
// 30-second waits in between, harvest; the harvest puts one batch of crops in
// the store; a tap during a wait is refused.
import { test, expect } from '../lib/fixtures.mjs';
import { clearPointOnCell } from '../lib/coords.mjs';

test('sow, water x3, harvest', async ({ game }) => {
  await game.setTimeScale(0);
  const { id } = await game.query('dev_place_building', ['farm', 1, 0]);
  const tapFarm = async () => { const p = await clearPointOnCell(game, [1, 0]); await game.tap(p.x, p.y); };
  const b = async () => (await game.state()).buildings.buildings.find((x) => x.id === id);
  const waitIdle = async () => {
    await game.setTimeScale(40);
    await expect.poll(async () => (await b()).state, { timeout: 15_000 }).toBe('idle');
    await game.setTimeScale(0);
  };
  await tapFarm();
  expect((await b()).state).toBe('working');
  await waitIdle();
  await tapFarm();
  await game.setTimeScale(40);
  await expect.poll(async () => (await b()).state, { timeout: 10_000 }).toBe('cooldown');
  await game.setTimeScale(0);
  await tapFarm();
  expect((await game.query('selection')).result.reason).toBe('err.cooldown');
  await waitIdle();
  for (let i = 0; i < 2; i++) {
    await tapFarm();
    await waitIdle();
  }
  expect((await b()).stage).toBe(4);
  await tapFarm();
  await waitIdle();
  const s = await game.state();
  expect(s.inventory.items.crop).toBe(1);
  expect((await b()).stage).toBe(0);
});
