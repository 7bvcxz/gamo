extends Node2D
# Snowball Relay -- drawing and input. The rules live in Sim.gd.
#
# Layout (portrait first): snow count on top, the field in the middle (never
# covered), five upgrade buttons bottom-left, a big forgiving swipe pad
# bottom-right. A swipe may start anywhere that is not a button.

const Sim := preload("res://scripts/Sim.gd")

const SKY_TOP := Color("cfe6f7")
const SKY_BOT := Color("eef6fc")
const INK := Color("33506b")
const ACCENT := Color("4aa3df")
const GOLD := Color("f2b632")

var sim: RefCounted = Sim.new(7)
var numbers_hidden: bool = false
var muted: bool = false

# gesture
var _gid: int = -99
var _g_start: Vector2 = Vector2.ZERO
var _g_last: Vector2 = Vector2.ZERO
var _g_len: float = 0.0
var _g_target: String = ""
var _g_points: Array[Vector2] = []

# view state
var _zoom: float = 44.0
var _angle: float = 0.0
var _squash: float = 0.0
var _clock: float = 0.0
var _last_input_t: float = -99.0
var _ever_pushed: bool = false
var _reset_armed_until: float = -1.0
var _buy_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _gain_shown: float = 0.0
var _particles: Array = []
var _floaters: Array = []
var _rects: Dictionary = {}
var _trail: PackedFloat32Array = PackedFloat32Array()
var _style: StyleBoxFlat = StyleBoxFlat.new()
var _font: Font = ThemeDB.fallback_font
var _sfx: Dictionary = {}
var _sfx_t: Dictionary = {}
var _bridge_t: float = 0.0
var _win: JavaScriptObject = null


func _ready() -> void:
	_build_sfx()
	if OS.has_feature("web"):
		_win = JavaScriptBridge.get_interface("window")
	_record_trail()


# ---- layout ------------------------------------------------------------------

func _view() -> Vector2:
	return get_viewport_rect().size

func _column() -> Rect2:
	var v: Vector2 = _view()
	var cw: float = minf(v.x, v.y * 0.62)
	return Rect2((v.x - cw) * 0.5, 0.0, cw, v.y)

func _layout() -> void:
	var col: Rect2 = _column()
	var v: Vector2 = _view()
	var u: float = col.size.x / 720.0
	var b: float = 94.0 * minf(u, 1.15)
	var gap: float = 10.0 * u
	var m: float = 16.0 * u
	var bottom: float = v.y - m
	_rects.clear()
	for i in 5:
		var y: float = bottom - b - float(4 - i) * (b + gap)
		_rects["up%d" % i] = Rect2(col.position.x + m, y, b, b)
	var zw: float = col.size.x * 0.52
	var zh: float = minf(v.y * 0.3, 420.0 * u)
	_rects["pad"] = Rect2(col.end.x - m - zw, bottom - zh, zw, zh)
	var ib: float = 64.0 * minf(u, 1.15)
	_rects["reset"] = Rect2(col.position.x + m, m, ib, ib)
	_rects["mute"] = Rect2(col.end.x - m - ib, m, ib, ib)
	_rects["u"] = Rect2(0, 0, u, u)


func _scale() -> float:
	return _rects["u"].size.x


# ---- input ------------------------------------------------------------------

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t: InputEventScreenTouch = e
		if t.pressed:
			_down(t.index, t.position)
		else:
			_up(t.index, t.position, t.canceled)
	elif e is InputEventScreenDrag:
		var d: InputEventScreenDrag = e
		_move(d.index, d.position)
	elif e is InputEventMouseButton:
		var mb: InputEventMouseButton = e
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_down(-1, mb.position)
			else:
				_up(-1, mb.position, false)
	elif e is InputEventMouseMotion:
		if _gid == -1:
			_move(-1, (e as InputEventMouseMotion).position)
	elif e is InputEventKey:
		var k: InputEventKey = e
		if k.pressed and not k.echo:
			match k.keycode:
				KEY_SPACE, KEY_ENTER, KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT:
					_do_push(0.7)
				KEY_M:
					_toggle_mute()
				KEY_H:
					numbers_hidden = not numbers_hidden
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
					_buy(int(k.keycode - KEY_1))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_gesture()


func _cancel_gesture() -> void:
	_gid = -99
	_g_target = ""
	_g_points.clear()


func _hit(p: Vector2) -> String:
	for k in _rects:
		if k == "u" or k == "pad":
			continue
		if (_rects[k] as Rect2).grow(4.0).has_point(p):
			return k
	return ""


func _down(id: int, p: Vector2) -> void:
	if _gid != -99:
		return   # one gesture at a time: a second finger is ignored, not doubled
	_layout()
	_gid = id
	_g_start = p
	_g_last = p
	_g_len = 0.0
	_g_target = _hit(p)
	_g_points.clear()
	_g_points.append(p)
	_last_input_t = _clock


func _move(id: int, p: Vector2) -> void:
	if id != _gid:
		return
	_g_len += p.distance_to(_g_last)
	_g_last = p
	if _g_target == "":
		_g_points.append(p)
		if _g_points.size() > 14:
			_g_points.pop_front()


func _up(id: int, p: Vector2, canceled: bool) -> void:
	if id != _gid:
		return
	var target: String = _g_target
	var len_px: float = _g_len
	_cancel_gesture()
	if canceled:
		return
	_layout()
	if target != "":
		if _hit(p) == target:
			_press_button(target)
		return
	# a field gesture: tap = small push, swipe = bigger, and it saturates
	var ref: float = minf(_view().x, _view().y) * 0.22
	var norm: float = len_px / ref
	var strength: float = 0.45 + 0.55 * (1.0 - exp(-norm * 2.2)) if len_px > 14.0 else 0.45
	_do_push(strength)


func _press_button(k: String) -> void:
	if k.begins_with("up"):
		_buy(int(k.substr(2)))
	elif k == "mute":
		_toggle_mute()
	elif k == "reset":
		if _clock < _reset_armed_until:
			_reset()
		else:
			_reset_armed_until = _clock + 2.5
			_blip("tick")


func _do_push(strength: float) -> void:
	_last_input_t = _clock
	var dv: float = sim.push(strength)
	_ever_pushed = true
	_squash = 1.0
	if dv > 0.0:
		_blip("push")


func _buy(i: int) -> void:
	if i < 0 or i > 4:
		return
	if sim.buy(i):
		_buy_flash[i] = 1.0
		_blip("buy")
	else:
		_blip("tick")


func _reset() -> void:
	sim = Sim.new(7)
	_particles.clear()
	_floaters.clear()
	_zoom = 44.0
	_angle = 0.0
	_ever_pushed = false
	_gain_shown = 0.0
	_reset_armed_until = -1.0
	_trail = PackedFloat32Array()
	_record_trail()


func _toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)


# ---- frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)   # a tab that was asleep must not fast-forward the ball
	_clock += dt
	var was_moving: bool = sim.speed > 0.0
	sim.step(dt)
	_record_trail()
	_angle += (sim.speed * dt) / maxf(sim.radius(), 0.5)
	_squash = maxf(0.0, _squash - dt * 4.0)
	for i in 5:
		_buy_flash[i] = maxf(0.0, _buy_flash[i] - dt * 2.5)
	var zt: float = 44.0 * pow(sim.radius(), -0.55)
	_zoom = lerpf(_zoom, zt, clampf(dt * 2.5, 0.0, 1.0))
	for ev in sim.drain_events():
		_on_event(ev)
	if sim.speed > 0.0:
		_snow_trail(dt)
	_tick_particles(dt)
	_gain_shown = lerpf(_gain_shown, sim.snow, clampf(dt * 12.0, 0.0, 1.0))
	_bridge_t += dt
	if _bridge_t > 0.2:
		_bridge_t = 0.0
		_publish()
	queue_redraw()


func _on_event(ev: Dictionary) -> void:
	var u: float = _scale()
	var ball: Vector2 = _ball_pos()
	match ev["t"]:
		"break":
			var z: float = _zoom
			var at: Vector2 = ball + Vector2(float(ev["off"]) * z, -0.3 * sim.radius() * z)
			var n: int = 6 + int(ev["tier"]) * 3
			for i in n:
				var a: float = randf() * TAU
				_spawn(at, Vector2(cos(a), sin(a)) * randf_range(60.0, 220.0) * u, randf_range(0.35, 0.7), randf_range(3.0, 7.0) * u, Color.WHITE if i % 2 == 0 else Color("b9d9f0"))
			_floaters.append({"p": at, "text": "+%s" % _fmt(float(ev["reward"])), "t": 0.0})
			_blip("break")
		"push":
			var dvv: float = float(ev["dv"])
			for i in 8:
				var a2: float = PI * 0.5 + randf_range(-0.9, 0.9)
				_spawn(ball + Vector2(0, sim.radius() * _zoom * 0.8), Vector2(cos(a2), sin(a2)) * randf_range(80.0, 200.0) * u * clampf(dvv / 8.0, 0.3, 1.5), randf_range(0.3, 0.6), randf_range(2.5, 5.0) * u, Color.WHITE)
		"buy":
			for i in 14:
				var a3: float = randf() * TAU
				_spawn(ball, Vector2(cos(a3), sin(a3)) * randf_range(120.0, 300.0) * u, randf_range(0.4, 0.8), randf_range(3.0, 6.0) * u, GOLD)


func _spawn(p: Vector2, v: Vector2, life: float, r: float, c: Color) -> void:
	if _particles.size() > 160:
		return
	_particles.append({"p": p, "v": v, "life": life, "max": life, "r": r, "c": c})


func _snow_trail(dt: float) -> void:
	if randf() < dt * 40.0 * clampf(sim.speed / sim.v0(), 0.2, 1.0):
		var u: float = _scale()
		var rr: float = sim.radius() * _zoom
		var bp: Vector2 = _ball_pos() + Vector2(randf_range(-rr, rr), rr * 0.85)
		_spawn(bp, Vector2(randf_range(-30.0, 30.0), randf_range(40.0, 110.0)) * u, randf_range(0.3, 0.6), randf_range(2.0, 4.5) * u, Color.WHITE)


func _tick_particles(dt: float) -> void:
	var i: int = _particles.size() - 1
	while i >= 0:
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - dt
		p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * dt
		p["v"] = (p["v"] as Vector2) * (1.0 - dt * 2.5)
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)
		i -= 1
	i = _floaters.size() - 1
	while i >= 0:
		var f: Dictionary = _floaters[i]
		f["t"] = float(f["t"]) + dt
		if float(f["t"]) > 0.9:
			_floaters.remove_at(i)
		i -= 1


func _record_trail() -> void:
	var need: int = int(sim.dist) + 2
	while _trail.size() < need:
		_trail.append(sim.radius())


func _ball_pos() -> Vector2:
	var v: Vector2 = _view()
	return Vector2(v.x * 0.5, v.y * 0.40)


# ---- drawing ----------------------------------------------------------------

func _draw() -> void:
	_layout()
	var v: Vector2 = _view()
	var u: float = _scale()
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(v.x, 0), Vector2(v.x, v.y), Vector2(0, v.y)]), PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOT, SKY_BOT]))
	_draw_ground(v)
	_draw_props(v)
	_draw_ball(u)
	for p in _particles:
		var a: float = clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		draw_circle(p["p"], float(p["r"]) * (0.4 + 0.6 * a), Color(p["c"], a))
	for f in _floaters:
		var k: float = float(f["t"]) / 0.9
		draw_string(_font, (f["p"] as Vector2) + Vector2(-24 * u, -40 * u * k - 20 * u), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * u), Color(INK, 1.0 - k))
	_draw_hud(u)
	_draw_upgrades(u)
	_draw_pad(u)


func _ground_y(d: float) -> float:
	# screen y of the world at distance d (the ball sits at dist)
	return _ball_pos().y - (d - sim.dist) * _zoom


func _draw_ground(v: Vector2) -> void:
	var z: float = _zoom
	# trail the ball has left, one slab per unit of distance
	var lo: int = maxi(0, int(sim.dist - (v.y - _ball_pos().y) / z) - 1)
	var hi: int = mini(_trail.size() - 1, int(sim.dist + _ball_pos().y / z) + 1)
	for i in range(lo, hi + 1):
		var y1: float = _ground_y(float(i) + 1.0)
		var y0: float = _ground_y(float(i))
		var w: float = _trail[i] * z * 1.5
		draw_rect(Rect2(v.x * 0.5 - w * 0.5, y1, w, y0 - y1 + 1.0), Color("cadff0"))
	# speckles that stream past so motion reads even when nothing else is near
	var spacing: float = 5.0
	var first: int = int(floor((sim.dist - (v.y - _ball_pos().y) / z) / spacing)) - 1
	var last: int = int(ceil((sim.dist + _ball_pos().y / z) / spacing)) + 1
	for k in range(first, last + 1):
		var h: int = hash(k * 7919)
		for j in 3:
			var hx: float = float((h >> (j * 5)) & 31) / 31.0
			var hy: float = float((h >> (j * 4 + 3)) & 15) / 15.0
			var wx: float = (hx - 0.5) * v.x * 1.2 / maxf(z / 44.0, 0.3)
			var p: Vector2 = Vector2(v.x * 0.5 + wx * z / 44.0 * 0.9, _ground_y((float(k) + hy) * spacing))
			draw_circle(p, 2.0 + 2.0 * hx, Color(1, 1, 1, 0.9))


func _draw_props(v: Vector2) -> void:
	var z: float = _zoom
	for p in sim.props:
		var y: float = _ground_y(float(p["d"]))
		if y < -200.0:
			break
		if y > v.y + 100.0:
			continue
		var s: float = float(p["size"]) * z
		var x: float = v.x * 0.5 + float(p["off"]) * z
		match int(p["tier"]):
			0:
				draw_circle(Vector2(x, y), s * 0.9, Color("9fb4c6"))
				draw_circle(Vector2(x - s * 0.2, y - s * 0.2), s * 0.5, Color("c3d3e0"))
			1:
				draw_circle(Vector2(x, y), s * 0.8, Color("5f9b72"))
				draw_circle(Vector2(x + s * 0.3, y - s * 0.3), s * 0.5, Color("78b88d"))
				draw_circle(Vector2(x - s * 0.1, y - s * 0.55), s * 0.45, Color("eaf4f8"))
			2:
				draw_circle(Vector2(x, y + s * 0.2), s * 0.75, Color.WHITE)
				draw_arc(Vector2(x, y + s * 0.2), s * 0.75, 0, TAU, 24, Color("aac6dc"), 2.0)
				draw_circle(Vector2(x, y - s * 0.55), s * 0.5, Color.WHITE)
				draw_arc(Vector2(x, y - s * 0.55), s * 0.5, 0, TAU, 20, Color("aac6dc"), 2.0)
				draw_circle(Vector2(x, y - s * 0.55), s * 0.08, INK)
			_:
				draw_rect(Rect2(x - s * 0.1, y - s * 0.1, s * 0.2, s * 0.5), Color("7a5b45"))
				draw_colored_polygon(PackedVector2Array([Vector2(x - s * 0.55, y), Vector2(x + s * 0.55, y), Vector2(x, y - s * 1.3)]), Color("3f7a5a"))
				draw_colored_polygon(PackedVector2Array([Vector2(x - s * 0.4, y - s * 0.5), Vector2(x + s * 0.4, y - s * 0.5), Vector2(x, y - s * 1.5)]), Color("4d9068"))
				draw_colored_polygon(PackedVector2Array([Vector2(x - s * 0.18, y - s * 1.1), Vector2(x + s * 0.18, y - s * 1.1), Vector2(x, y - s * 1.5)]), Color("eaf4f8"))


func _draw_ball(u: float) -> void:
	var c: Vector2 = _ball_pos()
	var r: float = sim.radius() * _zoom
	var sq: float = 1.0 + 0.12 * sin(_squash * PI)
	# collection radius ring: faint, so "attraction" is something you can see
	var cr: float = sim.collect_radius() * _zoom
	draw_arc(c, cr, 0, TAU, 48, Color(ACCENT, 0.28), 2.0 * u)
	draw_circle(c + Vector2(0, r * 0.18), r * 1.02, Color(INK, 0.12))
	draw_set_transform(c, _angle, Vector2(1.0 / sq, sq))
	draw_circle(Vector2.ZERO, r, Color.WHITE)
	draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color("9fc3dd"), maxf(2.0, r * 0.06))
	for i in 7:
		var a: float = float(i) * 0.9 + 0.4
		var rr: float = r * (0.25 + 0.55 * float((i * 37) % 10) / 10.0)
		draw_circle(Vector2(cos(a), sin(a)) * rr, r * (0.07 + 0.05 * float(i % 3)), Color("dcebf7"))
	draw_arc(Vector2.ZERO, r * 0.55, 0.3, 2.0, 16, Color("b9d6ea"), maxf(2.0, r * 0.05))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.18, Color(1, 1, 1, 0.9))


func _fmt(n: float) -> String:
	if n >= 1000000.0:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000.0:
		return "%.0fK" % (n / 1000.0)
	if n >= 1000.0:
		return "%.1fK" % (n / 1000.0)
	return str(int(n))


func _draw_flake(c: Vector2, r: float, col: Color) -> void:
	for i in 3:
		var a: float = float(i) * PI / 3.0
		var d: Vector2 = Vector2(cos(a), sin(a)) * r
		draw_line(c - d, c + d, col, maxf(2.0, r * 0.22))
	draw_circle(c, r * 0.25, col)


func _draw_hud(u: float) -> void:
	var col: Rect2 = _column()
	var cx: float = col.position.x + col.size.x * 0.5
	var y: float = 52.0 * u
	_draw_flake(Vector2(cx - 92.0 * u, y + 6.0 * u), 24.0 * u, ACCENT)
	if numbers_hidden:
		# no digits: a bar that fills toward the cheapest thing you could buy
		var best: float = 1e30
		for i in 5:
			if not sim.maxed(i):
				best = minf(best, sim.cost(i))
		var f: float = clampf(sim.snow / best, 0.0, 1.0) if best < 1e29 else 1.0
		draw_rect(Rect2(cx - 50.0 * u, y - 4.0 * u, 160.0 * u, 20.0 * u), Color(INK, 0.15))
		draw_rect(Rect2(cx - 50.0 * u, y - 4.0 * u, 160.0 * u * f, 20.0 * u), ACCENT)
	else:
		draw_string(_font, Vector2(cx - 56.0 * u, y + 26.0 * u), _fmt(_gain_shown), HORIZONTAL_ALIGNMENT_LEFT, -1, int(64.0 * u), INK)
	# small icon buttons
	_icon_button(_rects["reset"], "reset", _clock < _reset_armed_until)
	_icon_button(_rects["mute"], "mute", muted)


func _icon_button(r: Rect2, kind: String, on: bool) -> void:
	var c: Vector2 = r.get_center()
	var rad: float = r.size.x * 0.5
	var pressed: bool = _g_target == kind
	draw_circle(c, rad, Color(0.8, 0.3, 0.3, 0.9) if (on and kind == "reset") else Color(1, 1, 1, 0.75 if not pressed else 1.0))
	draw_arc(c, rad, 0, TAU, 32, Color(INK, 0.35), 2.0)
	var ink: Color = Color.WHITE if (on and kind == "reset") else INK
	if kind == "reset":
		draw_arc(c, rad * 0.45, 0.6, TAU - 0.2, 20, ink, 4.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(rad * 0.55, -rad * 0.55), c + Vector2(rad * 0.1, -rad * 0.5), c + Vector2(rad * 0.55, -rad * 0.05)]), ink)
	else:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-rad * 0.45, -rad * 0.2), c + Vector2(-rad * 0.15, -rad * 0.2), c + Vector2(rad * 0.15, -rad * 0.5), c + Vector2(rad * 0.15, rad * 0.5), c + Vector2(-rad * 0.15, rad * 0.2), c + Vector2(-rad * 0.45, rad * 0.2)]), ink)
		if on:
			draw_line(c + Vector2(rad * 0.3, -rad * 0.45), c + Vector2(rad * 0.7, rad * 0.45), Color("d04a4a"), 4.0)
		else:
			draw_arc(c + Vector2(rad * 0.1, 0), rad * 0.4, -0.8, 0.8, 8, ink, 3.0)


func _draw_upgrades(u: float) -> void:
	for i in 5:
		var r: Rect2 = _rects["up%d" % i]
		var afford: bool = sim.can_buy(i)
		var maxed: bool = sim.maxed(i)
		var pressed: bool = _g_target == "up%d" % i
		var pulse: float = 0.5 + 0.5 * sin(_clock * 6.0)
		var fill: float = 1.0 if maxed else clampf(sim.snow / sim.cost(i), 0.0, 1.0)
		_style.set_corner_radius_all(int(18 * u))
		_style.bg_color = Color(1, 1, 1, 0.92 if afford or pressed else 0.72)
		_style.border_color = Color(GOLD, 0.6 + 0.4 * pulse) if afford else Color(INK, 0.25)
		_style.set_border_width_all(int((5 if afford else 2) * u))
		var rr: Rect2 = r.grow(-3.0 * u) if pressed else r
		draw_style_box(_style, rr)
		# affordability fill rises from the bottom edge
		var fh: float = (rr.size.y - 12.0 * u) * fill
		draw_rect(Rect2(rr.position.x + 6.0 * u, rr.end.y - 6.0 * u - fh, 7.0 * u, fh), Color(ACCENT, 0.9) if not afford else Color(GOLD, 0.95))
		_icon(i, rr.get_center() + Vector2(3.0 * u, -4.0 * u), rr.size.x * 0.27, Color(INK, 1.0) if not maxed else Color("5f9b72"))
		# level pips
		for k in Sim.MAX_LEVEL:
			var px: float = rr.position.x + rr.size.x * 0.5 - 4.5 * 6.4 * u + float(k) * 6.4 * u + 3.0 * u
			draw_circle(Vector2(px, rr.end.y - 9.0 * u), 2.3 * u, ACCENT if k < sim.lv[i] else Color(INK, 0.18))
		if _buy_flash[i] > 0.0:
			draw_arc(rr.get_center(), rr.size.x * (0.5 + 0.5 * (1.0 - _buy_flash[i])), 0, TAU, 28, Color(GOLD, _buy_flash[i]), 5.0 * u)
		if not numbers_hidden and not maxed:
			draw_string(_font, Vector2(rr.position.x + 8.0 * u, rr.position.y + 19.0 * u), _fmt(sim.cost(i)), HORIZONTAL_ALIGNMENT_RIGHT, rr.size.x - 16.0 * u, int(18.0 * u), Color(INK, 0.85))


func _icon(i: int, c: Vector2, s: float, col: Color) -> void:
	match i:
		0: # mass: a small ball inside a bigger one
			draw_arc(c, s, 0, TAU, 24, col, s * 0.16)
			draw_circle(c + Vector2(-s * 0.2, s * 0.2), s * 0.38, col)
		1: # power: a bolt
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.2, -s), c + Vector2(-s * 0.55, s * 0.15), c + Vector2(-s * 0.05, s * 0.15), c + Vector2(-s * 0.25, s), c + Vector2(s * 0.6, -s * 0.2), c + Vector2(s * 0.05, -s * 0.2)]), col)
		2: # momentum: speed lines behind a dot
			draw_circle(c + Vector2(s * 0.45, 0), s * 0.38, col)
			for k in 3:
				var y: float = (float(k) - 1.0) * s * 0.55
				draw_line(c + Vector2(-s, y), c + Vector2(s * 0.05, y), col, s * 0.16)
		3: # attraction: arrows pulling into a dot
			draw_circle(c, s * 0.28, col)
			for k in 4:
				var a: float = float(k) * PI * 0.5 + PI * 0.25
				var d: Vector2 = Vector2(cos(a), sin(a))
				draw_line(c + d * s, c + d * s * 0.55, col, s * 0.16)
				draw_line(c + d * s * 0.55, c + d * s * 0.55 + d.rotated(2.5) * s * 0.3, col, s * 0.16)
				draw_line(c + d * s * 0.55, c + d * s * 0.55 + d.rotated(-2.5) * s * 0.3, col, s * 0.16)
		_: # impact: a burst
			for k in 8:
				var a2: float = float(k) * PI * 0.25
				var d2: Vector2 = Vector2(cos(a2), sin(a2))
				draw_line(c + d2 * s * 0.35, c + d2 * s * (1.0 if k % 2 == 0 else 0.7), col, s * 0.17)
			draw_circle(c, s * 0.25, col)


func _draw_pad(u: float) -> void:
	var r: Rect2 = _rects["pad"]
	var idle: float = _clock - _last_input_t
	var calm: bool = sim.speed <= 0.0
	var invite: float = 0.0
	if not _ever_pushed:
		invite = 1.0
	elif calm and idle > 4.0:
		invite = clampf((idle - 4.0) / 2.0, 0.0, 1.0)
	var down: bool = _gid != -99 and _g_target == ""
	_style.set_corner_radius_all(int(34 * u))
	_style.bg_color = Color(ACCENT, 0.16 + 0.1 * invite + (0.12 if down else 0.0))
	_style.border_color = Color(ACCENT, 0.55 + 0.25 * invite)
	_style.set_border_width_all(int(4 * u))
	draw_style_box(_style, r)
	# chevrons that run "forward", always there; a ghost finger when you have not played yet
	var c: Vector2 = r.get_center()
	var ph: float = fmod(_clock * 0.9, 1.0)
	for k in 3:
		var t: float = fmod(ph + float(k) / 3.0, 1.0)
		var y: float = c.y + r.size.y * 0.28 - t * r.size.y * 0.56
		var a: float = sin(t * PI) * (0.35 + 0.4 * invite)
		var w: float = 46.0 * u
		draw_polyline(PackedVector2Array([Vector2(c.x - w, y + 16.0 * u), Vector2(c.x, y - 8.0 * u), Vector2(c.x + w, y + 16.0 * u)]), Color(ACCENT, a), 8.0 * u)
	if invite > 0.0:
		var t2: float = fmod(_clock * 0.8, 1.2) / 1.2
		var fp: Vector2 = Vector2(c.x + 20.0 * u, c.y + r.size.y * 0.3 - t2 * r.size.y * 0.55)
		draw_circle(fp, 24.0 * u, Color(INK, 0.5 * invite * (1.0 - t2 * 0.5)))
		draw_circle(fp, 14.0 * u, Color(1, 1, 1, 0.8 * invite))
	# the live finger trail
	if _g_points.size() > 1:
		for k in range(1, _g_points.size()):
			draw_line(_g_points[k - 1], _g_points[k], Color(ACCENT, 0.15 + 0.8 * float(k) / float(_g_points.size())), 10.0 * u)
	# a short breath meter: how much more push the ball would take right now
	var room: float = clampf(1.0 - sim.speed / sim.vcap(), 0.0, 1.0)
	draw_rect(Rect2(r.position.x + 24.0 * u, r.end.y - 22.0 * u, (r.size.x - 48.0 * u) * room, 7.0 * u), Color(ACCENT, 0.5))


# ---- sound ------------------------------------------------------------------

func _build_sfx() -> void:
	var defs: Dictionary = {
		"push": [260.0, 120.0, 0.22, 0.30, 0.55],
		"break": [720.0, 260.0, 0.12, 0.35, 0.1],
		"buy": [660.0, 990.0, 0.2, 0.3, 0.0],
		"tick": [420.0, 380.0, 0.05, 0.2, 0.0],
	}
	for k in defs:
		var d: Array = defs[k]
		var pl: AudioStreamPlayer = AudioStreamPlayer.new()
		pl.stream = _tone(float(d[0]), float(d[1]), float(d[2]), float(d[3]), float(d[4]))
		pl.volume_db = -6.0
		add_child(pl)
		_sfx[k] = pl
		_sfx_t[k] = -9.0


func _tone(f0: float, f1: float, dur: float, vol: float, noise: float) -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(float(rate) * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var ph: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for i in n:
		var t: float = float(i) / float(n)
		ph += TAU * lerpf(f0, f1, t) / float(rate)
		var env: float = pow(1.0 - t, 2.0) * minf(1.0, t * 40.0)
		var s: float = (sin(ph) * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise) * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func _blip(name: String) -> void:
	if muted or not _sfx.has(name):
		return
	if _clock - float(_sfx_t[name]) < 0.05:
		return
	_sfx_t[name] = _clock
	(_sfx[name] as AudioStreamPlayer).play()


# ---- browser bridge (read-only state for the e2e script) --------------------

func _publish() -> void:
	if _win == null:
		return
	var v: Vector2 = _view()
	var rects: Dictionary = {}
	for k in _rects:
		if k == "u":
			continue
		var r: Rect2 = _rects[k]
		rects[k] = [r.position.x / v.x, r.position.y / v.y, r.size.x / v.x, r.size.y / v.y]
	var st: Dictionary = {
		"t": snappedf(sim.time, 0.01),
		"snow": snappedf(sim.snow, 0.1),
		"earned": snappedf(sim.earned, 0.1),
		"mass": snappedf(sim.mass, 0.01),
		"radius": snappedf(sim.radius(), 0.001),
		"dist": snappedf(sim.dist, 0.01),
		"speed": snappedf(sim.speed, 0.001),
		"lv": sim.lv,
		"pushes": sim.pushes,
		"breaks": sim.breaks,
		"rollT": sim.roll_time(),
		"lastRoll": snappedf(sim.last_roll_len, 0.01),
		"muted": muted,
		"hidden": numbers_hidden,
		"view": [v.x, v.y],
		"rects": rects,
	}
	_win.set("__snow", JSON.stringify(st))
