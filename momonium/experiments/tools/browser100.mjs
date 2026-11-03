// Step 100: the browser half of the 30-minute report. Reads a Playwright log
// of specs/durability100.spec.mjs (its "durability100 <project> <id>: ..."
// lines) and writes web/play30/browser100.json for report30.html.
//
//   node momonium/experiments/tools/browser100.mjs <playwright log> <what build> [out]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const [log, build, outArg] = process.argv.slice(2);
if (!log || !build) {
  console.error('usage: browser100.mjs <playwright log> <what build> [out]');
  process.exit(2);
}
const here = path.dirname(fileURLToPath(import.meta.url));
const out = outArg || path.join(here, '../web/play30/browser100.json');
const runs = [];
for (const line of fs.readFileSync(log, 'utf8').split('\n')) {
  const m = line.match(/^durability100 (\S+) (\S+): real input (.*?) in the first 3 min; (\{.*\})\s*$/);
  if (!m) continue;
  runs.push({ project: m[1], id: m[2], real_input: m[3], marks: JSON.parse(m[4]) });
}
if (runs.length === 0) {
  console.error(`no durability100 lines in ${log}`);
  process.exit(1);
}
fs.writeFileSync(out, JSON.stringify({
  _doc: `specs/durability100.spec.mjs on ${build}: the first three minutes by real taps and presses through the canvas in real time, then time-stepped by a script to thirty minutes; FPS a median of three real-frame windows at each mark. Technical and pacing evidence, not thirty minutes of human play.`,
  runs,
}, null, 2) + '\n');
console.log(`browser100: ${runs.length} runs -> ${out}`);
