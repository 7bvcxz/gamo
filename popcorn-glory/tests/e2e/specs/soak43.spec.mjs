// Step 43: ten minutes of real time at forty-four machines with the hand popping, measured
// every thirty seconds on the page's real output (lib/audio_tap.mjs): the loudest moment never
// reaches full scale, the voices stay in their pool, the page makes no new decoded buffers after
// the first minute (0.12.0 made one a frame while held: about 27 MB a hold), and the sound adds
// no memory of its own: the renderer's growth is compared with a control run of the same ten
// minutes with the sound off. Desktop only (the phones run sound43). Twenty minutes in all.
// SOAK43_MIN sets the minutes of each run (default 10).
import fs from 'node:fs';
import path from 'node:path';
import { test as base, expect } from '../lib/pop.mjs';
import { AUDIO_TAP, listen, listenStereo, counts, startRecord, stopRecord } from '../lib/audio_tap.mjs';

const test = base.extend({
  pop: async ({ pop }, use) => {
    await pop.page.addInitScript(AUDIO_TAP);
    await use(pop);
  },
});

const PLAN = [['M07', 'kitchen'], ['bagger', 'packing'], ['S03', 'shop'], ['M01', 'kitchen'], ['M07', 'kitchen'],
  ['S05', 'shop'], ['M07', 'kitchen'], ['P07', 'packing'], ['M13', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'],
  ['S08', 'shop'], ['M08', 'kitchen'], ['U04', 'packing'], ['S01', 'shop'], ['M06', 'kitchen'], ['M07', 'kitchen'],
  ['M07', 'kitchen'], ['M01', 'kitchen'], ['bagger', 'packing'], ['kiosk', 'shop'], ['M14', 'kitchen'], ['U08', 'packing'],
  ['S04', 'shop'], ['M07', 'kitchen'], ['M07', 'kitchen'], ['bagger', 'packing'], ['S06', 'shop'], ['M02', 'kitchen'],
  ['P01', 'packing'], ['kiosk', 'shop'], ['M07', 'kitchen'], ['M01', 'kitchen'], ['bagger', 'packing'], ['M03', 'kitchen'],
  ['U05', 'packing'], ['M07', 'kitchen'], ['U03', 'kitchen'], ['bagger', 'packing'], ['M07', 'kitchen'], ['M05', 'kitchen'],
  ['U02', 'kitchen'], ['M07', 'kitchen'], ['P04', 'packing']].map(([t, f]) => [t === 'M07' ? 'cooker' : t, f]);
// The resident memory of this browser's renderer processes in MB (the per-play buffer copies live
// outside the JS heap): their pids from CDP, their VmRSS from /proc (the test runs on this machine).
// A full collection first (CDP HeapProfiler.collectGarbage), so the reading is what is kept, not
// what is waiting for the collector: a played copy is garbage the moment its source ends.
async function rendererRss(pop) {
  try {
    if (!pop._pcdp) pop._pcdp = await pop.page.context().newCDPSession(pop.page);
    await pop._pcdp.send('HeapProfiler.collectGarbage');
    await pop.page.waitForTimeout(500);
    if (!pop._bcdp) pop._bcdp = await pop.page.context().browser().newBrowserCDPSession();
    const info = await pop._bcdp.send('SystemInfo.getProcessInfo');
    let kb = 0;
    for (const p of info.processInfo.filter((x) => x.type === 'renderer')) {
      const m = /VmRSS:\s+(\d+)/.exec(fs.readFileSync(`/proc/${p.id}/status`, 'utf8'));
      if (m) kb += Number(m[1]);
    }
    return Math.round(kb / 1024);
  } catch (e) { return -1; }
}

const OUT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../../../evidence/step43/audio');

// Ten minutes at forty-four machines, one row each thirty seconds. `off`: the control, the same
// factory and the same hand with the sound off (the game then plays nothing at all).
async function soak(pop, testInfo, off) {
  const minutes = Number(process.env.SOAK43_MIN || 10);
  await pop.open(off ? './?sound=off#factory' : './#factory');
  const s0 = await pop.state();
  await pop.hold('ring', Math.round(s0.run.window[0] + (s0.run.window[1] - s0.run.window[0]) * 0.25));
  const b = await pop.call('dev_build', { plan: PLAN, sign: 8, packer: 3 });
  expect(b.machines).toBe(44);
  const rows = [];
  const t0 = Date.now();
  let recorded = false;
  for (let k = 0; Date.now() - t0 < minutes * 60_000; k++) {
    const h = await listen(pop.page);
    const st = await listenStereo(pop.page);
    if (k === 2 && !off) recorded = await startRecord(pop.page);
    const end = Date.now() + 30_000;
    let pops = 0;
    let blocked = 0;   // tries while the hand's glass waits for the bin (err.kettle_full)
    while (Date.now() < end) {
      const s = await pop.state();
      if (Object.keys(s.run.glass).length > 0) blocked += 1;
      else if (!s.run.heating && s.run.cooldown_left <= 0 && Math.random() < 0.5) {
        await pop.hold('ring', Math.round(s.run.window[0] + (s.run.window[1] - s.run.window[0]) * (0.1 + 0.5 * Math.random())));
        pops += 1;
      }
      await pop.page.waitForTimeout(1500);
    }
    if (k === 2 && recorded) {
      fs.mkdirSync(OUT, { recursive: true });
      fs.writeFileSync(path.join(OUT, 'soak44_minute1_30s_desktop.webm'), await stopRecord(pop.page));
    }
    const m = await h(0);
    const e = await st(0);
    const c = await counts(pop.page);
    const info = await pop.call('dev_render_info');
    const heap = await pop.page.evaluate(() => (performance.memory ? performance.memory.usedJSHeapSize : 0));
    const rss = await rendererRss(pop);
    const snd = (await pop.state()).sound;
    rows.push({ t: Math.round((Date.now() - t0) / 1000), pops, blocked, rms: +m.rms.toFixed(4), peak: +m.peak.toFixed(3), mean_rms: +e.mean_rms.toFixed(4),
      buffers: c.buffers, copies: c.copies, copy_mb: +c.copy_mb.toFixed(1), sources: c.sources, heap_mb: +(heap / 1048576).toFixed(1), renderer_mb: rss,
      fps: info.fps, static_mb: +(info.static_mem / 1048576).toFixed(1), voices_peak: snd.voices_peak, beds: snd.beds_playing, bed_starts: snd.bed_starts,
      loop_copies: snd.loop_copies, sold: (await pop.state()).run.stats.sold });
  }
  testInfo.annotations.push({ type: 'soak', description: JSON.stringify(rows) });
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, off ? 'soak43_rows_off.json' : 'soak43_rows.json'), JSON.stringify(rows, null, 1));
  return rows;
}

// The renderer's growth over the run: the median of the last third against the first row
// (single readings jump by ~100 MB as the allocator and the software renderer breathe).
function growth(rows) {
  const tail = rows.slice(Math.floor(rows.length * 2 / 3)).map((r) => r.renderer_mb).sort((a, b) => a - b);
  return tail[Math.floor(tail.length / 2)] - rows[0].renderer_mb;
}

let control = null;

test.describe.serial('ten minutes at forty-four machines', () => {
  test('the control: the sound off plays nothing', async ({ pop }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'one long run on the desktop');
    test.setTimeout((Number(process.env.SOAK43_MIN || 10) * 60 + 240) * 1000);
    control = await soak(pop, testInfo, true);
    expect(control[control.length - 1].sources, 'off: no sound played').toBeLessThanOrEqual(2);
    expect(pop.errors).toEqual([]);
  });

  test('the sound on: no clip, bounded voices, no buffer growth, and no memory of its own', async ({ pop }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'one long run on the desktop');
    test.setTimeout((Number(process.env.SOAK43_MIN || 10) * 60 + 240) * 1000);
    const rows = await soak(pop, testInfo, false);
    const first = rows[1] ?? rows[0];
    const last = rows[rows.length - 1];
    expect(Math.max(...rows.map((r) => r.peak)), 'the loudest moment of ten minutes is under full scale').toBeLessThan(1.0);
    expect(Math.min(...rows.map((r) => r.mean_rms)), 'the factory is heard all along').toBeGreaterThan(0.002);
    expect(Math.max(...rows.map((r) => r.voices_peak)), 'the voices stay in their pool').toBeLessThanOrEqual(16);
    expect(last.buffers - first.buffers, `no new samples registered after the first minute (${first.buffers} -> ${last.buffers})`).toBeLessThanOrEqual(2);
    expect(Math.abs((last.copies - first.copies) - (last.sources - first.sources)), "the engine's per-play copies: one per play").toBeLessThanOrEqual(4);
    expect(last.loop_copies, 'no looping copies made in the factory').toBe(0);
    expect(last.heap_mb, `the page's JS heap does not climb (${first.heap_mb} -> ${last.heap_mb} MB)`).toBeLessThan(first.heap_mb * 1.15 + 5);
    // Godot 4.7 copies a sample for every web play (~1.1 GB over ten minutes here). The renderer
    // grows with the sound off too (the factory and the software renderer: a Step 46 question);
    // what the sound adds is the difference, and kept copies would add hundreds of MB.
    expect(control, 'the control ran first').not.toBeNull();
    if (rows[0].renderer_mb > 0 && control[0].renderer_mb > 0) {
      const own = growth(rows) - growth(control);
      expect(own, `the sound's own memory over ten minutes: ${own} MB (on ${growth(rows)}, off ${growth(control)}; ${last.copy_mb.toFixed(0)} MB copied)`).toBeLessThan(100);
    }
    // The hand presses whenever the game lets it: at this plan the bin is often full and the
    // hand's glass waits to pour (the same rule a player meets) -- counted as `blocked`.
    expect(rows.reduce((a, r) => a + r.pops, 0), 'the hand popped').toBeGreaterThan(0);
    expect(pop.errors).toEqual([]);
  });
});
