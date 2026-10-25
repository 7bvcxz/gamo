// Pure helpers of the blind playtest harness (Step 45): timing, the action
// log, coordinates, and what the controller reads from the game's own save.
// Nothing here is shown to the blind player.

export const SESSION_MINUTES = 10;
export const MAX_WAIT_SECONDS = 30;

// mm:ss of a number of seconds.
export function clock(seconds) {
  const s = Math.max(0, Math.floor(seconds));
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
}

// The session's own clock: it starts at the player's first look (the game is
// loaded and the player is there), and runs for `minutes` real minutes.
export class SessionClock {
  constructor(minutes = SESSION_MINUTES, now = () => Date.now()) {
    this.limitMs = minutes * 60_000;
    this.now = now;
    this.startedAt = null;
  }
  start() {
    if (this.startedAt === null) this.startedAt = this.now();
  }
  get started() {
    return this.startedAt !== null;
  }
  elapsed() {
    return this.started ? (this.now() - this.startedAt) / 1000 : 0;
  }
  remaining() {
    return this.started ? Math.max(0, this.limitMs / 1000 - this.elapsed()) : this.limitMs / 1000;
  }
  over() {
    return this.started && this.remaining() <= 0;
  }
}

// Screenshot pixels (what the player sees and points at) -> CSS pixels.
export function toCss(x, y, dpr, viewport) {
  const cx = Math.min(Math.max(x / dpr, 0), viewport.width - 1);
  const cy = Math.min(Math.max(y / dpr, 0), viewport.height - 1);
  return { x: cx, y: cy };
}

// Parses and checks one player command line: look | tap X Y | drag X1 Y1 X2 Y2
// | wait S | note TEXT | status. Returns {cmd, args} or {error}.
export function parseCommand(argv) {
  const [cmd, ...rest] = argv;
  const nums = rest.map(Number);
  switch (cmd) {
    case 'look':
    case 'status':
      return { cmd, args: {} };
    case 'tap':
      if (rest.length !== 2 || nums.some((n) => !Number.isFinite(n))) return { error: 'usage: tap X Y' };
      return { cmd, args: { x: nums[0], y: nums[1] } };
    case 'drag':
      if (rest.length !== 4 || nums.some((n) => !Number.isFinite(n))) return { error: 'usage: drag X1 Y1 X2 Y2' };
      return { cmd, args: { x1: nums[0], y1: nums[1], x2: nums[2], y2: nums[3] } };
    case 'wait': {
      const s = Number(rest[0]);
      if (!Number.isFinite(s) || s <= 0) return { error: `usage: wait SECONDS (1-${MAX_WAIT_SECONDS})` };
      return { cmd, args: { s: Math.min(s, MAX_WAIT_SECONDS) } };
    }
    case 'note':
      if (rest.join(' ').trim() === '') return { error: 'usage: note TEXT' };
      return { cmd, args: { text: rest.join(' ').slice(0, 2000) } };
    default:
      return { error: 'commands: look | tap X Y | drag X1 Y1 X2 Y2 | wait S | note TEXT | status' };
  }
}

// One line of the action log (JSON lines), stamped with the session clock.
export function logLine(t, cmd, args, result) {
  return JSON.stringify({ t: Math.round(t * 10) / 10, at: clock(t), cmd, ...args, ...result }) + '\n';
}

// What the controller reads from the game's own save (the localStorage
// mirror): a compact snapshot for milestone timing. Never shown to the player.
export function snapshotFromSave(text) {
  if (!text) return null;
  let env;
  try {
    env = JSON.parse(text);
  } catch {
    return null;
  }
  let state;
  try {
    state = typeof env.state === 'string' ? JSON.parse(env.state) : env.state;
  } catch {
    return null;
  }
  const sys = (state && state.systems) || {};
  const buildings = ((sys.buildings || {}).buildings || []).map((b) => b.type);
  const research = sys.research || {};
  return {
    sim_ms: (state.clock || {}).now_ms || 0,
    money: (sys.economy || {}).money ?? 0,
    level: (sys.progression || {}).level ?? 1,
    exp: (sys.progression || {}).exp ?? 0,
    land: ((sys.world || {}).land || []).length,
    land_bought: ((sys.land || {}).purchases || []).length,
    buildings,
    momos: ((sys.momo || {}).momos || []).length,
    assigned: ((sys.momo || {}).momos || []).filter((m) => m.assigned).length,
    research: Object.keys(research.completed || {}),
    tier: (sys.tiers || {}).tier ?? 0,
    crops: ((sys.inventory || {}).produced || {}).crop ?? 0,
    marks: ((sys.journey || {}).marks || []).map((m) => (typeof m === 'object' ? m : { id: m })),
  };
}

// Gaps longer than `seconds` between player actions (look excluded: looking
// is not acting) -- the idle intervals of the report.
export function idleIntervals(entries, seconds = 30) {
  const acts = entries.filter((e) => e.cmd === 'tap' || e.cmd === 'drag');
  const out = [];
  for (let i = 1; i < acts.length; i++) {
    const gap = acts[i].t - acts[i - 1].t;
    if (gap > seconds) out.push({ from: acts[i - 1].t, to: acts[i].t, gap: Math.round(gap) });
  }
  return out;
}

// The first moment in the controller snapshots where `pred` holds.
export function firstWhen(snapshots, pred) {
  for (const s of snapshots) if (s.state && pred(s.state)) return s.t;
  return null;
}
