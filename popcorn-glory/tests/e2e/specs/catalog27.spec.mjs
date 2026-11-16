// Step 27: the forty-machine sheet (#machines, not on the chooser) draws on every screen without errors.
import { test, expect } from '../lib/pop.mjs';

test('the machine catalog sheet draws on this screen', async ({ pop }) => {
  await pop.open('./#machines');
  const s = await pop.state();
  expect(s.exp).toBe('machines');
  expect(s.listed.includes('machines'), 'not on the chooser').toBe(false);
  await pop.page.waitForTimeout(600);
  await pop.shot('catalog27');
  expect(pop.errors).toEqual([]);
});
