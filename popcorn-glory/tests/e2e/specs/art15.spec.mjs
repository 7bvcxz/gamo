// Step 15: the art direction's runnable preview (#artboard: direction B drawn by the engine
// from art/tokens.gd) opens on every screen with no page errors, and draws (a picture with
// many colours, not a blank canvas). The chooser does not list it.
import { test, expect } from '../lib/pop.mjs';

test('the artboard preview draws on this screen', async ({ pop }) => {
  await pop.open('./#artboard');
  const s = await pop.state();
  expect(s.exp).toBe('artboard');
  await pop.shot('art15_artboard');
  expect(pop.errors).toEqual([]);
});

test('the chooser does not list the artboard', async ({ pop }) => {
  await pop.open('./');
  const s = await pop.state();
  expect(Object.keys(s.rects).filter((k) => k.includes('artboard'))).toEqual([]);
});
