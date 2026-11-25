// Screenshots of the game at the viewports the issue names, during action.
// node views.mjs <outdir> <snow|bubble>
import { chromium, open, state, px, tap, rectCenter, sleep } from './lib.mjs';
import fs from 'node:fs';
const out = process.argv[2] || '/tmp/claude-1000/views';
fs.mkdirSync(out, { recursive: true });
const sizes = [[360, 800, true], [390, 844, true], [412, 915, true], [1280, 720, false]];
const browser = await chromium.launch();
for (const [w, h, touch] of sizes) {
  const { ctx, page, cdp, errors } = await open(browser, { w, h, touch, dpr: touch ? 2 : 1 });
  await sleep(700);
  if (touch) { const c = await rectCenter(page, 'pad'); await tap(cdp, c, 70); } else {
    const s = await state(page); const r = s.rects.pad; const p = await px(page, r[0] + r[2] / 2, r[1] + r[3] * 0.7);
    await page.mouse.move(p.x, p.y); await page.mouse.down(); await page.mouse.up();
  }
  await sleep(250);
  await page.screenshot({ path: `${out}/${w}x${h}.png` });
  const s = await state(page);
  console.log(`${w}x${h} view=${s.view} snow=${s.snow ?? s.pop} errors=${errors.length}`);
  await ctx.close();
}
await browser.close();
