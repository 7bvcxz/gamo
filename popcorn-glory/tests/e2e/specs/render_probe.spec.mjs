// A probe, not a gate: what the renderer draws per frame (draw calls,
// objects, primitives) and the frame rate, at level 0 and at each
// experiment's top level, idle, three samples each. Run on one project:
//   popcorn-glory/tools/e2e.sh specs/render_probe.spec.mjs --project p720
import { test } from '../lib/pop.mjs';
import fs from 'node:fs';

test('render cost by level', async ({ pop }) => {
  test.setTimeout(300_000);
  const rows = [];
  for (const [id, top] of [['click', 11], ['perfect', 14], ['explosion', 9]]) {
    await pop.open(`./#${id}`);
    for (const level of [0, top]) {
      await pop.call('dev_level', level);
      await pop.page.waitForTimeout(800);
      const fps = [];
      for (let i = 0; i < 3; i++) fps.push(await pop.fps(1500));
      const info = await pop.call('dev_render_info');
      rows.push({ id, level, fps: fps.map((f) => Math.round(f * 10) / 10), draw_calls: info.draw_calls, objects: info.objects, primitives: info.primitives, nodes: info.nodes });
    }
  }
  console.log(JSON.stringify(rows, null, 1));
  if (process.env.POPCORN_PLAY_OUT) fs.writeFileSync(`${process.env.POPCORN_PLAY_OUT}/render_probe_${test.info().project.name}.json`, JSON.stringify(rows, null, 2));
});
