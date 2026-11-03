// Step 95: C+ -- the hit made tactile -- in the real web build, beside the
// frozen C. Real taps (a finger on touch projects, the mouse on desktop):
//   - the same rock, pickaxe and camera in C and C+: each press is one hit,
//     timed from the press to the hit being counted and to its sound's first
//     sample (lib/onset.mjs), with pictures of the hit, the chunk, the last
//     hit and the pieces (FUNLAB_SHOTS);
//   - a break pays once, taps while it breaks and rises do nothing, the
//     pieces fly and are gone;
//   - a stream of breaks keeps the frame rate (C and C+ alternately, three
//     times each, medians);
//   - the press-and-hold experiment (?alt=hold, dev) repeats only while held;
//   - reduced motion: nothing flies, the information stays.
// Timing and frame rates go to FUNLAB_SHOTS/cplus95_<project>.json when set.
import fs from 'node:fs';
import { test, expect } from '../lib/lab.mjs';
import { ONSET, resetOnsets, onsetTimes } from '../lib/onset.mjs';

const median = (a) => { const s = [...a].sort((x, y) => x - y); return s.length ? s[Math.floor(s.length / 2)] : null; };
const centre = (r) => [r[0] + r[2] / 2, r[1] + r[3] / 2];
const records = {};
const rec = (info) => (records[info.project.name] ||= {});
const save = (info) => {
  if (process.env.FUNLAB_SHOTS) fs.writeFileSync(`${process.env.FUNLAB_SHOTS}/cplus95_${info.project.name}.json`, JSON.stringify(rec(info), null, 2));
};

// Opens experiment `id` and waits until it runs (moving between two
// experiments on one page is a hash change, answered a frame later).
async function go(lab, id) {
  await lab.open(`./#${id}`);
  await expect.poll(async () => (await lab.state()).route, { timeout: 15_000 }).toBe(id);
}

// A press at canvas pixel (x, y) the project's way.
async function press(lab, info, x, y) {
  const s = await lab.state();
  const box = await lab.canvas.boundingBox();
  const k = box.width / s.window[0];
  if (info.project.use.hasTouch) await lab.page.touchscreen.tap(box.x + x * k, box.y + y * k);
  else await lab.page.mouse.click(box.x + x * k, box.y + y * k);
}

// Notes the frame and time of every press and of every frame the hit count
// changes (frames: a phone at twice the pixels under a loaded machine draws
// far fewer a second, so the press-to-count time is read in frames too).
// Once a page (an experiment's link is a hash change, not a new page).
const PROBE = () => {
  window.__hits = [];
  window.__downs = [];
  if (window.__probe) return;
  window.__probe = true;
  window.__frame = 0;
  let last = window.funlab.call('count', 'hits');
  const loop = () => {
    window.__frame++;
    const h = window.funlab.call('count', 'hits');
    if (h !== last && h > last) window.__hits.push({ hits: h, t: performance.now(), f: window.__frame });
    last = h;
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
  window.addEventListener('pointerdown', (e) => window.__downs.push({ t: e.timeStamp, f: window.__frame }), true);
};

test('the same rock in C and C+: one press, one hit -- timed to the count and the sound, pictured', async ({ lab }, info) => {
  test.setTimeout(300_000);
  await lab.page.addInitScript(ONSET);
  for (const id of ['rock', 'rock-plus']) {
    await go(lab, id);
    await lab.call('dev_quiet');
    await lab.call('dev_rock', 3);
    await lab.call('dev_pick', 4);
    await lab.page.waitForTimeout(800);
    await lab.shot(`cplus95_${id}_0_rest`);
    await lab.page.evaluate(PROBE);
    await resetOnsets(lab.page);
    const offsets = [[-60, -30], [40, -50], [10, 20], [-30, 40], [70, 10]];
    let shotChunk = false;
    let taps = 0;
    let s = await lab.state();
    const start = s.host.experiment;
    while ((await lab.state()).host.experiment.breaks === 0) {
      const e = (await lab.state()).host.experiment;
      const [cx, cy] = centre(e.rock_rect);
      const [dx, dy] = offsets[taps % offsets.length];
      await press(lab, info, cx + dx, cy + dy);
      taps++;
      if (taps === 1) await lab.shot(`cplus95_${id}_1_hit`);
      await lab.page.waitForTimeout(250);
      const now = (await lab.state()).host.experiment;
      if (!shotChunk && now.cracks >= 0.7 && now.breaks === 0) { shotChunk = true; await lab.shot(`cplus95_${id}_2_cracked`); }
      if (now.breaks > 0) {
        await lab.shot(`cplus95_${id}_3_last_hit`);
        await lab.page.waitForTimeout(200);
        await lab.shot(`cplus95_${id}_4_flying`);
      }
      expect(taps, 'the rock breaks within its hits').toBeLessThan(40);
    }
    s = await lab.state();
    const e = s.host.experiment;
    expect(e.hits - start.hits, `${id}: every press was one hit`).toBe(taps);
    expect(s.host.session.actions_by_kind.hit, `${id}: recorded once each`).toBe(taps);
    const log = await lab.page.evaluate(() => ({ hits: window.__hits, downs: window.__downs }));
    expect(log.downs.length, 'one pointerdown a press').toBe(taps);
    // Each counted hit after its press: the first frame that showed it.
    expect(log.hits.length, 'each hit seen').toBe(taps);
    const ms = log.hits.map((h, i) => h.t - log.downs[i].t);
    const frames = log.hits.map((h, i) => h.f - log.downs[i].f);
    const sound = (await onsetTimes(lab.page)).filter((v) => v !== null);
    rec(info)[id] = { taps, register_ms: { median: median(ms), max: Math.max(...ms) }, register_frames: { median: median(frames), max: Math.max(...frames) },
      sound_ms: { median: median(sound), max: sound.length ? Math.max(...sound) : null, heard: sound.length, of: taps },
      rock: e.rock, breaks: e.breaks, chunks: e.chunks ?? null };
    console.log(`cplus95 ${info.project.name} ${id}: ${taps} taps, counted ${median(frames)} frames after the press (max ${Math.max(...frames)}; ${median(ms).toFixed(1)} ms), sound out ${median(sound)?.toFixed(1)} ms after (${sound.length}/${taps} heard)`);
    expect(median(frames), `${id}: a hit is counted within two frames of the press`).toBeLessThanOrEqual(2);
    expect(sound.length, `${id}: its sound really plays`).toBeGreaterThanOrEqual(Math.floor(taps * 0.8));
  }
  expect(rec(info)['rock-plus'].register_frames.median, 'C+ counts a hit no later than C').toBeLessThanOrEqual(rec(info).rock.register_frames.median);
  expect(rec(info)['rock-plus'].sound_ms.median, 'C+ sounds no later than C').toBeLessThan(rec(info).rock.sound_ms.median + 25);
  expect(rec(info)['rock-plus'].chunks, 'C+ lost its two chunks on the way').toBe(2);
  save(info);
});

test('a C+ break pays once; taps while it breaks and rises do nothing; the pieces fly and are gone', async ({ lab }, info) => {
  await lab.open('./#rock-plus');
  await lab.call('dev_pick', 6);
  // Play time stands still from here (a loaded machine's slow presses would
  // otherwise land after the 0.57 s the breaking and rising take).
  await lab.call('dev_time_scale', 0);
  let s = await lab.state();
  while (s.host.experiment.breaks === 0) {
    await press(lab, info, ...centre(s.host.experiment.rock_rect));
    s = await lab.state();
  }
  expect(s.host.experiment.coins, 'the first rock pays 25').toBe(25);
  expect(s.host.experiment.breaking, 'the breaking moment holds').toBe(true);
  for (let i = 0; i < 3; i++) await press(lab, info, ...centre(s.host.experiment.rock_rect));
  s = await lab.state();
  expect(s.host.experiment.coins, 'still 25: paid once').toBe(25);
  expect(s.host.experiment.breaks).toBe(1);
  expect(s.host.session.actions_by_kind.tap_wait, 'three presses that waited').toBe(3);
  await lab.call('dev_time_scale', 1);
  await expect.poll(async () => (await lab.state()).host.experiment.bits, { timeout: 5000, message: 'the pieces fly' }).toBeGreaterThan(0);
  await expect.poll(async () => (await lab.state()).host.experiment.bits, { timeout: 8000, message: 'and are gone' }).toBe(0);
  s = await lab.state();
  expect(s.host.experiment.rising, 'the next rock has risen').toBe(false);
  // Step 96 numbers: the second boulder has 115, the pickaxe at level 6 hits 9.
  expect(s.host.experiment.hp, 'untouched').toBe(115);
  await press(lab, info, ...centre(s.host.experiment.rock_rect));
  expect((await lab.state()).host.experiment.hp, 'and takes the next press').toBe(106);
});

// Frames a second on this machine swing four to six times between runs of
// the same build under load (Step 95: C 10.0 / 46.7 / 52.9), so the render
// objects at the busiest moment carry the comparison -- a count the load
// cannot move (Step 93 found D's frame drop that way) -- and the frame rate
// is recorded and only has to stay out of collapse.
test('a stream of breaks keeps the render load and frame rate (C and C+ alternately, three times each)', async ({ lab }, info) => {
  test.skip(info.project.name === 'phone', 'the 720x1280 phone and desktop (the 2x phone is the same software renderer at four times the pixels)');
  test.setTimeout(600_000);
  const fps = { rock: [], 'rock-plus': [] };
  const objects = { rock: [], 'rock-plus': [] };
  for (let round = 0; round < 3; round++) {
    for (const id of ['rock', 'rock-plus']) {
      await go(lab, id);
      // A pickaxe that breaks every rock in one hit (C's last level; C+ has no last).
      await lab.call('dev_pick', id === 'rock' ? 10 : 40);
      await lab.page.waitForTimeout(500);
      const s = await lab.state();
      const [x, y] = centre(s.host.experiment.rock_rect);
      await lab.page.evaluate(() => { window.__frames = 0; const f = () => { window.__frames++; requestAnimationFrame(f); }; requestAnimationFrame(f); });
      const t0 = Date.now();
      const f0 = await lab.page.evaluate(() => window.__frames);
      let most = 0;
      for (let i = 0; i < 30; i++) {
        await press(lab, info, x, y);
        await lab.page.waitForTimeout(80);
        if (i % 3 === 2) most = Math.max(most, (await lab.call('dev_render_info')).objects);
      }
      objects[id].push(most);
      const f1 = await lab.page.evaluate(() => window.__frames);
      const secs = (Date.now() - t0) / 1000;
      const st = await lab.state();
      fps[id].push((f1 - f0) / secs);
      expect(st.host.experiment.breaks, `${id}: breaking all the way`).toBeGreaterThan(5);
    }
  }
  rec(info).stream = { rock: { fps: fps.rock, median: median(fps.rock), objects: objects.rock }, 'rock-plus': { fps: fps['rock-plus'], median: median(fps['rock-plus']), objects: objects['rock-plus'] } };
  console.log(`cplus95 ${info.project.name} stream of breaks: render objects at the busiest C ${objects.rock.join('/')}, C+ ${objects['rock-plus'].join('/')}; fps C ${fps.rock.map((v) => v.toFixed(1)).join('/')}, C+ ${fps['rock-plus'].map((v) => v.toFixed(1)).join('/')}`);
  // Step 95 found 2,200-2,950 here before the cracks lost their antialiasing.
  expect(Math.max(...objects['rock-plus']), 'C+ at its busiest stays within a light render budget (D had 2,473 when it dropped frames)').toBeLessThan(1200);
  expect(median(objects['rock-plus']), 'and within 1.6 times C\'s').toBeLessThan(median(objects.rock) * 1.6);
  expect(median(fps['rock-plus']), 'and its frame rate does not collapse').toBeGreaterThan(median(fps.rock) * 0.4);
  save(info);
});

test('the press-and-hold experiment (?alt=hold) repeats only while held', async ({ lab }, info) => {
  test.skip(info.project.name === 'p720', 'phone and desktop');
  await lab.open('./?alt=hold#rock-plus');
  let s = await lab.state();
  expect(s.host.alt).toBe('hold');
  const box = await lab.canvas.boundingBox();
  const k = box.width / s.window[0];
  const [cx, cy] = centre(s.host.experiment.rock_rect);
  const x = box.x + cx * k;
  const y = box.y + cy * k;
  const t0 = s.host.session.active_seconds;
  if (info.project.use.hasTouch) {
    const cdp = await lab.page.context().newCDPSession(lab.page);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
    await lab.page.waitForTimeout(2000);
    s = await lab.state();
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  } else {
    await lab.page.mouse.move(x, y);
    await lab.page.mouse.down();
    await lab.page.waitForTimeout(2000);
    s = await lab.state();
    await lab.page.mouse.up();
  }
  expect(s.host.experiment.holding, 'held').toBe(true);
  // Play time (a slow frame advances at most 0.25 s), not the wall clock.
  const held = s.host.session.active_seconds - t0;
  // (t0 was read a moment before the press began: the hold is a little shorter.)
  expect(held, 'some play time passed').toBeGreaterThan(0.9);
  expect(s.host.experiment.hold_hits, 'repeats while held').toBeGreaterThanOrEqual(2);
  expect(s.host.experiment.hold_hits, `never more than one every 0.45 s of the ${held.toFixed(1)} s`).toBeLessThanOrEqual(Math.floor(held / 0.45));
  await lab.page.waitForTimeout(300);
  const after = (await lab.state()).host.experiment;
  expect(after.holding, 'released').toBe(false);
  await lab.page.waitForTimeout(1200);
  expect((await lab.state()).host.experiment.hits, 'nothing after the release').toBe(after.hits);
  expect((await lab.state()).host.session.variant).toBe('hold');
});

test('reduced motion: C+ breaks without flying pieces and keeps the numbers', async ({ lab }, info) => {
  test.skip(info.project.name === 'p720', 'phone and desktop');
  await lab.open('./?motion=reduce#rock-plus');
  await lab.call('dev_pick', 6);
  let s = await lab.state();
  while (s.host.experiment.breaks === 0) {
    await press(lab, info, ...centre(s.host.experiment.rock_rect));
    s = await lab.state();
  }
  expect(s.host.experiment.bits, 'nothing flies').toBe(0);
  expect(s.host.experiment.breaking, 'no held moment').toBe(false);
  expect(s.host.experiment.coins).toBe(25);
  expect(s.host.experiment.chunks, 'the chunks are still shown').toBe(2);
});
