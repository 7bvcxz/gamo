// Step 04: the exported build carries the sprite atlas, its metadata and pivots.
import { readFileSync } from 'node:fs';
import { test, expect } from '../lib/fixtures.mjs';

const atlas = JSON.parse(readFileSync(new URL('../../../assets/atlas/sprites.json', import.meta.url), 'utf8'));

test('atlas and pivots load in the browser', async ({ game }) => {
  const info = await game.query('art_info');
  expect(info.sprites).toBe(Object.keys(atlas.sprites).length);
  expect(info.size).toEqual(atlas.size);
  expect(info.texture).toEqual(atlas.size);
  expect(info.momo_origin).toEqual(atlas.sprites.momo_front.pivots.origin);
});
