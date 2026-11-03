extends PopPlayView

## A Click & Pop's picture: every press squashes the machine and throws its
## popcorn at once. Fast presses (under STREAK_MS apart) build a streak that
## throws the pieces higher and wider -- the picture only; the money is the
## same (no hidden rule).

const STREAK_MS := 350

var streak := 0
var best_streak := 0
var _last_press := -100000


func _press() -> void:
	if now_ms - _last_press < STREAK_MS:
		streak += 1
	else:
		streak = 0
	best_streak = maxi(best_streak, streak)
	_last_press = now_ms
	super()


func on_events(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		match String(e["type"]):
			"pop":
				_squash = 1.0
				var n := int(e["data"].get("count", 1))
				var lift := 1.0 + 0.04 * mini(streak, 10)
				fx.burst(machine_top(), mini(n, 16) if not reduced_motion else 1, machine_size() / 900.0, rng,
					PopPalette.CREAM, 0.9 + 0.03 * mini(streak, 10), lift)
			"earn":
				fx.coin(machine_top(), machine_size() / 900.0)
				_gain(int(e["data"].get("amount", 0)))
			"upgrade":
				_squash = 1.0
				fx.burst(machine_top(), 18 if not reduced_motion else 2, machine_size() / 900.0, rng, PopPalette.GOLD)


func _draw_over(ci: CanvasItem, base: Vector2, size_px: float) -> void:
	# A streak shows as a ring of sparks round the machine, brighter as it grows.
	if streak < 3 or now_ms - _last_press > STREAK_MS * 2:
		return
	var c := machine_centre()
	var k := mini(streak, 12)
	for i in k:
		var a := TAU * float(i) / k + _t * 3.0
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * size_px * 0.5, 6.0 + k * 0.6, Color(PopPalette.GOLD, 0.8))
