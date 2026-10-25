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
