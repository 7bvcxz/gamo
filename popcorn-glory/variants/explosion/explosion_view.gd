extends PopPlayView

## C Pop Explosion's picture. Eight slots in a row over the machine: each press
## drops a kernel into the next. The fuller the chamber, the more the machine
## rattles. A full chamber erupts, and how it erupts is the production stage
## (Step 04 addendum: three recognisable stages by about three minutes):
##   levels 0-2  SINGLE POP  one burst from the machine's top
##   levels 3-5  CLUSTER     bursts chaining off popcorn already in the air
##   levels 6+   FOUNTAIN    a steady column straight up for the whole show,
##                           and the chain around it
## Coins shower to the counter. At most VISUAL_MAX pieces are drawn per
## eruption; past that the pieces get bigger instead of more (PopFx.CAP).

const VISUAL_MAX := 300

var _show_total := 0.0      # pieces to draw in this show
var _show_drawn := 0.0
var _show_len := 1.0
var _show_age := 0.0
var _boom := 0.0
var _drops: Array[Dictionary] = []   # kernels falling into slots: {slot, age}
var _tier := 0


static func tier_of(level: int) -> int:
	return 0 if level < 3 else (1 if level < 6 else 2)


func _st() -> Dictionary:
	return rules.state()


func slot_point(i: int, n: int, base: Vector2, size_px: float) -> Vector2:
	var h := PopMachineArt.height_at(rules.level, size_px)
	var span := size_px * 0.7
	# Above everything the machine wears on top (its star and flags).
	return Vector2(base.x - span / 2 + span * (float(i) + 0.5) / n, base.y - h - size_px * 0.24)


func on_events(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		var d: Dictionary = e["data"]
		match String(e["type"]):
			"load":
				_drops.append({"slot": int(d["loaded"]) - 1, "age": 0.0})
				squash(0.35)
				# Each kernel a step higher: the chamber is audibly filling.
				_sound("clink", 0.8 + 0.08 * float(d["loaded"]))
			"erupt":
				var n := int(d["count"])
				_show_total = float(mini(n, VISUAL_MAX)) if not reduced_motion else 6.0
				_show_drawn = 0.0
				_show_len = maxf(0.2, float(d["show_ms"]) / 1000.0)
				_show_age = 0.0
				_boom = 1.0
				squash(0.0, 12.0)
				_tier = tier_of(int(d["level"]))
				var s := machine_size() / 900.0
				var first := mini(int(_show_total), 24 if _tier > 0 else int(_show_total))
				fx.burst(machine_top(), first, s, rng, PopPalette.CREAM, 1.3 if _tier > 0 else 1.0, 1.4, _big(n), 1.6)
				_show_drawn += first
				for i in mini(12, 2 + n / 20):
					fx.coin(machine_top() + Vector2(rng.randf_range(-80, 80), rng.randf_range(-40, 40)), s)
				_sound("boom", 1.0 - 0.02 * mini(int(d["level"]), 10))
				_sound("crackle")
			"earn":
				_gain(int(d.get("amount", 0)))
				_sound("coin", 1.0, -4.0)
			"upgrade":
				_on_upgrade(int(d.get("level", 0)))


## Past the drawn maximum, pieces grow instead of multiplying.
func _big(n: int) -> float:
	return 1.0 + clampf(log(maxf(1.0, float(n) / VISUAL_MAX)) / log(10.0), 0.0, 1.0) * 0.8


func _process(delta: float) -> void:
	_boom = maxf(0.0, _boom - delta * 1.8)
	for d: Dictionary in _drops:
		d["age"] = float(d["age"]) + delta
	while not _drops.is_empty() and float(_drops[0]["age"]) > 0.25:
		_drops.pop_front()
	if _show_drawn < _show_total and rules != null:
		# The chain: the rest of the pieces over the show, from the machine and
		# from pieces already flying.
		_show_age += delta
		var due := _show_total * clampf(_show_age / _show_len, 0.0, 1.0)
		var k := int(due - _show_drawn)
		var s := machine_size() / 900.0
		var big := _big(int(_st()["earned"]))
		for i in k:
			if _tier == 2 and i % 2 == 0:
				# The fountain: straight up from the top, gold-tinged.
				fx.burst(machine_top(), 1, s, rng, PopPalette.CREAM.lerp(PopPalette.GOLD, 0.35), 0.18, 1.45, big, 1.5)
			else:
				var from := fx.random_piece(rng, machine_top()) if i % 2 == 0 else machine_top()
				fx.burst(from, 1, s, rng, PopPalette.CREAM, PI, 0.7, big, 1.3)
		_show_drawn += k
	super(delta)


func _shake() -> Vector2:
	if rules == null or reduced_motion:
		return Vector2.ZERO
	var st := _st()
	var k := float(st["loaded"]) / maxf(1.0, float(st["slots"]))
	var amp := 5.0 * k * k + 14.0 * _boom
	return Vector2(sin(_t * 61.0), cos(_t * 47.0)) * amp


func _draw_over(ci: CanvasItem, base: Vector2, size_px: float) -> void:
	var st := _st()
	var n := int(st["slots"])
	var loaded := int(st["loaded"])
	var r := size_px * 0.035
	for i in n:
		var p := slot_point(i, n, base - _shake(), size_px)
		ci.draw_circle(p, r * 1.25, Color(1, 1, 1, 0.75))
		ci.draw_arc(p, r * 1.25, 0, TAU, 20, PopPalette.INK, 3.0)
		if i < loaded:
			var drop_y := 0.0
			for d: Dictionary in _drops:
				if int(d["slot"]) == i:
					drop_y = -size_px * 0.2 * (1.0 - float(d["age"]) / 0.25)
			if PopAtlas.has("kernel"):
				PopAtlas.draw(ci, "kernel", p + Vector2(0, drop_y), r * 2.6)
			else:
				ci.draw_circle(p + Vector2(0, drop_y), r, Color(0.85, 0.55, 0.2))
				ci.draw_circle(p + Vector2(-r * 0.3, drop_y - r * 0.3), r * 0.35, Color(1, 0.85, 0.5))
	if _boom > 0.0:
		var c := machine_centre()
		ci.draw_circle(c, size_px * (0.3 + 0.6 * (1.0 - _boom)), Color(1, 1, 0.85, 0.35 * _boom))
