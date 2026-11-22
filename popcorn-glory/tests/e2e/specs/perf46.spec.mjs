// Step 46: the benchmark table (a measurement, not a gate -- run with test_all.sh --perf).
// On the desktop (1280x800) and the phone (390x844 @2x) projects, in Playwright's Chromium on
// this machine (K12, software WebGL under load from sibling sessions -- the numbers say what
// this machine did, not what a phone does):
//   load: a fresh page to the first drawn frame; build bytes: the pack and the engine wasm
//   1, 5, 10, 20, 44 working machines: fps every second for 10 s (min, p10, median, p90),
//     draw calls and objects in a frame, nodes, JS heap after a forced GC, voices, cargo
//   44 machines, saturated buffers (the bin filled); 44 at rush hour (the film festival:
//     x1.5 arrivals); the peak of goods drawn moving at once
//   44 with fifty cargo journeys asked for at once (the dev storm: the view draws at most 40)
//   prolonged (desktop): five real minutes at 44 machines -- fps and heap at the start and end
// Writes $OUT/perf46_<project>.json (or the test's output folder) and an annotation.
import fs from 'node:fs';
import path from 'node:path';
import { test, expect } from '../lib/pop.mjs';

const PLAN = [['M07', 'kitchen'], ['bagger', 'packing'], ['S03', 'shop'], ['M01', 'kitchen'], ['M07', 'kitchen'],
  ['S05', 'shop'], ['M07', 'kitchen'], ['P07', 'packing'], ['M13', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'],
  ['S08', 'shop'], ['M08', 'kitchen'], ['U04', 'packing'], ['S01', 'shop'], ['M06', 'kitchen'], ['M07', 'kitchen'],
  ['M07', 'kitchen'], ['M01', 'kitchen'], ['bagger', 'packing'], ['kiosk', 'shop'], ['M14', 'kitchen'], ['U08', 'packing'],
  ['S04', 'shop'], ['M07', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'], ['S06', 'shop'], ['M02', 'kitchen'],
  ['P01', 'packing'], ['kiosk', 'shop'], ['M07', 'kitchen'], ['M01', 'kitchen'], ['bagger', 'packing'], ['M03', 'kitchen'],
  ['U05', 'packing'], ['M07', 'kitchen'], ['U03', 'kitchen'], ['bagger', 'packing'], ['M07', 'kitchen'], ['M05', 'kitchen'],
  ['U02', 'kitchen'], ['M07', 'kitchen'], ['P04', 'packing']];

const pct = (a, p) => { const s = [...a].sort((x, y) => x - y); return s[Math.min(s.length - 1, Math.floor(p * (s.length - 1)))]; };
const load = () => fs.readFileSync('/proc/loadavg', 'utf8').split(' ').slice(0, 3).map(Number);

async function heapAfterGc(pop) {
  const cdp = await pop.cdp();
  await cdp.send('HeapProfiler.collectGarbage');
  return (await cdp.send('Runtime.getHeapUsage')).usedSize;
}

async function popIfFree(pop) {
  const s = await pop.state();
  if (!s.run.heating && Object.keys(s.run.glass).length === 0 && s.run.cooldown_left <= 0) {
    await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * 0.25));
  }
}

async function sample(pop, label, seconds = 10) {
  const fps = [];
  let cargoPeak = 0;
  for (let i = 0; i < seconds; i++) {
    fps.push(await pop.fps(1000));
    const st = await pop.state();
    cargoPeak = Math.max(cargoPeak, st.view?.cargo_stats?.peak ?? 0, (st.view?.cargo_stats?.live ?? 0));
  }
  const info = await pop.call('dev_render_info');
  const s = await pop.state();
  return { scene: label, machines: s.run.machines.length, load: load(),
    fps: { min: Math.min(...fps), p10: pct(fps, 0.1), median: pct(fps, 0.5), p90: pct(fps, 0.9), all: fps.map((v) => Math.round(v * 10) / 10) },
    draw_calls: info.draw_calls, objects: info.objects, primitives: info.primitives, nodes: info.nodes,
    heap_mb: Math.round((await heapAfterGc(pop)) / 1e5) / 10,
    voices: s.sound?.voices, voices_peak: s.sound?.voices_peak, loop_copies: s.sound?.loop_copies,
    cargo: s.view?.cargo_stats ?? null, cargo_peak_seen: cargoPeak,
    queue: s.run.queue, bin: s.run.bin_portions, shelf: s.run.shelf };
}

test('the benchmark table: load, bytes, 1-44 machines, saturated, rush hour, prolonged', async ({ pop }, testInfo) => {
  const project = testInfo.project.name;
  test.skip(!['desktop', 'phone'].includes(project), 'the table is taken on the desktop and the phone');
  test.setTimeout(1_500_000);
  const rows = [];
  // Load and bytes.
  await pop.open('./#factory');
  const loadMs = pop.loadMs;
  const version = await pop.page.evaluate(() => fetch('./version.json', { cache: 'no-store' }).then((r) => r.json()));
  const wasmBytes = await pop.page.evaluate(async (engine) => {
    const r = await fetch(`../engine/${engine}.wasm`, { method: 'HEAD' });
    return Number(r.headers.get('content-length')) || null;
  }, version.engine);
  const build = { version: version.version, pack: version.pack, pack_bytes: version.packSize, engine: version.engine, wasm_bytes: wasmBytes, load_to_first_frame_ms: loadMs };
  // 1, 5, 10, 20, 44 working machines (each on a fresh page: nothing carried over).
  for (const n of [1, 5, 10, 20, 44]) {
    // A fresh factory on a fresh page. (Clearing localStorage before the navigation did not
    // work: the leaving page saves its factory on unload, and the rows piled up 1, 6, 15, 32.)
    await pop.open('./#factory');
    await pop.call('dev_restart');
    expect((await pop.state()).run.machines.length, 'a fresh factory').toBe(0);
    await pop.call('dev_money', 1e9);
    expect((await pop.call('dev_build', { plan: PLAN.slice(0, n), sign: 8, packer: 3 })).ok).toBe(true);
    for (let i = 0; i < 6; i++) { await popIfFree(pop); await pop.call('dev_advance', 5000); }   // warm: goods on every floor
    rows.push(await sample(pop, `${n} machines`));
  }
  // 44, saturated buffers.
  await pop.call('dev_fill_bin');
  rows.push(await sample(pop, '44, bin filled'));
  // 44, rush hour.
  const news = await pop.call('dev_news', 'film_festival');
  for (let i = 0; i < 4; i++) await pop.call('dev_advance', 5000);
  rows.push({ ...(await sample(pop, '44, rush hour (x1.5 arrivals)')), news_ok: news.ok });
  // 44 at rush hour, and fifty cargo journeys asked for at once (the view's dev storm: lot lifts
  // up the tube through the model's own event, asked again every frame; no model change). Natural
  // play reaches 7-9 in the air; the view draws at most its cap (40) and refuses the rest.
  await pop.call('dev_cargo', { n: 50, seconds: 60 });
  const stormRow = await sample(pop, '44, 50 cargo asked at once');
  const storm = await pop.call('dev_cargo', { n: 0 });
  rows.push({ ...stormRow, storm });
  // Prolonged: five real minutes at 44 (desktop), the hand popping now and then.
  let prolonged = null;
  if (project === 'desktop') {
    const a = await sample(pop, '44, prolonged start', 5);
    const t0 = Date.now();
    while (Date.now() - t0 < 300_000) { await popIfFree(pop); await pop.page.waitForTimeout(4000); }
    const b = await sample(pop, '44, prolonged after 5 min', 5);
    prolonged = { start: a, end: b, heap_growth_mb: Math.round((b.heap_mb - a.heap_mb) * 10) / 10 };
    rows.push(a, b);
  }
  const table = { project, viewport: testInfo.project.use.viewport, when: new Date().toISOString(), machine: 'K12 (Linux, Playwright Chromium, software WebGL)', build, rows, prolonged };
  const out = process.env.OUT ? path.join(process.env.OUT, `perf46_${project}.json`) : testInfo.outputPath(`perf46_${project}.json`);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, JSON.stringify(table, null, 2));
  testInfo.annotations.push({ type: 'perf46', description: JSON.stringify({ build, rows: rows.map((r) => ({ scene: r.scene, fps: r.fps.median, p10: r.fps.p10, draw: r.draw_calls, obj: r.objects, heap: r.heap_mb, voices: r.voices_peak, load: r.load[0] })) }) });
  // Gates that hold on any machine: the game runs (frames come), memory does not run away.
  for (const r of rows) expect(r.fps.median, `${r.scene}: frames come`).toBeGreaterThan(3);
  expect(storm.ok, 'the storm ran').toBe(true);
  // No new journey starts over the cap; a bag being filled under its head keeps flying when it
  // is sealed (it is drawn already), so the peak may pass the cap by the bags being filled.
  expect(storm.peak, 'fifty asked fill the cap').toBeGreaterThanOrEqual(storm.cargo_max);
  expect(storm.peak, 'and pass it by no more than the bags being filled').toBeLessThanOrEqual(storm.cargo_max + storm.filling_peak);
  expect(storm.refused, 'the asks over the cap are refused').toBeGreaterThan(0);
  if (prolonged) expect(prolonged.heap_growth_mb, 'five minutes keep under 30 MB more heap').toBeLessThan(30);
  expect(pop.errors).toEqual([]);
});
