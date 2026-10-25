// Real multi-touch through the Chrome DevTools Protocol. Playwright's
// touchscreen only taps; drags and pinches need touchStart/Move/End.
async function cdp(page) {
  if (!page.__cdp) page.__cdp = await page.context().newCDPSession(page);
  return page.__cdp;
}

const pt = (p, id) => ({ x: p.x, y: p.y, id, radiusX: 2, radiusY: 2, force: 1 });

export async function touchDrag(page, from, to, steps = 10) {
  const s = await cdp(page);
  await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [pt(from, 0)] });
  for (let i = 1; i <= steps; i++) {
    const p = { x: from.x + ((to.x - from.x) * i) / steps, y: from.y + ((to.y - from.y) * i) / steps };
    await s.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [pt(p, 0)] });
    await page.waitForTimeout(16);
  }
  await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

// Two fingers centred on `c`, moving from `d0` apart to `d1` apart horizontally.
export async function pinch(page, c, d0, d1, steps = 10) {
  const s = await cdp(page);
  const at = (d) => [pt({ x: c.x - d / 2, y: c.y }, 0), pt({ x: c.x + d / 2, y: c.y }, 1)];
  await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: at(d0) });
  for (let i = 1; i <= steps; i++) {
    await s.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: at(d0 + ((d1 - d0) * i) / steps) });
    await page.waitForTimeout(16);
  }
  await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}
