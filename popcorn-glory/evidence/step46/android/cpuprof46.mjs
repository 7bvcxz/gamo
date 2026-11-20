// Step 46: a CPU profile of an S23 frame at 44 machines (CDP Profiler, 4 s), top functions by self time.
import fs from 'node:fs';
import { chromium } from '@playwright/test';

const BASE = process.env.BASE;
const PLAN = JSON.parse(process.env.PLAN);
const browser = await chromium.connectOverCDP('http://127.0.0.1:9333');
const page = await browser.contexts()[0].newPage();
const call = (n, a) => page.evaluate(([x, y]) => window.popcorn.call(x, y), [n, a]);
await page.goto(BASE + 'about.html', { waitUntil: 'domcontentloaded' });
await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
await page.goto(BASE + '?dev=1#factory', { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => window.popcorn && window.popcorn.ready, null, { timeout: 120_000 });
await call('dev_money', 1e9);
await call('dev_build', { plan: PLAN.slice(0, Number(process.env.N || 44)), sign: 8, packer: 3 });
for (let i = 0; i < 6; i++) await call('dev_advance', 5000);
await page.waitForTimeout(3000);
const cdp = await page.context().newCDPSession(page);
await cdp.send('Profiler.enable');
await cdp.send('Profiler.setSamplingInterval', { interval: 500 });
await cdp.send('Profiler.start');
await page.waitForTimeout(4000);
const { profile } = await cdp.send('Profiler.stop');
const self = new Map();
const dt = profile.timeDeltas;
const byId = new Map(profile.nodes.map((n) => [n.id, n]));
const hits = new Map();
for (let i = 0; i < profile.samples.length; i++) hits.set(profile.samples[i], (hits.get(profile.samples[i]) || 0) + (dt[i] || 0));
let total = 0;
for (const [id, t] of hits) { const n = byId.get(id); const k = `${n.callFrame.functionName || '(anon)'} @${(n.callFrame.url || '').split('/').pop()}`; self.set(k, (self.get(k) || 0) + t); total += t; }
const top = [...self.entries()].sort((a, b) => b[1] - a[1]).slice(0, 40).map(([k, t]) => [k, Math.round(t / 1000), Math.round(t / total * 1000) / 10]);
await page.evaluate(() => { for (const k of Object.keys(localStorage)) if (k.startsWith('popcorn-glory.')) localStorage.removeItem(k); });
await page.close();
await browser.close();
fs.writeFileSync(process.argv[2], JSON.stringify({ total_ms: Math.round(total / 1000), top }, null, 2));
for (const r of top.slice(0, 30)) console.log(r.join('  '));
