// Step 46: what a test_all.sh run was -- its mode, the specs it played, the ones it left
// out and why (tools/specs.mjs ON_DEMAND), the load and the free memory at both ends.
//   node tools/run_info.mjs <out> <mode> <started> <load at start> <MB available at start>
import fs from 'node:fs';
import path from 'node:path';
import { ON_DEMAND, all } from './specs.mjs';

const [out, mode, started, load0, mem0] = process.argv.slice(2);
const ranFile = path.join(out, 'specs.txt');
const ran = fs.existsSync(ranFile) ? fs.readFileSync(ranFile, 'utf8').split('\n').filter(Boolean).map((s) => path.basename(s)) : [];
const every = all();
const info = {
  mode, started, ended: new Date().toISOString(),
  specs_run: ran,
  not_run: Object.fromEntries(every.filter((f) => !ran.includes(f)).map((f) => [f, ON_DEMAND[f]?.why ?? (mode === 'focused' ? 'not in the focused set' : mode === 'only' ? 'not asked for (--only)' : 'not in this run')])),
  load: { start: load0, end: fs.readFileSync('/proc/loadavg', 'utf8').split(' ').slice(0, 3).join(' ') },
  mem_available_mb: { start: Number(mem0), end: Math.round(Number(/MemAvailable:\s+(\d+)/.exec(fs.readFileSync('/proc/meminfo', 'utf8'))[1]) / 1024) },
};
fs.writeFileSync(path.join(out, 'run_info.json'), JSON.stringify(info, null, 2));
