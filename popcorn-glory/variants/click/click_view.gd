extends PopPlayView

## A Click & Pop's picture: every press squashes the machine and throws its
## popcorn at once. Fast presses (under STREAK_MS apart) build a streak that
## throws the pieces higher and wider -- the picture only; the money is the
## same (no hidden rule).

const STREAK_MS := 350

## A press first presses the machine down (anticipation); IMPACT_S later it
## pops: the burst, the recoil, the coins. Every press is shown -- a press
## during another's anticipation queues its own pop, none is dropped.
const IMPACT_S := 0.06

var streak := 0
var best_streak := 0
var shown_pops := 0
var _last_press := -100000
var _pending: Array[Dictionary] = []   # {at, count, amount}


func _press() -> void:
	if now_ms - _last_press < STREAK_MS:
		streak += 1
	else:
		streak = 0
	best_streak = maxi(best_streak, streak)
	_last_press = now_ms
	squash(0.55)
	super()


func on_events(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		match String(e["type"]):
			"pop":
				_pending.append({"at": _t + IMPACT_S, "count": int(e["data"].get("count", 1)), "amount": 0})
			"earn":
				if not _pending.is_empty():
					_pending[_pending.size() - 1]["amount"] = int(e["data"].get("amount", 0))
			"upgrade":
				_on_upgrade(int(e["data"].get("level", 0)))


func _process(delta: float) -> void:
	while not _pending.is_empty() and float(_pending[0]["at"]) <= _t + delta:
		_impact(_pending.pop_front())
	super(delta)


func _impact(p: Dictionary) -> void:
	shown_pops += 1
	squash(0.0, 9.0)
	var n := int(p["count"])
	var lift := 1.0 + 0.04 * mini(streak, 10)
	# At least four pieces fly: one piece was invisible in a still frame (Step 08,
	# blind player: 'a tap mostly felt like a number ticking up'). Money is unchanged.
	fx.burst(machine_top(), clampi(n, 4, 16) if not reduced_motion else 1, machine_size() / 900.0, rng,
		PopPalette.CREAM, 0.9 + 0.03 * mini(streak, 10), lift)
	# A streak climbs a little in pitch: the hand hears its rhythm.
	_sound("pop_%d" % (1 + rng.randi() % 3), 1.0 + 0.03 * mini(streak, 10) + rng.randf_range(-0.04, 0.04))
	if int(p["amount"]) > 0:
		fx.coin(machine_top(), machine_size() / 900.0)
		_gain(int(p["amount"]))
		_sound("coin", 1.0, -8.0)


func _draw_over(ci: CanvasItem, base: Vector2, size_px: float) -> void:
	# A streak shows as a ring of sparks round the machine, brighter as it grows.
	if streak < 3 or now_ms - _last_press > STREAK_MS * 2:
		return
	var c := machine_centre()
	var k := mini(streak, 12)
	for i in k:
		var a := TAU * float(i) / k + _t * 3.0
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * size_px * 0.5, 6.0 + k * 0.6, Color(PopPalette.GOLD, 0.8))
