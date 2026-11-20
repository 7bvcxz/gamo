// Which browser specs a test_all.sh run plays (Step 46). The full list is DERIVED from
// tests/e2e/specs/ -- a hand-written list rots (AGENTS.md): until Step 46 the full suite
// silently left out ui44, save45 and every spec written after Step 43. A spec stays out of
// the full run only if it is named in ON_DEMAND with its reason, and the report says so.
//
//   node tools/specs.mjs full|focused|slow|perf     -> the spec paths, one per line
//   node tools/specs.mjs explain                    -> JSON {full, focused, on_demand: {spec: reason}}
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const GAME = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DIR = path.join(GAME, 'tests', 'e2e', 'specs');

// Out of the full run, each for a reason; `mode` is the flag that runs it.
export const ON_DEMAND = {
  'play180.spec.mjs': { mode: 'slow', why: 'three real minutes per experiment (--slow)' },
  'play_stand.spec.mjs': { mode: 'slow', why: 'a long real-time stand session, one project (--slow)' },
  'sessions22.spec.mjs': { mode: 'slow', why: 'Step 22 evidence: real-time 3-minute sessions from seeds, writes $OUT/sessions22.json (--slow)' },
  'render_probe.spec.mjs': { mode: 'perf', why: 'a probe, not a gate: load time and render cost of a build (--perf)' },
  'perf46.spec.mjs': { mode: 'perf', why: 'the Step 46 benchmark table, desktop and phone (--perf)' },
};

// A quick set that touches every area once (first play, the factory's flow, saves, the
// frame's targets, news and contests, the hand under a stalled frame, the journey, the
// pathological cases). Minutes, not hours.
export const FOCUSED = ['stub03.spec.mjs', 'stall09.spec.mjs', 'release12.spec.mjs', 'factory17.spec.mjs', 'factory22.spec.mjs',
  'factory26.spec.mjs', 'news37.spec.mjs', 'contests38.spec.mjs', 'save45.spec.mjs', 'journey46.spec.mjs', 'negative46.spec.mjs'];

export function all() {
  return fs.readdirSync(DIR).filter((f) => f.endsWith('.spec.mjs')).sort();
}

export function list(mode) {
  const every = all();
  if (mode === 'focused') return FOCUSED.filter((f) => every.includes(f));
  if (mode === 'slow' || mode === 'perf') return every.filter((f) => ON_DEMAND[f]?.mode === mode);
  return every.filter((f) => !ON_DEMAND[f]);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const mode = process.argv[2] || 'full';
  if (mode === 'explain') {
    const missing = FOCUSED.filter((f) => !all().includes(f));
    console.log(JSON.stringify({ full: list('full'), focused: list('focused'), focused_missing: missing,
      on_demand: Object.fromEntries(Object.entries(ON_DEMAND).filter(([f]) => all().includes(f)).map(([f, o]) => [f, o.why])) }, null, 2));
  } else {
    for (const f of list(mode)) console.log(`specs/${f}`);
  }
}
