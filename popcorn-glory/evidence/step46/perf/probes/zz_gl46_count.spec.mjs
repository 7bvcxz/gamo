// Step 46 probe (temporary; kept in evidence/step46/perf/): WebGL objects created per frame.
// Emscripten's GL layer never reuses an object id and pads every id table to its one counter,
// so the JS heap grows with every object ever created (getNewId in the engine JS). This counts
// the creations, by kind, per frame -- with each layer of the factory hidden in turn.
import fs from 'node:fs';
import { test, expect } from '../lib/pop.mjs';
const PLAN = JSON.parse(fs.readFileSync(new URL('./perf46.spec.mjs', import.meta.url), 'utf8').match(/const PLAN = (\[[\s\S]*?\]\]);/)[1].replace(/'/g, '"'));
const KINDS = ['createBuffer', 'createVertexArray', 'fenceSync', 'createTexture', 'createFramebuffer', 'createRenderbuffer', 'createQuery', 'createSampler'];
const LAYERS = (process.env.GL_LAYERS || 'machine_layer,actor_layer,goods_layer,floor_layer,detail_layer,customer_node,belt_layer').split(',');
test('gl objects per frame', async ({ pop }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'desktop only');
  test.setTimeout(1_800_000);
  await pop.page.addInitScript((kinds) => {
    window.__gl = { frames: 0 };
    for (const k of kinds) window.__gl[k] = 0;
    for (const C of [window.WebGL2RenderingContext, window.WebGLRenderingContext]) {
      if (!C) continue;
      for (const k of kinds) {
        const f = C.prototype[k];
        if (typeof f !== 'function') continue;
        C.prototype[k] = function (...a) { window.__gl[k]++; return f.apply(this, a); };
      }
    }
    const raf = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = (cb) => raf((t) => { window.__gl.frames++; cb(t); });
  }, KINDS);
  const rows = [];
  const measure = async (label, ms = 8000) => {
    const a = await pop.page.evaluate(() => ({ ...window.__gl }));
    await pop.page.waitForTimeout(ms);
    const b = await pop.page.evaluate(() => ({ ...window.__gl }));
    const frames = b.frames - a.frames;
    const per = {};
    for (const k of KINDS) per[k] = Math.round((b[k] - a[k]) / Math.max(1, frames) * 10) / 10;
    const info = await pop.call('dev_render_info');
    rows.push({ scene: label, frames, per_frame: per, ids_per_frame: Math.round(KINDS.reduce((s, k) => s + (b[k] - a[k]), 0) / Math.max(1, frames) * 10) / 10, draw_calls: info.draw_calls, atlas: info.atlas_ready, fx_alive: info.fx_alive });
    console.log(JSON.stringify(rows.at(-1)));
  };
  await pop.open('./?sound=off#factory');
  await pop.call('dev_restart');
  await pop.page.waitForTimeout(3000);
  await measure('0 machines, idle');
  await pop.call('dev_money', 1e9);
  expect((await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 })).ok).toBe(true);
  await pop.page.waitForTimeout(10_000);
  await measure('44 machines');
  for (const l of LAYERS) {
    const r = await pop.call('dev_hide', { name: l, hidden: true });
    if (!r.ok) { rows.push({ scene: `hide ${l}`, error: r.error || 'no such layer' }); continue; }
    await pop.page.waitForTimeout(1500);
    await measure(`44, ${l} hidden`);
    await pop.call('dev_hide', { name: l, hidden: false });
  }
  await pop.call('dev_bake', { actors: false, free: true });
  await pop.page.waitForTimeout(1500);
  await measure('44, bakes off and freed');
  rows.push({ scene: 'render info', info: await pop.call('dev_render_info') });
  fs.writeFileSync(process.env.OUT + '/gl46_count.json', JSON.stringify({ when: new Date().toISOString(), kinds: KINDS, rows }, null, 2));
});
