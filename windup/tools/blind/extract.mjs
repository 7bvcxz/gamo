// After a blind session (Step 09): split the player's transcript into
//   seen/<screen>.png        -- the exact images the player opened (decoded from the transcript)
//   transcript.sanitized.jsonl -- the transcript with each image replaced by its file name
//   decisions.md             -- in order: the screen it looked at, what it said, what it did next
// and delete the raw transcript (its images are now in seen/). Run once per session.
//   node windup/tools/blind/extract.mjs <session dir>
import fs from 'node:fs';
import path from 'node:path';

const dir = process.argv[2];
const raw = path.join(dir, 'transcript.jsonl');
if (!fs.existsSync(raw)) { console.log('already extracted'); process.exit(0); }
const actions = fs.readFileSync(path.join(dir, 'actions.jsonl'), 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l));
const wallOf = Object.fromEntries(actions.filter((a) => a.screen).map((a) => [a.screen, a.wall_after]));
fs.mkdirSync(path.join(dir, 'seen'), { recursive: true });
// The stream also repeats each image in a top-level tool_use_result; drop any
// long base64 string left anywhere (the image itself is in seen/).
function strip(v) {
  if (typeof v === 'string') return v.length > 20000 && /^[A-Za-z0-9+/=\s]+$/.test(v.slice(0, 2000)) ? `<${v.length} chars of base64 removed; the image is in seen/>` : v;
  if (Array.isArray(v)) return v.map(strip);
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, strip(x)]));
  return v;
}
const pendingRead = {};   // tool_use id -> screen name
const out = [];
const steps = [];         // {kind, ...}
for (const line of fs.readFileSync(raw, 'utf8').split('\n').filter(Boolean)) {
  const m = JSON.parse(line);
  if (m.type === 'assistant' && Array.isArray(m.message?.content)) {
    for (const c of m.message.content) {
      if (c.type === 'text' && c.text.trim()) steps.push({ kind: 'say', text: c.text.trim() });
      if (c.type === 'tool_use' && c.name === 'Read') { pendingRead[c.id] = path.basename(String(c.input.file_path || '')); }
      if (c.type === 'tool_use' && c.name === 'Bash') steps.push({ kind: 'run', cmd: String(c.input.command || '') });
      if (c.type === 'tool_use' && !['Read', 'Bash'].includes(c.name)) steps.push({ kind: 'other_tool', name: c.name });
    }
  }
  if (m.type === 'user' && Array.isArray(m.message?.content)) {
    for (const c of m.message.content) {
      if (c.type !== 'tool_result' || !Array.isArray(c.content)) continue;
      for (const x of c.content) {
        if (x.type === 'image' && x.source?.data) {
          const name = (pendingRead[c.tool_use_id] || `unknown_${c.tool_use_id}.png`).replace(/\.\w+$/, '.png');
          fs.writeFileSync(path.join(dir, 'seen', name), Buffer.from(x.source.data, 'base64'));
          x.source = { type: 'file', path: `seen/${name}` };
          steps.push({ kind: 'look', screen: name });
        }
      }
    }
  }
  out.push(JSON.stringify(strip(m)));
}
fs.writeFileSync(path.join(dir, 'transcript.sanitized.jsonl'), out.join('\n') + '\n');
const md = [`# Decisions — ${path.basename(dir)}`, '',
  'In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).', ''];
for (const s of steps) {
  if (s.kind === 'look') md.push(`- **looked at** \`seen/${s.screen}\` (${wallOf[s.screen.replace('.png', '.png')] !== undefined ? wallOf[s.screen].toFixed(1) + ' s' : '?'})`);
  if (s.kind === 'say') md.push(`  > ${s.text.replace(/\n+/g, ' ')}`);
  if (s.kind === 'run') md.push(`  - ran \`${s.cmd.length > 300 ? s.cmd.slice(0, 300) + '…' : s.cmd}\``);
  if (s.kind === 'other_tool') md.push(`  - used tool ${s.name}`);
}
fs.writeFileSync(path.join(dir, 'decisions.md'), md.join('\n') + '\n');
fs.unlinkSync(raw);
console.log(`${path.basename(dir)}: ${fs.readdirSync(path.join(dir, 'seen')).length} screens seen, ${steps.filter((s) => s.kind === 'run').length} commands`);
