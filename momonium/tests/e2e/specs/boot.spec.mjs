// Step 02: the web build boots into the starting rules and runs one clock.
import { readFileSync } from 'node:fs';
import { test, expect } from '../lib/fixtures.mjs';

const projectVersion = readFileSync(new URL('../../../project.godot', import.meta.url), 'utf8').match(/config\/version="([^"]+)"/)[1];

test('boots into Day 1 with $10 and Level 1', async ({ game }) => {
  expect(await game.version()).toBe(projectVersion);
  const s = await game.state();
  expect(s.day).toBe(1);
  expect(s.economy.money).toBe(10);
  expect(s.progression.level).toBe(1);
  expect(s.progression.exp).toBe(0);
});

test('the day rolls over on the simulation clock', async ({ game }) => {
  await game.setTimeScale(20);
  await expect.poll(async () => (await game.state()).day, { timeout: 20_000 }).toBeGreaterThanOrEqual(2);
  await game.setTimeScale(1);
});
