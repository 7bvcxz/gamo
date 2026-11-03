// Step 06: the reference and the three variants, each from a fresh start for
// more than three minutes under the SAME scripted input (the enthusiastic
// pattern: ten clicks, a four-second hold, a short rest -- a script, not a
// person and not an AI), the same screen and the same capture. Per version:
// the events, input counts, first reward, the share of energy the dolls made
// on their own, idle time, doll actions, pictures at 0/30/60/180 s, and an
// unedited video with sound named by build id. Evidence (WINDUP_EVIDENCE=1):
// windup/evidence/step06/.
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
  ? path.resolve(here, '../../../evidence/step06')
  : path.resolve(here, '../test-results/evidence/step06');
const VARIANTS = (process.env.WINDUP_VARIANTS || 'base,a,b,c').split(',');

test.describe.configure({ mode: 'serial' });

for (const v of VARIANTS) {
  test(`variant ${v}: three minutes, same input`, async ({ browser }, info) => {
    test.skip(info.project.name !== 'desktop', 'one comparison run, on the PC layout');
    test.setTimeout(400_000);
    fs.mkdirSync(evidence, { recursive: true });
    const viewport = { width: 1280, height: 720 };
    const rec = process.env.WINDUP_NO_VIDEO ? null : await recordingContext(browser, viewport, path.join(evidence, 'video_tmp'));
    const context = rec ? rec.context : await browser.newContext({ viewport });
    const page = rec ? rec.page : await context.newPage();
    await page.addInitScript(AUDIO_TAP);
    const { errors } = await openGame(page, `?variant=${v}&fresh=1`);
    const k = await keyPoint(page);
    const inputs = [];
    const t0 = Date.now();
    const log = async (input) => inputs.push({ wall: (Date.now() - t0) / 1000, game: (await state(page)).t, input });
    const shots = new Set();
    const until = async () => {
      const s = await state(page);
      for (const m of [0, 30, 60, 180]) {
        if (!shots.has(m) && s.t >= m) { shots.add(m); await page.screenshot({ path: path.join(evidence, `${v}_${String(m).padStart(3, '0')}s.png`) }); }
      }
      return s.t >= 186;
    };
    await until();
    while (!(await until())) {
      for (let i = 0; i < 10; i++) { await log('click'); await page.mouse.click(k.x, k.y); await page.waitForTimeout(170); }
      await page.mouse.move(k.x, k.y); await log('down'); await page.mouse.down(); await page.waitForTimeout(4000);
      await log('up'); await page.mouse.up(); await page.waitForTimeout(800);
    }
    const end = await call(page, 'end');
    const ev = await events(page);
    const s = await state(page);
    expect(s.build_id).toBe(`${s.version}+${v}`);
    const count = (n) => ev.filter((e) => e.ev === n).length;
    const idle = ev.filter((e) => e.ev === 'idle').map((e) => e.seconds);
    const at180 = (n) => ev.filter((e) => e.ev === n && e.t <= 180).length;
    const summary = {
      variant: v, build_id: s.build_id, game_seconds: s.t,
      first_input: ev.find((e) => e.ev === 'wind')?.t ?? null,
      first_reward: ev.find((e) => e.ev === 'doll_awake')?.t ?? null,
      awakenings: ev.filter((e) => e.ev === 'doll_awake').map((e) => e.t), dolls_at_180: at180('doll_awake'),
      presses: end.inputs, turns: end.turns, refused: end.blocked,
      auto_share: +(s.auto_energy / Math.max(1e-9, s.auto_energy + s.manual_energy)).toFixed(3),
      idle_total_s: idle.reduce((a, b) => a + b, 0),
      doll_actions: { helps: count('help'), kicks: count('kick'), releases: count('release'), ready: count('doll_ready') },
      errors, machine_load_1min: os.loadavg()[0],
    };
    fs.writeFileSync(path.join(evidence, `${v}_events.jsonl`), ev.map((e) => JSON.stringify(e)).join('\n') + '\n');
    fs.writeFileSync(path.join(evidence, `${v}_inputs.json`), JSON.stringify(inputs) + '\n');
    if (rec) {
      const audio = await takeAudio(page);
      const f = await finishFootage(rec, audio, path.join(evidence, `footage_${s.build_id}.mp4`));
      summary.footage = { file: path.basename(f.out), audio_bytes: f.audio_bytes, audio_offset_s: f.audio_offset_s };
    } else {
      await context.close();
    }
    fs.writeFileSync(path.join(evidence, `${v}_summary.json`), JSON.stringify(summary, null, 2) + '\n');
    expect(s.t).toBeGreaterThan(180);
    expect(summary.first_reward).not.toBeNull();
    expect(summary.first_reward).toBeLessThan(60);       // an emotionally meaningful moment inside the window
    if (v === 'a') expect(summary.doll_actions.releases).toBeGreaterThan(3);
    if (v === 'c') expect(summary.doll_actions.kicks).toBeGreaterThan(0);
    expect(errors).toEqual([]);
  });
}
