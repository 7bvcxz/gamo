extends PopPlayView

## B Perfect Pop's picture. Pressing lights a flame and fills a ring round the
## machine, clockwise from the top: cool blue, then the GOLD arc (the target,
## always drawn so it is seen before the first press), then red. The kernels in
## the glass swell with the heat and sparkle inside the gold. Letting go pops:
##   perfect -> a gold burst and a flash ring;  early -> a few pops and
##   unpopped kernels tumbling out;  late -> brown popcorn;  burnt -> smoke.

var _flash := 0.0
var _flash_col := PopPalette.GOLD
var _last_outcome := ""


func _release() -> void:
	command.emit("release", {"type": "release"})


func _r() -> Dictionary:
	return rules.state()


func ring_radius() -> float:
	return machine_size() * 0.5


func on_events(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		var d: Dictionary = e["data"]
		match String(e["type"]):
			"outcome":
				_last_outcome = String(d["kind"])
			"pop":
				_squash = 1.0
				var n := int(d.get("count", 1))
				var s := machine_size() / 900.0
				var shown := mini(n, 18) if not reduced_motion else 1
				match String(d.get("outcome", "")):
					"perfect":
						fx.burst(machine_top(), shown + 6, s, rng, PopPalette.GOLD, 1.0, 1.25)
						_flash = 1.0
						_flash_col = PopPalette.GOLD
					"early":
						fx.burst(machine_top(), maxi(1, shown / 2), s, rng, PopPalette.CREAM, 0.6, 0.7)
						fx.kernels(machine_top(), 10, s, rng)
					"late":
						fx.burst(machine_top(), shown, s, rng, Color(0.85, 0.62, 0.36), 0.8, 0.9)
					"burnt":
						fx.burst(machine_top(), maxi(1, shown / 3), s, rng, Color(0.35, 0.27, 0.22), 0.5, 0.6)
						fx.smoke(machine_top(), 10, s, rng)
						_flash = 0.6
						_flash_col = Color(0.3, 0.3, 0.3)
			"earn":
				fx.coin(machine_top(), machine_size() / 900.0)
				_gain(int(d.get("amount", 0)))
			"upgrade":
				_squash = 1.0
				fx.burst(machine_top(), 18 if not reduced_motion else 2, machine_size() / 900.0, rng, PopPalette.GOLD)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.5)
	super(delta)


func _shake() -> Vector2:
	if rules == null or not bool(_r()["heating"]):
		return Vector2.ZERO
	var st := _r()
	var w: Array = st["window"]
	var heat := float(st["heat_ms"])
	if heat < float(w[1]) or reduced_motion:
		return Vector2.ZERO
	# Past the gold the machine rattles: it is about to burn.
	var k := (heat - float(w[1])) / maxf(1.0, float(w[2]) - float(w[1]))
	return Vector2(sin(_t * 70.0), cos(_t * 53.0)) * 6.0 * k


## Behind the machine: the flame while heating.
func _draw_under(ci: CanvasItem, base: Vector2, size_px: float) -> void:
	if not bool(_r()["heating"]):
		return
	# The flame under the machine.
	for i in 5:
		var fx_x := base.x + (float(i) - 2.0) * size_px * 0.07
		var hgt := size_px * (0.06 + 0.03 * sin(_t * 18.0 + i))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(fx_x - size_px * 0.03, base.y + 4), Vector2(fx_x + size_px * 0.03, base.y + 4),
			Vector2(fx_x, base.y + 4 - hgt)]), Color(1.0, 0.55 + 0.1 * float(i % 2), 0.15, 0.9))


## The gauge, in front of the machine: a wide machine at a high level must
## never hide the gold (it did when this was drawn behind it).
func _draw_ring(ci: CanvasItem, _base: Vector2, size_px: float) -> void:
	var st := _r()
	var w: Array = st["window"]
	var heating := bool(st["heating"])
	var heat := float(st["heat_ms"])
	var burn := float(w[2])
	var c := machine_centre()
	var r := ring_radius()
	var top := -PI / 2
	var to_angle := func(ms: float) -> float: return top + TAU * clampf(ms / burn, 0.0, 1.0)
	var width := size_px * 0.045
	# The track: blue, GOLD, red -- always visible.
	ci.draw_arc(c, r, top, to_angle.call(float(w[0])), 48, Color(0.45, 0.65, 0.95, 0.35), width)
	ci.draw_arc(c, r, to_angle.call(float(w[0])), to_angle.call(float(w[1])), 24, Color(PopPalette.GOLD, 0.95), width * 1.6)
	ci.draw_arc(c, r, to_angle.call(float(w[1])), top + TAU, 32, Color(0.9, 0.25, 0.2, 0.35), width)
	if heating:
		# The heat so far, each part in its zone's colour, and a bright head.
		var a: float = to_angle.call(heat)
		var blue := Color(0.3, 0.55, 0.95)
		var red := Color(0.9, 0.25, 0.2)
		ci.draw_arc(c, r, top, to_angle.call(minf(heat, float(w[0]))), 48, blue, width * 0.8)
		if heat > float(w[0]):
			ci.draw_arc(c, r, to_angle.call(float(w[0])), to_angle.call(minf(heat, float(w[1]))), 24, PopPalette.GOLD.darkened(0.15), width * 1.2)
		if heat > float(w[1]):
			ci.draw_arc(c, r, to_angle.call(float(w[1])), a, 32, red, width * 0.8)
		var col := blue
		if heat >= float(w[0]):
			col = PopPalette.GOLD if heat <= float(w[1]) else red
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * r, width * 1.3, Color.WHITE)
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * r, width * 0.9, col)
	if _flash > 0.0:
		ci.draw_arc(c, r * (1.0 + 0.4 * (1.0 - _flash)), 0, TAU, 64, Color(_flash_col, _flash), width * 2.0)


func _draw_over(ci: CanvasItem, base: Vector2, size_px: float) -> void:
	_draw_ring(ci, base, size_px)
	# Kernels in the glass: they swell with heat and sparkle inside the gold.
	var st := _r()
	var w: Array = st["window"]
	var heat := float(st["heat_ms"]) if bool(st["heating"]) else 0.0
	var swell := clampf(heat / float(w[0]), 0.0, 1.0)
	var gold := bool(st["heating"]) and heat >= float(w[0]) and heat <= float(w[1])
	var h := PopMachineArt.height_at(rules.level, size_px)
	var y := base.y - h * 0.47
	for i in 7:
		var x := base.x + (float(i) - 3.0) * h * 0.075
		var rr := h * (0.018 + 0.016 * swell) * (1.0 + 0.15 * sin(_t * 20.0 + i) * swell)
		var col := Color(0.85, 0.6, 0.25).lerp(PopPalette.CREAM, swell)
		if gold and int(_t * 12.0 + i) % 2 == 0:
			col = PopPalette.GOLD.lightened(0.3)
		ci.draw_circle(Vector2(x, y), rr, col)
