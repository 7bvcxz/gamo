extends RefCounted
# Bubble Wrap Empire rules: no drawing, no input, so a headless test can play a
# whole session. One currency (POP). A trigger pops one bubble and then a wave
# spreads through its neighbours over the next fraction of a second.

const COLS: int = 7
const ROWS: int = 10
const MAX_LEVEL: int = 10
const BASE_COST: Array[float] = [14.0, 4.0, 8.0, 16.0, 50.0]
const COST_GROWTH: float = 2.1
const NAMES: Array[String] = ["Radius", "Chain", "Value", "Refill", "Mega"]
const I_RADIUS: int = 0
const I_CHAIN: int = 1
const I_VALUE: int = 2
const I_REFILL: int = 3
const I_MEGA: int = 4

const HOP_DELAY: float = 0.075       # seconds between a bubble and the ones it sets off
const REFILL_WAIT: float = 0.35      # a popped bubble rests this long before it re-inflates
const TRIGGER_REFRACTORY: float = 0.2  # a second touch this soon is the same touch, not a new trigger
# A touch that follows the last one sooner than this pays proportionally less
# (never less than a quarter): the touch is taken, the pop happens, only the
# value of that wave is softened. Waiting costs nothing and rapid taps gain little.
const RAPID_WINDOW: float = 0.8
const RAPID_FLOOR: float = 0.25
const MAX_NEIGHBOUR: float = 5.2

var pop: float = 0.0
var earned: float = 0.0
var lv: Array[int] = [0, 0, 0, 0, 0]
var time: float = 0.0
var pos: Array[Vector2] = []            # bubble centres, in cell units
var fill: Array[float] = []             # 1 = full and poppable
var wait: Array[float] = []
var pop_at: Array[float] = []           # scheduled pop time, -1 if none
var depth: Array[int] = []
var wave_id: Array[int] = []
var mega_flag: Array[bool] = []
var neighbours: Array = []              # per bubble: [[index, dist], ...] sorted by dist
var pending: Array[int] = []
var events: Array = []
var triggers: int = 0
var pops: int = 0
var last_trigger_t: float = -99.0
var mega_clock: float = 0.0
var waves: Dictionary = {}
var _next_wave: int = 1
var last_wave_count: int = 0
var last_wave_secs: float = 0.0
var wave_total: int = 0            # finished waves
var wave_pops_sum: int = 0
var wave_secs_sum: float = 0.0
var wave_max: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 5) -> void:
	_rng.seed = seed_value
	for r in ROWS:
		for c in COLS:
			pos.append(Vector2(float(c) + (0.5 if r % 2 == 1 else 0.0), float(r) * 0.866))
			fill.append(1.0)
			wait.append(0.0)
			pop_at.append(-1.0)
			depth.append(0)
			wave_id.append(0)
			mega_flag.append(false)
	for i in pos.size():
		var list: Array = []
		for j in pos.size():
			if i != j:
				var d: float = pos[i].distance_to(pos[j])
				if d <= MAX_NEIGHBOUR:
					list.append([j, d])
		list.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
		neighbours.append(list)


# ---- derived numbers --------------------------------------------------------

func radius() -> float:
	return 1.05 + 0.18 * lv[I_RADIUS]

func hops() -> int:
	return lv[I_CHAIN]

func chance() -> float:
	return clampf(0.62 + 0.04 * lv[I_CHAIN], 0.0, 1.0)

func value() -> float:
	return pow(1.35, lv[I_VALUE])

func refill_time() -> float:
	return 6.0 / (1.0 + 0.45 * lv[I_REFILL])

func mega_period() -> float:
	return 26.0 - 2.0 * lv[I_MEGA]

func mega_unlocked() -> bool:
	return lv[I_MEGA] > 0

func mega_ready() -> bool:
	return mega_unlocked() and mega_clock >= mega_period()

func cost(i: int) -> float:
	return roundf(BASE_COST[i] * pow(COST_GROWTH, lv[i]))

func maxed(i: int) -> bool:
	return lv[i] >= MAX_LEVEL

func can_buy(i: int) -> bool:
	return not maxed(i) and pop >= cost(i)

func full_count() -> int:
	var n: int = 0
	for f in fill:
		if f >= 0.999:
			n += 1
	return n

func poppable(i: int) -> bool:
	return fill[i] >= 0.999 and pop_at[i] < 0.0


# ---- actions ----------------------------------------------------------------

# Seed the wave at the full bubble nearest to `at` (cell units). Returns the
# seed index, or -1 when nothing could be popped (an empty sheet costs nothing).
func trigger(at: Vector2) -> int:
	if time - last_trigger_t < TRIGGER_REFRACTORY:
		return -1
	var seed_i: int = -1
	var best: float = 1e9
	for i in pos.size():
		if poppable(i):
			var d: float = pos[i].distance_to(at)
			if d < best:
				best = d
				seed_i = i
	if seed_i < 0:
		return -1
	var scale: float = clampf((time - last_trigger_t) / RAPID_WINDOW, RAPID_FLOOR, 1.0)
	last_trigger_t = time
	triggers += 1
	var mega: bool = mega_ready()
	if mega:
		mega_clock = 0.0
	var wid: int = _next_wave
	_next_wave += 1
	waves[wid] = {"seed": seed_i, "total": 0.0, "count": 0, "left": 0, "t0": time, "mega": mega, "scale": scale}
	_schedule(seed_i, 0, time, wid, mega)
	var rad: float = radius() * (1.7 if mega else 1.0)
	var max_hops: int = hops() + (2 if mega else 0)
	var p: float = 1.0 if mega else chance()
	var frontier: Array[int] = [seed_i]
	for d in range(1, max_hops + 1):
		var nxt: Array[int] = []
		for b in frontier:
			for pair in neighbours[b]:
				if float(pair[1]) > rad:
					break
				var n: int = int(pair[0])
				if poppable(n) and _rng.randf() < p:
					_schedule(n, d, pop_at[b] + HOP_DELAY + 0.02 * float(pair[1]), wid, mega)
					nxt.append(n)
		frontier = nxt
		if frontier.is_empty():
			break
	events.append({"t": "trigger", "seed": seed_i, "mega": mega, "wave": wid})
	return seed_i


func _schedule(i: int, d: int, at_t: float, wid: int, mega: bool) -> void:
	pop_at[i] = at_t
	depth[i] = d
	wave_id[i] = wid
	mega_flag[i] = mega
	pending.append(i)
	waves[wid]["left"] += 1


func buy(i: int) -> bool:
	if not can_buy(i):
		return false
	pop -= cost(i)
	lv[i] += 1
	events.append({"t": "buy", "i": i})
	return true


func step(delta: float) -> void:
	var left: float = delta
	while left > 0.0:
		var dt: float = minf(left, 0.05)
		left -= dt
		_step(dt)


func _step(dt: float) -> void:
	time += dt
	if mega_unlocked() and mega_clock < mega_period():
		mega_clock += dt
	# scheduled pops
	var i: int = pending.size() - 1
	while i >= 0:
		var b: int = pending[i]
		if pop_at[b] <= time:
			pending.remove_at(i)
			_pop(b)
		i -= 1
	# refill
	var rate: float = 1.0 / refill_time()
	for b in pos.size():
		if fill[b] < 1.0 and pop_at[b] < 0.0:
			if wait[b] > 0.0:
				wait[b] -= dt
			else:
				fill[b] = minf(1.0, fill[b] + rate * dt)


func _pop(b: int) -> void:
	var w: Dictionary = waves[wave_id[b]]
	var reward: float = value() * (1.0 + 0.08 * depth[b]) * (2.0 if mega_flag[b] else 1.0) * float(w["scale"])
	pop += reward
	earned += reward
	pops += 1
	fill[b] = 0.0
	wait[b] = REFILL_WAIT
	pop_at[b] = -1.0
	w["total"] += reward
	w["count"] += 1
	w["left"] -= 1
	events.append({"t": "pop", "i": b, "depth": depth[b], "reward": reward, "mega": mega_flag[b]})
	if w["left"] <= 0:
		last_wave_count = w["count"]
		last_wave_secs = time - float(w["t0"])
		wave_total += 1
		wave_pops_sum += int(w["count"])
		wave_secs_sum += last_wave_secs
		wave_max = maxi(wave_max, int(w["count"]))
		events.append({"t": "wave", "seed": w["seed"], "total": w["total"], "count": w["count"], "mega": w["mega"]})
		waves.erase(wave_id[b])


func drain_events() -> Array:
	var out: Array = events
	events = []
	return out
