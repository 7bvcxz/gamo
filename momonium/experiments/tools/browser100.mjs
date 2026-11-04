// Step 100: the browser half of the 30-minute report. Reads Playwright logs
// of specs/durability100.spec.mjs (their "durability100 <project> <id>: ..."
// lines; a later log's run replaces an earlier one's for the same project and
// variant -- a rerun) and writes web/play30/browser100.json for report30.html.
//
//   node momonium/experiments/tools/browser100.mjs <what build> <log> [<rerun log> ...] [--out file]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const oi = args.indexOf('--out');
const here = path.dirname(fileURLToPath(import.meta.url));
const out = oi >= 0 ? args.splice(oi, 2)[1] : path.join(here, '../web/play30/browser100.json');
const [build, ...logs] = args;
if (!build || logs.length === 0) {
  console.error('usage: browser100.mjs <what build> <log> [<rerun log> ...] [--out file]');
  process.exit(2);
}
const runs = [];
logs.forEach((log, n) => {
  for (const line of fs.readFileSync(log, 'utf8').split('\n')) {
    const m = line.match(/^durability100 (\S+) (\S+): real input (.*?) in the first 3 min; (\{.*\})\s*$/);
    if (!m) continue;
    const run = { project: m[1], id: m[2], real_input: m[3], marks: JSON.parse(m[4]), rerun: n > 0 };
    const i = runs.findIndex((r) => r.project === run.project && r.id === run.id);
    if (i >= 0) runs[i] = run; else runs.push(run);
  }
});
if (runs.length === 0) {
  console.error(`no durability100 lines in ${logs.join(", ")}`);
  process.exit(1);
}
fs.writeFileSync(out, JSON.stringify({
  _doc: `specs/durability100.spec.mjs on ${build}: the first three minutes by real taps and presses through the canvas in real time, then time-stepped by a script to thirty minutes; FPS a median of three real-frame windows at each mark. Technical and pacing evidence, not thirty minutes of human play.`,
  runs,
}, null, 2) + '\n');
console.log(`browser100: ${runs.length} runs -> ${out}`);
