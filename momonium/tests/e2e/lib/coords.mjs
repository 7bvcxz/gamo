// Converts a game window position (from momonium.call('cell_screen')) into a
// point relative to the canvas element in CSS pixels, for page.touchscreen/mouse.
export async function cellToCanvas(game, cell) {
  const r = await game.query('cell_screen', cell);
  const box = await game.canvas.boundingBox();
  return { x: r.x * (box.width / r.window[0]), y: r.y * (box.height / r.window[1]) };
}

export async function logicalToCanvas(game, x, y, z = 0) {
  const r = await game.query('logical_screen', [x, y, z]);
  const box = await game.canvas.boundingBox();
  return { x: r.x * (box.width / r.window[0]), y: r.y * (box.height / r.window[1]) };
}

// A point on a building's cell that no Momo is standing over, so a real tap
// reaches the building (Momo are tapped first when they overlap it).
export async function clearPointOnCell(game, cell) {
  const m = await game.query('momos');
  const box = await game.canvas.boundingBox();
  const sx = box.width / m.window[0];
  const sy = box.height / m.window[1];
  const bodies = Object.values(m.momos).map((x) => ({ x: x.body[0] * sx, y: x.body[1] * sy }));
  let best = null;
  let bestD = -1;
  for (const [fx, fy] of [[0.5, 0.5], [0.25, 0.25], [0.75, 0.25], [0.25, 0.75], [0.75, 0.75], [0.5, 0.2], [0.2, 0.5]]) {
    const p = await logicalToCanvas(game, cell[0] + fx, cell[1] + fy);
    const d = Math.min(...bodies.map((b) => Math.hypot(b.x - p.x, (b.y - p.y) * 0.7)), 1e9);
    if (d > bestD) { bestD = d; best = p; }
  }
  return best;
}
