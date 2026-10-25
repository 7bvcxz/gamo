// Step 06: the 2x2 island is actually drawn -- grass on the tops, cliff below
// the near edges, sea around it and sky above -- on a phone and a desktop.
import { test, expect } from '../lib/fixtures.mjs';
import { cellToCanvas, logicalToCanvas } from '../lib/coords.mjs';
import { decodePng, pixel } from '../lib/png.mjs';

test('grass tops, cliff faces, sea and sky are where they should be', async ({ game }) => {
  await game.page.waitForTimeout(300);
  const png = decodePng(await game.canvas.screenshot());
  const box = await game.canvas.boundingBox();
  const sx = png.width / box.width;
  const sy = png.height / box.height;
  const at = (p) => pixel(png, p.x * sx, p.y * sy);
  const isGreen = ([r, g, b]) => g > r + 20 && g > b + 20;
  const isBlue = ([r, g, b]) => b > r + 30 && b >= g;
  for (const cell of [[0, 0], [1, 0], [0, 1], [1, 1]]) {
    expect(isGreen(at(await cellToCanvas(game, cell))), `grass on ${cell}`).toBe(true);
  }
  // Halfway down the cliff below the middle of the south-east face.
  const cliff = at(await logicalToCanvas(game, 2, 1.5, -0.3));
  expect(isGreen(cliff) || isBlue(cliff), `cliff colour ${cliff}`).toBe(false);
  // Open sea at the left edge below the horizon, and sky at the top.
  expect(isBlue(at({ x: box.width * 0.04, y: box.height * 0.55 })), 'sea').toBe(true);
  expect(isBlue(at({ x: box.width / 2, y: box.height * 0.1 })), 'sky').toBe(true);
});
