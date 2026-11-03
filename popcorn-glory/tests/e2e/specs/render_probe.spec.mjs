// A probe, not a gate: what one build costs. Load time to the first drawn
// frame (median of three fresh pages), the JS heap, Godot's static memory
// (when the build reports it), and per experiment at level 0 and at its top
// level, idle: draw calls, objects, primitives and fps (three samples).
// Run it on one project, against any build -- Step 05 compares the published
// 0.4.0 (before the art and sound) with the new one:
//   POPCORN_PLAY_OUT=/abs/dir POPCORN_E2E_BASE=<url> popcorn-glory/tools/e2e.sh specs/render_probe.spec.mjs --project p720
import { test } from '../lib/pop.mjs';
import fs from 'node:fs';
import os from 'node:os';

test('render cost by level', async ({ pop }) => {
  test.setTimeout(400_000);
  const loads = [];
  for (let i = 0; i < 3; i++) {
    await pop.page.goto('about:blank');
    await pop.open('./#click');
    loads.push(pop.loadMs);
  }
  loads.sort((a, b) => a - b);
  const heap = await pop.page.evaluate(() => (performance.memory ? performance.memory.usedJSHeapSize : null));
  const rows = [];
  for (const [id, top] of [['click', 11], ['perfect', 14], ['explosion', 9]]) {
    await pop.open(`./#${id}`);
    for (const level of [0, top]) {
      await pop.call('dev_level', level);
      await pop.page.waitForTimeout(800);
      const fps = [];
      for (let i = 0; i < 3; i++) fps.push(await pop.fps(1500));
      const info = await pop.call('dev_render_info');
      rows.push({ id, level, fps: fps.map((f) => Math.round(f * 10) / 10), draw_calls: info.draw_calls, objects: info.objects,
        primitives: info.primitives, nodes: info.nodes, static_mem: info.static_mem ?? null });
    }
  }
  const s = await pop.state();
  const out = { base: test.info().project.use.baseURL, version: s.version, load_ms_median: loads[1], load_ms: loads,
    js_heap: heap, load_avg: os.loadavg()[0], rows };
  console.log(JSON.stringify(out));
  if (process.env.POPCORN_PLAY_OUT) fs.writeFileSync(`${process.env.POPCORN_PLAY_OUT}/render_probe_${s.version}_${test.info().project.name}.json`, JSON.stringify(out, null, 2));
});
