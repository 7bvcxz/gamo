// Step 03: a save written to the browser's user:// storage reads back as the
// same world (JSON, IndexedDB and the loader all agree on the web build).
import { test, expect } from '../lib/fixtures.mjs';

test('save round trip through browser storage', async ({ game }) => {
  await game.setTimeScale(30);
  await expect.poll(async () => (await game.state()).now_ms, { timeout: 10_000 }).toBeGreaterThan(5_000);
  await game.setTimeScale(0);
  const result = await game.query('save_roundtrip');
  expect(result.write).toBe(0);
  expect(result.equal).toBe(true);
  expect(result.now_ms).toBeGreaterThan(5_000);
});
