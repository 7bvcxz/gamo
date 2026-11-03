// Turns a test_all.sh run into report.json + report.md (Step 07): each check PASSED / FAILED / SKIPPED
// with its cause, the git SHA, the build, and the console errors of failed browser checks.
import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';

const [out, headless, deploy, deployWhy, browser, browserWhy] = process.argv.slice(2);
const sh = (c) => { try { return execSync(c, { encoding: 'utf8' }).trim(); } catch { return ''; } };
const game = path.resolve(out, '../../..');
const report = {
  _doc: 'AUTOMATED test report (popcorn-glory/tools/test_all.sh). PASSED / FAILED / SKIPPED (with cause).',
  sha: sh(`git -C ${game} rev-parse --short=12 HEAD`),
  dirty: sh(`git -C ${game} status --porcelain -- ${game} ':(exclude)${game}/evidence' ':(exclude)${game}/tests/results'`) !== '',
  build: (() => { try { return JSON.parse(fs.readFileSync(path.resolve(game, '../docs/popcorn-glory/version.json'), 'utf8')); } catch { return null; } })(),
  when: new Date().toISOString(),
  stages: { headless, deploy: deploy + (deployWhy ? ` (${deployWhy})` : ''), browser: browser + (browserWhy ? ` (${browserWhy})` : '') },
  headless_summary: (fs.existsSync(path.join(out, 'headless.log')) ? fs.readFileSync(path.join(out, 'headless.log'), 'utf8').match(/\d+ passed, \d+ failed[^\n]*/)?.[0] : null) ?? null,
  browser_checks: [],
};
const json = path.join(out, 'e2e.json');
if (fs.existsSync(json) && browser !== 'SKIPPED') {
  const walk = (suite, file) => {
    for (const s of suite.suites ?? []) walk(s, s.file ?? file);
    for (const spec of suite.specs ?? []) for (const t of spec.tests) {
      const r = t.results[t.results.length - 1] ?? {};
      const skipped = t.status === 'skipped' || r.status === 'skipped';
      report.browser_checks.push({
        spec: file, title: spec.title, project: t.projectName,
        status: skipped ? 'SKIPPED' : (t.status === 'expected' ? 'PASSED' : 'FAILED'),
        cause: skipped ? (t.annotations.find((a) => a.type === 'skip')?.description ?? 'skipped') : undefined,
        error: !skipped && t.status !== 'expected' ? (r.error?.message ?? '').replace(/\u001b\[[0-9;]*m/g, '').split('\n').slice(0, 6).join('\n') : undefined,
        notes: t.annotations.filter((a) => a.type !== 'skip').map((a) => `${a.type}: ${a.description}`),
        ms: r.duration,
      });
    }
  };
  const j = JSON.parse(fs.readFileSync(json, 'utf8'));
  for (const s of j.suites) walk(s, s.file);
}
const count = (st) => report.browser_checks.filter((c) => c.status === st).length;
report.browser_totals = { passed: count('PASSED'), failed: count('FAILED'), skipped: count('SKIPPED') };
fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
let md = `# Popcorn test report (AUTOMATED)\n\n- git ${report.sha}${report.dirty ? ' (uncommitted changes)' : ''} · build ${report.build?.version ?? '?'} ${report.build?.pack ?? ''}\n- ${report.when}\n`;
md += `- headless: **${headless}** ${report.headless_summary ? `(${report.headless_summary})` : ''}\n- deploy: **${report.stages.deploy}**\n- browser: **${report.stages.browser}** — passed ${report.browser_totals.passed}, failed ${report.browser_totals.failed}, skipped ${report.browser_totals.skipped}\n\n`;
md += '| spec | check | project | status | cause / notes |\n|---|---|---|---|---|\n';
for (const c of report.browser_checks) md += `| ${c.spec} | ${c.title} | ${c.project} | ${c.status} | ${(c.cause ?? c.error ?? c.notes.join('; ')).replace(/\n/g, ' ').replace(/\|/g, '/').slice(0, 220)} |\n`;
fs.writeFileSync(path.join(out, 'report.md'), md);
console.log(`report: ${path.join(out, 'report.md')} — browser passed ${report.browser_totals.passed}, failed ${report.browser_totals.failed}, skipped ${report.browser_totals.skipped}`);
