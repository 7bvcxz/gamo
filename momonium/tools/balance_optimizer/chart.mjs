#!/usr/bin/env node
// Draws the pacing charts of the Step 50 report as plain SVG (no
// dependencies): production income over the first ten minutes -- the frozen
// target curve, the simulator's run and each blind run with their median --
// and a milestone strip of the primary times (target, each run, median).
//
//   node chart.mjs --sim sim.json --blind blind.json --title "R3" --out income.svg [--milestones ms.svg]
//
// sim.json: optimize.gd --json; blind.json: score_blind.mjs --json.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const opt = (k) => (args.includes(`--${k}`) ? args[args.indexOf(`--${k}`) + 1] : null);
const targets = JSON.parse(fs.readFileSync(path.join(here, 'targets.json'), 'utf8'));
const sim = opt('sim') ? JSON.parse(fs.readFileSync(opt('sim'), 'utf8')) : null;
const blind = opt('blind') ? JSON.parse(fs.readFileSync(opt('blind'), 'utf8')) : null;
const title = opt('title') || '';

const W = 720;
const H = 400;
const pad = { l: 64, r: 150, t: 36, b: 44 };
const X = (s) => pad.l + (s / 600) * (W - pad.l - pad.r);
const COLORS = { target: '#1b6ef3', sim: '#e8590c', run: '#868e96', median: '#2b8a3e' };

// The target curve: the exact income targets, and the lower bounds as points.
const tPoints = [[0, 0]];
for (const t of targets.targets) {
  const m = /^income_at:(\d+)$/.exec(t.metric);
  if (m) tPoints.push([Number(m[1]), t.target]);
}
tPoints.sort((a, b) => a[0] - b[0]);
const series = [];
series.push({ name: 'target', color: COLORS.target, width: 3, dash: '6 4', pts: tPoints });
if (sim) {
  const pts = [[0, 0], ...sim.series.filter((r) => r.checkpoint_s <= 600).map((r) => [r.checkpoint_s, r.income_all])];
  series.push({ name: `sim (${sim.profile})`, color: COLORS.sim, width: 2.5, pts });
}
if (blind) {
  const per = blind.runs.map((r) => [[0, 0], ...[10, 30, 60, 120, 180, 240, 300, 360, 420, 480, 540, 600]
    .map((s) => [s, r.metrics[`income_at:${s}`]]).filter(([, v]) => v !== null && v !== undefined)]);
  per.forEach((pts, i) => series.push({ name: `blind run ${i + 1}`, color: COLORS.run, width: 1.2, pts }));
  const med = [];
  for (const s of [0, 10, 30, 60, 120, 180, 240, 300, 360, 420, 480, 540, 600]) {
    const vs = per.map((pts) => (pts.find((p) => p[0] === s) || [s, null])[1]).filter((v) => v !== null).sort((a, b) => a - b);
    if (vs.length === per.length && vs.length) med.push([s, vs[Math.floor(vs.length / 2)]]);
  }
  series.push({ name: 'blind median', color: COLORS.median, width: 3, pts: med });
}
const maxY = Math.max(...series.flatMap((s) => s.pts.map((p) => p[1] || 0)), 100) * 1.08;
const Y = (v) => H - pad.b - (v / maxY) * (H - pad.t - pad.b);

const out = [];
out.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" font-family="sans-serif" font-size="12">`);
out.push(`<rect width="${W}" height="${H}" fill="#ffffff"/>`);
out.push(`<text x="${pad.l}" y="22" font-size="15" font-weight="bold">누적 생산 수입 (첫 10분) ${title}</text>`);
for (let s = 0; s <= 600; s += 60) {
  out.push(`<line x1="${X(s)}" y1="${pad.t}" x2="${X(s)}" y2="${H - pad.b}" stroke="#eee"/>`);
  out.push(`<text x="${X(s)}" y="${H - pad.b + 16}" text-anchor="middle" fill="#555">${s / 60}:00</text>`);
}
const step = Math.pow(10, Math.floor(Math.log10(maxY / 4)));
const tick = [1, 2, 5].map((k) => k * step).find((k) => maxY / k <= 6) || step * 10;
for (let v = 0; v <= maxY; v += tick) {
  out.push(`<line x1="${pad.l}" y1="${Y(v)}" x2="${W - pad.r}" y2="${Y(v)}" stroke="#eee"/>`);
  out.push(`<text x="${pad.l - 6}" y="${Y(v) + 4}" text-anchor="end" fill="#555">$${v}</text>`);
}
series.forEach((s, i) => {
  const d = s.pts.map((p, j) => `${j ? 'L' : 'M'}${X(p[0]).toFixed(1)},${Y(p[1]).toFixed(1)}`).join(' ');
  out.push(`<path d="${d}" fill="none" stroke="${s.color}" stroke-width="${s.width}"${s.dash ? ` stroke-dasharray="${s.dash}"` : ''}/>`);
  if (!s.name.startsWith('blind run') || i === series.findIndex((x) => x.name.startsWith('blind run'))) {
    const ly = pad.t + 18 * series.filter((x, k) => k < i && (!x.name.startsWith('blind run') || k === series.findIndex((y) => y.name.startsWith('blind run')))).length;
    out.push(`<line x1="${W - pad.r + 12}" y1="${ly}" x2="${W - pad.r + 36}" y2="${ly}" stroke="${s.color}" stroke-width="${s.width}"${s.dash ? ` stroke-dasharray="${s.dash}"` : ''}/>`);
    out.push(`<text x="${W - pad.r + 42}" y="${ly + 4}">${s.name.startsWith('blind run') ? 'blind runs' : s.name}</text>`);
  }
});
out.push('</svg>');
fs.writeFileSync(opt('out'), out.join('\n'));

// The milestone strip: one row per primary time target.
if (opt('milestones') && blind) {
  const rows = blind.rows.filter((r) => r.metric.startsWith('journey:') && r.kind === 'exact');
  const MW = 720;
  const rowH = 34;
  const MH = 50 + rows.length * rowH;
  const MX = (s) => 150 + (s / 420) * (MW - 180);
  const m = [`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${MW} ${MH}" font-family="sans-serif" font-size="12">`,
    `<rect width="${MW}" height="${MH}" fill="#ffffff"/>`, `<text x="12" y="22" font-size="15" font-weight="bold">처음 해낸 시각: 목표(±10%) · 실행 · 중앙값 ${title}</text>`];
  for (let s = 0; s <= 420; s += 60) m.push(`<text x="${MX(s)}" y="${MH - 8}" text-anchor="middle" fill="#555">${s / 60}:00</text>`, `<line x1="${MX(s)}" y1="34" x2="${MX(s)}" y2="${MH - 22}" stroke="#eee"/>`);
  rows.forEach((r, i) => {
    const y = 48 + i * rowH;
    m.push(`<text x="12" y="${y + 4}">${r.id} ${r.metric.replace('journey:', '')}</text>`);
    m.push(`<rect x="${MX(r.target * 0.9)}" y="${y - 8}" width="${MX(r.target * 1.1) - MX(r.target * 0.9)}" height="16" fill="#d0e2ff"/>`);
    m.push(`<line x1="${MX(r.target)}" y1="${y - 10}" x2="${MX(r.target)}" y2="${y + 10}" stroke="${COLORS.target}" stroke-width="2"/>`);
    r.runs.forEach((v) => { if (v !== null) m.push(`<circle cx="${MX(Math.min(v, 420))}" cy="${y}" r="4" fill="${COLORS.run}"/>`); else m.push(`<text x="${MX(420) - 30}" y="${y + 4}" fill="#c92a2a">never</text>`); });
    if (r.median !== null) m.push(`<path d="M${MX(Math.min(r.median, 420)) - 6},${y} l6,-7 l6,7 l-6,7 z" fill="${r.pass ? COLORS.median : '#c92a2a'}"/>`);
  });
  m.push('</svg>');
  fs.writeFileSync(opt('milestones'), m.join('\n'));
}
