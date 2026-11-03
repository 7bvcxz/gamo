// Step 04 V2: three real play traces on the running web build, each from a
// fresh start for more than three minutes -- an enthusiastic clicker, a
// minimal clicker, and a novice-style first try (looks around, clicks the
// wrong things first, then finds the key, slow and uneven, one long pause) at
// 1920x1080. The players are scripts with fixed patterns, not people and not
// AI; they show what each engagement level reaches. The enthusiastic run is
// kept as unedited footage with the game's own sound (lib/footage.mjs).
// Evidence (WINDUP_EVIDENCE=1): windup/evidence/<WINDUP_EVIDENCE_STEP or step04>/profiles/.
import { test, expect } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
import { openGame, state, call, events, keyPoint } from '../lib/game.mjs';
import { AUDIO_TAP } from '../lib/audio_tap.mjs';
import { recordingContext, takeAudio, finishFootage } from '../lib/footage.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const evidence = process.env.WINDUP_EVIDENCE
  ? path.resolve(here, '../../../evidence/' + (process.env.WINDUP_EVIDENCE_STEP || 'step04') + '/profiles')
  : path.resolve(here, '../test-results/evidence/profiles');

test.describe.configure({ mode: 'serial' });

const PROFILES = {
  enthusiastic: {
    viewport: { width: 1280, height: 720 }, footage: true,
    async play(page, k, until) {
      while (!(await until())) {
        for (let i = 0; i < 10; i++) { await page.mouse.click(k.x, k.y); await page.waitForTimeout(170); }
        await page.mouse.move(k.x, k.y); await page.mouse.down(); await page.waitForTimeout(4000); await page.mouse.up();
        await page.waitForTimeout(800);
      }
    },
  },
  minimal: {
    viewport: { width: 1280, height: 720 }, footage: true,
    async play(page, k, until) {
      await page.waitForTimeout(2000);
      while (!(await until())) { await page.mouse.click(k.x, k.y); await page.waitForTimeout(3000); }
    },
  },
  novice: {
    viewport: { width: 1920, height: 1080 },
    async play(page, k, until) {
      const box = await page.locator('canvas').boundingBox();
      await page.waitForTimeout(5000);                                          // looks around
      await page.mouse.click(box.x + box.width * 0.33, box.y + box.height * 0.9);  // a sleeping doll
      await page.waitForTimeout(2000);
      await page.mouse.click(box.x + box.width * 0.38, box.y + box.height * 0.38); // the spirit
      await page.waitForTimeout(3000);
      let n = 0;
      while (!(await until())) {
        n++;
        if (n % 9 === 0) { await page.mouse.move(k.x, k.y); await page.mouse.down(); await page.waitForTimeout(2000); await page.mouse.up(); }
        else await page.mouse.click(k.x + ((n * 7) % 30) - 15, k.y + ((n * 11) % 30) - 15);
        await page.waitForTimeout(n === 60 ? 12000 : 450 + ((n * 137) % 500));   // uneven, one long pause
      }
    },
  },
};

for (const [name, prof] of Object.entries(PROFILES)) {
  test(`profile ${name}: three minutes from a fresh start`, async ({ browser }, info) => {
    test.skip(info.project.name !== 'desktop', 'profiles run once, on the PC layout');
    // (0.5.1-0.7.0 the minimal player woke nothing in 3 minutes -- a known
    // failure marked test.fail; Step 08's tuning, first cost 75 -> 55, fixed it.)
    test.setTimeout(360_000);
    fs.mkdirSync(evidence, { recursive: true });
    const rec = prof.footage ? await recordingContext(browser, prof.viewport, path.join(evidence, 'video_tmp')) : null;
    const context = rec ? rec.context : await browser.newContext({ viewport: prof.viewport });
    const page = rec ? rec.page : await context.newPage();
    await page.addInitScript(AUDIO_TAP);
    const { errors } = await openGame(page, '?fresh=1');
    // Game time 0 in video time (for milestone captions): now minus the game's clock.
    const videoAtGameZero = rec ? (Date.now() - rec.startedAt) / 1000 - (await state(page)).t : 0;
    const k = await keyPoint(page);
    // Every input with wall and game time, so a profile's pattern can be checked against its trace.
    const inputs = [];
    const t0 = Date.now();
    const realMouse = page.mouse;
    const logged = {
      click: async (x, y) => { inputs.push({ wall: (Date.now() - t0) / 1000, game: (await state(page)).t, input: 'click', x: Math.round(x), y: Math.round(y) }); return realMouse.click(x, y); },
      down: async () => { inputs.push({ wall: (Date.now() - t0) / 1000, game: (await state(page)).t, input: 'down' }); return realMouse.down(); },
      up: async () => { inputs.push({ wall: (Date.now() - t0) / 1000, game: (await state(page)).t, input: 'up' }); return realMouse.up(); },
      move: (x, y) => realMouse.move(x, y),
    };
    const shots = new Set();
    const until = async () => {
      const s = await state(page);
      for (const m of [0, 10, 30, 60, 180]) {
        if (!shots.has(m) && s.t >= m) { shots.add(m); await page.screenshot({ path: path.join(evidence, `${name}_${String(m).padStart(3, '0')}s.png`) }); }
      }
      return s.t >= 185;
    };
    await until();
    await prof.play({ mouse: logged, waitForTimeout: (ms) => page.waitForTimeout(ms), locator: (q) => page.locator(q) }, k, until);
    const end = await call(page, 'end');
    const ev = await events(page);
    const s = await state(page);
    const first = (n) => ev.find((e) => e.ev === n);
    const idle = ev.filter((e) => e.ev === 'idle').map((e) => e.seconds);
    const summary = {
      profile: name, viewport: prof.viewport, build_id: s.build_id, game_seconds: s.t,
      first_input: first('wind')?.t ?? null, first_doll: first('doll_awake')?.t ?? null,
      second_doll: ev.filter((e) => e.ev === 'doll_awake')[1]?.t ?? null, first_help: first('help')?.t ?? null,
      awakenings: ev.filter((e) => e.ev === 'doll_awake').map((e) => e.t), dolls_end: s.awake, energy_end: s.energy,
      presses: end.inputs, turns: end.turns, refused_by_cap: end.blocked,
      dead_time_s: idle.reduce((a, b) => a + b, 0), idle_gaps_over_5s: idle, hints: ev.filter((e) => e.ev === 'hint').length,
      pauses: ev.filter((e) => e.ev === 'pause').length, errors, machine_load_1min: os.loadavg()[0],
    };
    fs.writeFileSync(path.join(evidence, `${name}_events.jsonl`), ev.map((e) => JSON.stringify(e)).join('\n') + '\n');
    fs.writeFileSync(path.join(evidence, `${name}_inputs.json`), JSON.stringify(inputs) + '\n');
    if (rec) {
      const audio = await takeAudio(page);
      summary.footage = await finishFootage(rec, audio, path.join(evidence, `${name}_footage_${s.build_id}.mp4`));
      summary.footage.video = path.basename(summary.footage.video);
      summary.footage.out = path.basename(summary.footage.out);
      summary.footage.video_at_game_zero_s = videoAtGameZero;
      // Milestones as captions on the video (WebVTT beside the mp4).
      const cue = (t) => { const s = Math.max(0, t); const h = String(Math.floor(s / 3600)).padStart(2, '0'); const m = String(Math.floor(s / 60) % 60).padStart(2, '0'); return `${h}:${m}:${(s % 60).toFixed(3).padStart(6, '0')}`; };
      const label = { doll_awake: (e) => `doll ${e.index + 1} wakes (game ${e.t.toFixed(1)} s)`, help: (e) => `doll ${e.helper + 1} starts winding doll ${e.target + 1}`,
        stage: (e) => `the atelier: ${e.name}`, hint: (e) => `wordless hint: ${e.reason}` };
      const vtt = ['WEBVTT', ''];
      for (const e of ev.filter((x) => label[x.ev])) { const at = videoAtGameZero + e.t; vtt.push(`${cue(at)} --> ${cue(at + 3)}`, label[e.ev](e), ''); }
      fs.writeFileSync(path.join(evidence, summary.footage.out.replace(/\.mp4$/, '.vtt')), vtt.join('\n'));
    } else {
      await context.close();
    }
    fs.writeFileSync(path.join(evidence, `${name}_summary.json`), JSON.stringify(summary, null, 2) + '\n');
    expect(s.t).toBeGreaterThan(180);
    expect(summary.first_doll).not.toBeNull();             // every profile wakes the first doll
    expect(s.energy).toBeGreaterThanOrEqual(0);
    expect(errors).toEqual([]);
  });
}
