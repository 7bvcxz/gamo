// Farm helpers for specs (Step 50): run a farm's stages by command, moving
// game time exactly to the end of each stage and of the wait after it -- the
// cycle's length comes from the game (rules query), never from the spec.
export async function runStages(game, id, n) {
  const b = async () => (await game.state()).buildings.buildings.find((x) => x.id === id);
  for (let i = 0; i < n; i++) {
    await settle(game, id);
    const r = await game.command({ type: 'building.tap', id });
    if (!r.ok) throw new Error(`stage ${i} did not start: ${r.reason}`);
    const s = await game.state();
    const f = s.buildings.buildings.find((x) => x.id === id);
    await game.query('dev_advance_ms', Math.max(f.task_end - s.now_ms, 0) + 5);
  }
  return b();
}

// Moves time to the end of whatever the building is doing (work or wait).
export async function settle(game, id) {
  for (let k = 0; k < 4; k++) {
    const s = await game.state();
    const f = s.buildings.buildings.find((x) => x.id === id);
    if (f.state === 'idle') return;
    const end = f.state === 'working' ? f.task_end : f.ready_at;
    await game.query('dev_advance_ms', Math.max(end - s.now_ms, 0) + 5);
  }
}
