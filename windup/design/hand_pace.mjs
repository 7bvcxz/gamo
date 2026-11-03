// Step 01 hand model of the CORE_LOOP.md hypotheses (H1-H6). NOT the game:
// a 0.1 s integration used only to make the hypothesis table consistent.
// The game (Step 04+) reads windup/data/ and its own simulator (Step 08).
const P = { base: 1, gear: 0.25, costs: [90, 170, 280, 430, 640, 920, 1300, 1800, 2500, 3400, 4600, 6200],
  doll: [1.0, 1.4, 1.8, 2.3, 2.8, 3.4, 4.0, 4.7, 5.4, 6.2, 7.0, 8.0] };
function run(qps, start, idleAfter, T = 1800, dt = 0.1) {
  let t = 0, e = 0, k = 0; const aw = []; let manual = 0, auto = 0;
  while (t < T && k < 12) {
    const winding = t >= start && (idleAfter == null || k < idleAfter);
    const m = winding ? qps * P.base * (1 + P.gear * k) : 0;
    let a = 0; for (let i = 0; i < k; i++) a += P.doll[i];
    e += (m + a) * dt; manual += m * dt; auto += a * dt; t += dt;
    if (e >= P.costs[k]) { e -= P.costs[k]; k++; aw.push(t.toFixed(0)); }
  }
  return { aw: aw.join(' '), share: (manual / (manual + auto)).toFixed(2) };
}
for (const [n, q, s, i] of [['engaged 4/s', 4, 2, null], ['novice 2/s', 2, 5, null], ['idle after 1', 4, 2, 1]])
  console.log(n.padEnd(14), JSON.stringify(run(q, s, i)));
