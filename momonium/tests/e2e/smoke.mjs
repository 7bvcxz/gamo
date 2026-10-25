// Per-deploy smoke check. Not the E2E suite: it only proves that the published
// build loads on a phone-shaped and a desktop-shaped browser, draws frames,
// reports the expected version and survives a tap/click without page errors.
//
//   node smoke.mjs [--url URL] [--version x.y.z] [--pack game-<hash>.pck]
import { chromium } from 'playwright';
import { openGame, bridge, PROFILES, PAGES_URL } from './lib/game.mjs';
import { decodePng, colorCount } from './lib/png.mjs';

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, a) => (v.startsWith('--') ? [...acc, [v.slice(2), a[i + 1]]] : acc), []));
const url = args.url || PAGES_URL;
let ok = true;
const report = [];

if (args.pack) {
  // The stable index carries the pack name it redirects to; until Pages has
  // published this deploy it still names the previous build.
  const html = await (await fetch(url + 'index.html', { cache: 'no-store' })).text();
  const served = html.includes(args.pack);
  report.push(`index.html names ${args.pack}: ${served}`);
  ok &&= served;
}

const browser = await chromium.launch();
for (const [name, profile] of Object.entries(PROFILES)) {
  const context = await browser.newContext(profile);
  const page = await context.newPage();
  const res = await openGame(page, url);
  const info = await bridge(page);
  const canvas = await page.$('canvas');
  const box = await canvas.boundingBox();
  if (profile.hasTouch) await page.touchscreen.tap(box.x + box.width / 2, box.y + box.height * 0.7);
  else await page.mouse.click(box.x + box.width / 2, box.y + box.height * 0.7);
  await page.waitForTimeout(800);
  const after = colorCount(decodePng(await canvas.screenshot()));
  const versionOk = !args.version || (info && info.version === args.version);
  const pass = res.colors >= 12 && after >= 12 && res.errors.length === 0 && versionOk;
  report.push(`${name}: ${pass ? 'PASS' : 'FAIL'} ready ${(res.readyMs / 1000).toFixed(1)}s colours ${res.colors}->${after} version ${info ? info.version : '-'} canvas ${Math.round(box.width)}x${Math.round(box.height)} errors ${res.errors.length}`);
  for (const e of res.errors.slice(0, 5)) report.push('    ' + e);
  if (args.shot) await page.screenshot({ path: `${args.shot}-${name}.png` });
  ok &&= pass;
  await context.close();
}
await browser.close();
console.log(report.join('\n'));
console.log(ok ? 'SMOKE PASS' : 'SMOKE FAIL');
process.exit(ok ? 0 : 1);
