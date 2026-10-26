// The blind scorer (Step 50): times placed on the session clock from the
// game's own save, income between saves, the median of runs with "never"
// counted as never, and pass/fail and relative error as targets.json defines.
//   node --test momonium/tools/balance_optimizer/test/*.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { measure, score, observe } from '../score_blind.mjs';

// A fake run: the first look at epoch 1000 s; the game had been open 40 s by
// then (its clock 40 s ahead); saves every 15 s.
function fakeRun({ marks, incomes, firstTapIssued = 9, extra = {} }) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'blind-score-'));
  fs.mkdirSync(path.join(dir, 'controller'));
  const started = 1_000_000; // ms
  const lines = incomes.map(([t, income], i) => JSON.stringify({ t: t + 5, started_at: started, state: {
    sim_ms: (t + 40) * 1000, saved_unix: 1000 + t, income, jobs: 10 * (i + 1), momo_jobs: 8 * (i + 1), level: 3, buildings: ['farm', 'farm', 'research'],
    land_bought: 1, momos: 2, research_levels: 1, letters: 2, marks: marks.map(([key, t2]) => ({ key, at_ms: (t2 + 40) * 1000 })), ...extra } }));
  fs.writeFileSync(path.join(dir, 'controller', 'state.jsonl'), lines.join('\n') + '\n');
  fs.writeFileSync(path.join(dir, 'controller', 'actions.jsonl'), [
    JSON.stringify({ t: 0.6, cmd: 'look' }), JSON.stringify({ t: firstTapIssued + 1.5, issued: firstTapIssued, cmd: 'tap' })].join('\n') + '\n');
  return dir;
}

test('firsts land on the session clock, and income is interpolated between saves', () => {
  const run = fakeRun({ marks: [['sale', 10], ['momo_income', 50], ['land', 150]], incomes: [[0, 0], [15, 3], [30, 3], [45, 6], [60, 30], [600, 1000], [615, 1030]] });
  const m = measure(run);
  assert.equal(Math.round(m.journey.sale), 10);
  assert.equal(Math.round(observe(m, 'journey:income')), 10, 'income is the first sale');
  assert.equal(Math.round(observe(m, 'journey:land')), 150);
  assert.equal(m.metrics['income_at:30'], 3);
  assert.equal(m.metrics['income_at:600'], 1000);
  assert.equal(m.metrics['first_reward_after_tap'], 1, 'from the tap being issued to the first sale');
  assert.equal(m.metrics['meaningful_at:600'], 2 + 2 + 1 + 1 + 1 + 2, 'levels, new buildings, land, hire, research, letters');
});

test('the median counts a run that never got there as never', () => {
  const targets = { tolerance: 0.1, targets: [
    { id: 'T2', metric: 'journey:land', kind: 'exact', target: 150, weight: 2, primary: true },
    { id: 'P1', metric: 'journey:income', kind: 'max', target: 15, primary: true }] };
  const runs = [
    measure(fakeRun({ marks: [['sale', 9], ['land', 140]], incomes: [[0, 0], [600, 900]] })),
    measure(fakeRun({ marks: [['sale', 11], ['land', 160]], incomes: [[0, 0], [600, 900]] })),
    measure(fakeRun({ marks: [['sale', 12]], incomes: [[0, 0], [600, 900]] })),
  ];
  const r = score(runs, targets);
  const land = r.rows.find((x) => x.id === 'T2');
  assert.equal(Math.round(land.median), 160, 'two runs and a never: the median is the later of the two');
  assert.ok(Math.abs(land.error - 10 / 150) < 1e-9);
  assert.equal(land.pass, true);
  const missing = score([runs[2], runs[2], runs[0]], targets).rows.find((x) => x.id === 'T2');
  assert.equal(missing.median, null, 'most runs never got there: never');
  assert.equal(missing.pass, false, 'and that fails');
  assert.equal(r.rows.find((x) => x.id === 'P1').pass, true, 'a max target passes under its bound');
});
