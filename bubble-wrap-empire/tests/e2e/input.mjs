// One gesture must be exactly one trigger, for touch and for mouse, and a
// second finger or a cancelled touch must not start a wave.
import { chromium, open, state, px, rectCenter, sleep } from './lib.mjs';
const browser = await chromium.launch();
let fails = 0;
const ok = (c, m) => { console.log((c ? 'ok   ' : 'FAIL ') + m); if (!c) fails++; };

// touch
{
  const { page, cdp, errors } = await open(browser, { w: 390, h: 844, touch: true });
  await sleep(600);
  const pad = await rectCenter(page, 'pad');
  const ts = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
  await ts('touchStart', [{ x: pad.x, y: pad.y, id: 1 }]); await sleep(60); await ts('touchEnd', []);
  await sleep(500);
  let s = await state(page);
  ok(s.triggers === 1 && s.pops === 1, `touch tap = 1 trigger (triggers=${s.triggers}, pops=${s.pops})`);
  // a very short direction-free swipe is the same single trigger
  await sleep(300);
  await ts('touchStart', [{ x: pad.x - 20, y: pad.y, id: 1 }]); await sleep(30);
  await ts('touchMove', [{ x: pad.x, y: pad.y + 10, id: 1 }]); await sleep(30);
  await ts('touchMove', [{ x: pad.x + 25, y: pad.y - 5, id: 1 }]); await sleep(30); await ts('touchEnd', []);
  await sleep(500);
  s = await state(page);
  ok(s.triggers === 2, `short swipe = 1 trigger (triggers=${s.triggers})`);
  // second finger while the first is down: still one trigger
  await sleep(300);
  await ts('touchStart', [{ x: pad.x, y: pad.y, id: 1 }]); await sleep(40);
  await ts('touchStart', [{ x: pad.x, y: pad.y, id: 1 }, { x: pad.x - 40, y: pad.y - 30, id: 2 }]); await sleep(40);
  await ts('touchEnd', []); await sleep(500);
  s = await state(page);
  ok(s.triggers === 3, `two fingers = 1 trigger (triggers=${s.triggers})`);
  // (a cancelled touch is checked in Step 04: Godot Web delivers touchcancel as a plain release)
  // a tap on an affordable upgrade buys it and starts no wave (3 POP so far: Chain costs 4 -> afford after one more)
  const before = (await state(page)).triggers;
  const up = await rectCenter(page, 'up1');
  await ts('touchStart', [{ x: up.x, y: up.y, id: 1 }]); await sleep(40); await ts('touchEnd', []); await sleep(300);
  s = await state(page);
  ok(s.triggers === before && s.lv[1] <= 1, `button tap starts no wave (triggers ${before} -> ${s.triggers}, lv=${s.lv})`);
  ok(errors.length === 0, 'no browser errors (touch) ' + JSON.stringify(errors.slice(0, 2)));
  await page.context().close();
}
// mouse (desktop, landscape)
{
  const { page, errors } = await open(browser, { w: 1280, h: 720, touch: false, dpr: 1 });
  await sleep(600);
  const s0 = await state(page);
  const r = s0.rects.pad;
  const p = await px(page, r[0] + r[2] / 2, r[1] + r[3] / 2);
  await page.mouse.move(p.x, p.y); await page.mouse.down(); await sleep(60); await page.mouse.up();
  await sleep(500);
  const s = await state(page);
  ok(s.triggers === 1 && s.pops === 1, `mouse click = 1 trigger (triggers=${s.triggers})`);
  ok(errors.length === 0, 'no browser errors (mouse) ' + JSON.stringify(errors.slice(0, 2)));
  await page.screenshot({ path: process.argv[2] ? `${process.argv[2]}/desktop.png` : '/tmp/claude-1000/bub-desktop.png' });
}
console.log('FAILS', fails);
await browser.close();
process.exit(fails ? 1 : 0);
