extends RefCounted
# Snowball Relay rules, with no drawing and no input -- so a headless test can
# play a whole session. One currency (snow). Mass is a state of the ball, never
# something you spend.
#
# Units: distance is in "units" (the ball starts about one unit across).

const MAX_LEVEL: int = 10
const BASE_COST: Array[float] = [8.0, 12.0, 16.0, 14.0, 20.0]
const COST_GROWTH: float = 1.85
const NAMES: Array[String] = ["Mass", "Power", "Momentum", "Attraction", "Impact"]
const I_MASS: int = 0
const I_POWER: int = 1
const I_MOMENTUM: int = 2
const I_ATTRACT: int = 3
const I_IMPACT: int = 4

# Pushes that arrive sooner than this after the last one count for less: a
# frantic swipe is accepted, it just is not worth more (soft saturation).
const PUSH_REFRACTORY: float = 1.5
# Decay shape: dx/dt = -(K/T) * (0.35 + 0.65 x), x = speed / v0. K makes a full
# push last about T seconds from v0 to a stop.
const DECAY_K: float = 1.56

var snow: float = 0.0
var earned: float = 0.0
var mass: float = 1.0
var dist: float = 0.0
var speed: float = 0.0
var lv: Array[int] = [0, 0, 0, 0, 0]
var time: float = 0.0
var props: Array = []
var events: Array = []
var pushes: int = 0
var breaks: int = 0
var last_push_t: float = -99.0
var roll_started_t: float = -1.0   # when the current roll began (speed was 0)
var last_roll_len: float = 0.0     # seconds the last finished roll lasted
var rolls: int = 0                 # finished rolls
var roll_len_sum: float = 0.0
var moving_time: float = 0.0       # seconds the ball was rolling at all

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_prop_d: float = 5.0


func _init(seed_value: int = 7) -> void:
	_rng.seed = seed_value
	_fill_props()


# ---- derived numbers --------------------------------------------------------

func radius() -> float:
	return pow(mass, 0.42)

func collect_radius() -> float:
	return radius() * (1.0 + 0.22 * lv[I_ATTRACT]) + 0.6

func v0() -> float:
	return 8.0 * (1.0 + 0.28 * lv[I_POWER])

func roll_time() -> float:
	return 3.0 + 2.4 * lv[I_MOMENTUM]

func vcap() -> float:
	return v0() * 1.0

func cost(i: int) -> float:
	return roundf(BASE_COST[i] * pow(COST_GROWTH, lv[i]))

func maxed(i: int) -> bool:
	return lv[i] >= MAX_LEVEL

func can_buy(i: int) -> bool:
	return not maxed(i) and snow >= cost(i)


# ---- actions ----------------------------------------------------------------

# strength 0..1 comes from the gesture (a tap is small, a swipe larger).
# Returns the speed that was actually added.
func push(strength: float) -> float:
	var since: float = time - last_push_t
	var rate: float = clampf(since / PUSH_REFRACTORY, 0.08, 1.0)
	var room: float = maxf(0.0, 1.0 - speed / vcap())
	var dv: float = v0() * clampf(strength, 0.0, 1.0) * rate * room
	last_push_t = time
	pushes += 1
	if speed <= 0.0001:
		roll_started_t = time
	speed += dv
	events.append({"t": "push", "dv": dv, "s": strength})
	return dv


func buy(i: int) -> bool:
	if not can_buy(i):
		return false
	snow -= cost(i)
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
	if speed <= 0.0:
		return
	moving_time += dt
	var x: float = speed / v0()
	var decay: float = DECAY_K / roll_time() * (0.35 + 0.65 * x)
	speed = maxf(0.0, speed - decay * v0() * dt)
	if speed < 0.02 * v0():
		speed = 0.0
		last_roll_len = time - roll_started_t
		rolls += 1
		roll_len_sum += last_roll_len
		events.append({"t": "stop"})
		return
	var dd: float = speed * dt
	dist += dd
	var gain: float = dd * 0.5 * collect_radius()
	snow += gain
	earned += gain
	mass += dd * 0.022 * (1.0 + 0.5 * lv[I_MASS])
	_fill_props()
	while props.size() > 0 and props[0]["d"] <= dist + 0.3 * radius():
		_break_prop(props.pop_front())


func _fill_props() -> void:
	while _next_prop_d < dist + 160.0:
		var roll: float = _rng.randf()
		var tier: int = 0
		var late: float = clampf(_next_prop_d / 600.0, 0.0, 1.0)
		if roll < 0.45 - 0.25 * late:
			tier = 0
		elif roll < 0.75 - 0.15 * late:
			tier = 1
		elif roll < 0.92 - 0.05 * late:
			tier = 2
		else:
			tier = 3
		var sizes: Array[float] = [0.5, 0.9, 1.6, 2.4]
		var values: Array[float] = [2.0, 4.0, 9.0, 16.0]
		props.append({
			"d": _next_prop_d,
			"tier": tier,
			"size": sizes[tier],
			"value": values[tier],
			"off": _rng.randf_range(-0.8, 0.8),
			"seed": _rng.randi() % 1000,
		})
		_next_prop_d += (8.0 + _next_prop_d * 0.02) * _rng.randf_range(0.8, 1.25)


func _break_prop(p: Dictionary) -> void:
	var reward: float = float(p["value"]) * (1.0 + 0.6 * lv[I_IMPACT]) * (1.0 + radius() * 0.15)
	snow += reward
	earned += reward
	breaks += 1
	events.append({"t": "break", "tier": p["tier"], "size": p["size"], "off": p["off"], "reward": reward, "seed": p["seed"]})


func drain_events() -> Array:
	var out: Array = events
	events = []
	return out
