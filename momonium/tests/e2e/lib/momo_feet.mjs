// Step 76: Momo's two feet in a screenshot -- the browser-side twin of
// tools/art/gen/momo_anchor.gd's measure. Cream blobs of a foot's size and
// shape (a filled oval; a seed or a drop is small, a blade's edge thin, a
// cuff sits above its foot), the pair side by side that stands lowest and
// most level; the root is midway between their bottom middles, on the lower
// one's line.
//
//   feet(rgba, width, height, hp) -> { x, y, feet: [...] } | { error, blobs }
// `hp` is Momo's stand height in the image's pixels (feet to fur curl).

// Cream on screen: Momo's fur and overalls under the island's light --
// light, warm, unsaturated.
export const isCream = (r, g, b) => r > 190 && g > 170 && b > 140 && r >= b && r - b < 80;

export function feet(rgba, W, H, hp) {
  const cream = new Uint8Array(W * H);
  for (let i = 0; i < W * H; i++) cream[i] = isCream(rgba[i * 4], rgba[i * 4 + 1], rgba[i * 4 + 2]) ? 1 : 0;
  const seen = new Uint8Array(W * H);
  const blobs = [];
  for (let s = 0; s < W * H; s++) {
    if (!cream[s] || seen[s]) continue;
    let lx = W, ly = H, hx = -1, hy = -1, n = 0;
    const st = [s];
    seen[s] = 1;
    while (st.length) {
      const p = st.pop();
      const x = p % W, y = (p / W) | 0;
      n++;
      if (x < lx) lx = x;
      if (y < ly) ly = y;
      if (x > hx) hx = x;
      if (y > hy) hy = y;
      if (x + 1 < W && cream[p + 1] && !seen[p + 1]) { seen[p + 1] = 1; st.push(p + 1); }
      if (x > 0 && cream[p - 1] && !seen[p - 1]) { seen[p - 1] = 1; st.push(p - 1); }
      if (y + 1 < H && cream[p + W] && !seen[p + W]) { seen[p + W] = 1; st.push(p + W); }
      if (y > 0 && cream[p - W] && !seen[p - W]) { seen[p - W] = 1; st.push(p - W); }
    }
    const w = hx - lx + 1, h = hy - ly + 1;
    blobs.push({ x: lx + w / 2, y: hy + 1, lo: lx, hi: hx + 1, w, h, n, fill: n / (w * h) });
  }
  const isFoot = (b) => b.fill >= 0.45 && b.n >= 0.004 * hp * hp && b.w >= 0.1 * hp && b.w <= 0.25 * hp && b.h >= 0.045 * hp && b.h <= 0.17 * hp;
  const cands = blobs.filter(isFoot).sort((a, b) => b.y - a.y);
  if (!cands.length) return { error: 'no foot', blobs: blobs.filter((b) => b.n > 0.002 * hp * hp) };
  // The pair that stands lowest and most level -- at the bottom: not higher
  // than the lowest blob by more than a partner may rise.
  const floor = cands[0].y - 0.12 * hp;
  let pair = null, best = -Infinity;
  for (let i = 0; i < cands.length; i++) {
    for (let j = i + 1; j < cands.length; j++) {
      const a = cands[i], b = cands[j];
      const dx = Math.abs(a.x - b.x), rise = Math.abs(a.y - b.y);
      if ((a.lo >= b.hi || a.hi <= b.lo) && dx >= 0.12 * hp && dx <= 0.5 * hp && rise <= 0.12 * hp && Math.min(a.y, b.y) >= floor) {
        const score = Math.min(a.y, b.y) - 0.5 * rise;
        if (score > best) { best = score; pair = [a, b]; }
      }
    }
  }
  if (!pair) return { error: 'one foot', blobs: cands };
  const [a, b] = pair;
  if (Math.abs(a.y - b.y) > 0.035 * hp) return { error: 'a foot lifted', blobs: pair };
  return { x: (a.x + b.x) / 2, y: Math.max(a.y, b.y), feet: pair };
}
