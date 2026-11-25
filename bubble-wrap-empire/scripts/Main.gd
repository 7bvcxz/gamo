extends Node2D
# Bubble Wrap Empire -- drawing and input. The rules live in Sim.gd.
#
# Layout (portrait first): POP count on top, the bubble sheet in the middle
# (never covered), five upgrade buttons bottom-left, a big thumb pad
# bottom-right that is a small map of the sheet: where your thumb rests on the
# pad is where the pop will start on the sheet (a ring shows it). The pop
# happens when you let go; one touch is one trigger, however long or short.

const Sim := preload("res://scripts/Sim.gd")
const Metrics := preload("res://scripts/Metrics.gd")

const BG_TOP := Color("e9defa")
const BG_BOT := Color("f8f1fd")
const INK := Color("4a3d6b")
const ACCENT := Color("8a6ad6")
const PINK := Color("ef7fb0")
const GOLD := Color("f2b632")

var sim: RefCounted = Sim.new(5)
var metrics: RefCounted = Metrics.new()
var panel_open: bool = false
var _session_t0: float = 0.0
var _g_t0: float = 0.0
var _copied_until: float = -1.0
var numbers_hidden: bool = false
var muted: bool = false

var _gid: int = -99
var _g_target: String = ""
var _g_pad: bool = false
var _g_pos: Vector2 = Vector2.ZERO
var _g_len: float = 0.0
var _g_last: Vector2 = Vector2.ZERO

var _clock: float = 0.0
var _last_input_t: float = -99.0
var _ever_popped: bool = false
var _reset_armed_until: float = -1.0
var _buy_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _shown: float = 0.0
var _rings: Array = []
var _particles: Array = []
var _floaters: Array = []
var _rects: Dictionary = {}
var _style: StyleBoxFlat = StyleBoxFlat.new()
var _font: Font = ThemeDB.fallback_font
var _players: Array[AudioStreamPlayer] = []
var _pop_streams: Array[AudioStreamWAV] = []
var _sfx: Dictionary = {}
var _sfx_t: Dictionary = {}
var _pool_i: int = 0
var _pop_snd_t: float = -9.0
var _bridge_t: float = 0.0
var _win: JavaScriptObject = null
var _sheet: Rect2 = Rect2()
var _cell: float = 60.0


func _ready() -> void:
	_build_sfx()
	if OS.has_feature("web"):
		_win = JavaScriptBridge.get_interface("window")
		var d: Variant = JavaScriptBridge.eval("window.devicePixelRatio")
		if d != null:
			metrics.dpr = float(d)


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
	var col_top: float = bottom - 5.0 * b - 4.0 * gap
	var zw: float = col.size.x * 0.52
	var zh: float = minf(v.y * 0.3, 420.0 * u)
	_rects["pad"] = Rect2(col.end.x - m - zw, bottom - zh, zw, zh)
	var ib: float = 64.0 * minf(u, 1.15)
	_rects["reset"] = Rect2(col.position.x + m, m, ib, ib)
	_rects["mute"] = Rect2(col.end.x - m - ib, m, ib, ib)
	_rects["info"] = Rect2(col.position.x + m + ib + 10.0 * u, m, ib, ib)
	if panel_open:
		var pw: float = col.size.x - 2.0 * m
		_rects["panel"] = Rect2(col.position.x + m, 120.0 * u, pw, 400.0 * u)
		_rects["copy"] = Rect2(col.position.x + m + 16.0 * u, 120.0 * u + 330.0 * u, 150.0 * u, 56.0 * u)
		_rects["num"] = Rect2(col.position.x + m + 182.0 * u, 120.0 * u + 330.0 * u, 150.0 * u, 56.0 * u)
	_rects["u"] = Rect2(0, 0, u, u)
	# the sheet: as large as fits between the top bar and the upgrade column
	var y0: float = 120.0 * u
	var y1: float = minf(col_top - 14.0 * u, v.y * 0.62)
	_cell = minf(col.size.x * 0.95 / (float(Sim.COLS) + 0.5), (y1 - y0) / (float(Sim.ROWS - 1) * 0.866 + 1.0))
	var sw: float = (float(Sim.COLS) - 0.5) * _cell
	var sh: float = float(Sim.ROWS - 1) * 0.866 * _cell
	_sheet = Rect2(col.position.x + (col.size.x - sw) * 0.5, y0 + _cell * 0.5, sw, sh)

func _scale() -> float:
	return _rects["u"].size.x

func _bp(i: int) -> Vector2:
	var p: Vector2 = sim.pos[i]
	return Vector2(_sheet.position.x + p.x * _cell, _sheet.position.y + p.y * _cell)

func _to_cell(p: Vector2) -> Vector2:
	return Vector2((p.x - _sheet.position.x) / _cell, (p.y - _sheet.position.y) / _cell)

# Where a touch at `p` means to pop. Inside the pad the pad is a map of the sheet;
# anywhere else it is simply that spot on the sheet.
func _aim(p: Vector2, in_pad: bool) -> Vector2:
	var pad: Rect2 = _rects["pad"]
	if in_pad:
		var u: float = clampf((p.x - pad.position.x) / pad.size.x, 0.0, 1.0)
		var w: float = clampf((p.y - pad.position.y) / pad.size.y, 0.0, 1.0)
		return _to_cell(_sheet.position + Vector2(u * _sheet.size.x, w * _sheet.size.y))
	return _to_cell(Vector2(clampf(p.x, _sheet.position.x, _sheet.end.x), clampf(p.y, _sheet.position.y, _sheet.end.y)))


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
				KEY_SPACE, KEY_ENTER:
					metrics.press(_t(), sim.earned, "field", 0.0, 0.0, 0.0, false, _trigger(_aim(_sheet.get_center(), false)))
				KEY_M:
					_toggle_mute()
				KEY_H:
					numbers_hidden = not numbers_hidden
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
					metrics.press(_t(), sim.earned, "upgrade", 0.0, 0.0, 0.0, false, _buy(int(k.keycode - KEY_1)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _gid != -99:
			metrics.press(_t(), sim.earned, "field" if _g_target == "" else "button", _clock - _g_t0, _g_len, _g_len / _short_side(), true, false)
		_cancel_gesture()


func _cancel_gesture() -> void:
	_gid = -99
	_g_target = ""
	_g_pad = false


func _hit(p: Vector2) -> String:
	for k in _rects:
		if k == "u" or k == "pad" or k == "panel" or k == "sheet":
			continue
		if (_rects[k] as Rect2).grow(4.0).has_point(p):
			return k
	return ""


func _down(id: int, p: Vector2) -> void:
	if _gid != -99:
		return   # one touch at a time: a second finger is ignored, never doubled
	_layout()
	_gid = id
	_g_pos = p
	_g_last = p
	_g_len = 0.0
	_g_target = _hit(p)
	_g_pad = (_rects["pad"] as Rect2).has_point(p)
	_g_t0 = _clock
	metrics.view = _view()
	_last_input_t = _clock


func _move(id: int, p: Vector2) -> void:
	if id != _gid:
		return
	_g_len += p.distance_to(_g_last)
	_g_last = p
	_g_pos = p


func _up(id: int, p: Vector2, canceled: bool) -> void:
	if id != _gid:
		return
	var target: String = _g_target
	var in_pad: bool = _g_pad
	var len_px: float = _g_len
	var down_s: float = _clock - _g_t0
	_cancel_gesture()
	var kind: String = "field" if target == "" else ("upgrade" if target.begins_with("up") else "button")
	if canceled:
		metrics.press(_t(), sim.earned, kind, down_s, len_px, len_px / _short_side(), true, false)
		return
	_layout()
	if target != "":
		var took_b: bool = false
		if _hit(p) == target:
			took_b = _press_button(target)
		metrics.press(_t(), sim.earned, kind, down_s, len_px, len_px / _short_side(), false, took_b)
		return
	var took: bool = _trigger(_aim(p, in_pad))
	metrics.press(_t(), sim.earned, "field", down_s, len_px, len_px / _short_side(), false, took)


func _press_button(k: String) -> bool:
	if k.begins_with("up"):
		return _buy(int(k.substr(2)))
	elif k == "mute":
		_toggle_mute()
	elif k == "info":
		panel_open = not panel_open
	elif k == "copy":
		DisplayServer.clipboard_set(_summary())
		_copied_until = _clock + 1.5
	elif k == "num":
		numbers_hidden = not numbers_hidden
	elif k == "reset":
		if _clock < _reset_armed_until:
			_reset()
		else:
			_reset_armed_until = _clock + 2.5
			_blip("tick")
	return false


func _trigger(at: Vector2) -> bool:
	_last_input_t = _clock
	var seed_i: int = sim.trigger(at)
	if seed_i >= 0:
		_ever_popped = true
		return true
	_blip("tick")
	return false


func _buy(i: int) -> bool:
	if i < 0 or i > 4:
		return false
	if sim.buy(i):
		_buy_flash[i] = 1.0
		_blip("buy")
		return true
	_blip("tick")
	return false


func _reset() -> void:
	sim = Sim.new(5)
	_rings.clear()
	_particles.clear()
	_floaters.clear()
	_ever_popped = false
	_shown = 0.0
	_reset_armed_until = -1.0
	metrics.reset()
	_session_t0 = _clock


func _toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)


func _t() -> float:
	return _clock - _session_t0


func _short_side() -> float:
	var v: Vector2 = _view()
	return maxf(minf(v.x, v.y), 1.0)


func _live_down() -> float:
	return (_clock - _g_t0) if _gid != -99 else 0.0


func _costs() -> Array:
	var out: Array = []
	for i in 5:
		out.append(-1.0 if sim.maxed(i) else sim.cost(i))
	return out


func _summary() -> String:
	var game: Dictionary = {
		"triggers_accepted": sim.triggers, "bubbles_popped": sim.pops, "waves_finished": sim.wave_total,
		"avg_wave_pops": snappedf((float(sim.wave_pops_sum) / float(sim.wave_total)) if sim.wave_total > 0 else 0.0, 0.01),
		"max_wave_pops": sim.wave_max, "last_wave_pops": sim.last_wave_count,
		"avg_wave_s": snappedf((sim.wave_secs_sum / float(sim.wave_total)) if sim.wave_total > 0 else 0.0, 0.01),
		"sheet_full": "%d/%d" % [sim.full_count(), sim.pos.size()], "refill_s": snappedf(sim.refill_time(), 0.01),
		"upgrade_levels": str(sim.lv),
	}
	return metrics.summary(_t(), _live_down(), sim.earned, game)


# ---- frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)   # a tab that was asleep must not fast-forward the sheet
	_clock += dt
	_layout()
	sim.step(dt)
	for i in 5:
		_buy_flash[i] = maxf(0.0, _buy_flash[i] - dt * 2.5)
	for ev in sim.drain_events():
		_on_event(ev)
	_tick_fx(dt)
	_shown = lerpf(_shown, sim.pop, clampf(dt * 12.0, 0.0, 1.0))
	_bridge_t += dt
	if _bridge_t > 0.2:
		_bridge_t = 0.0
		_publish()
	queue_redraw()


func _on_event(ev: Dictionary) -> void:
	var u: float = _scale()
	match ev["t"]:
		"pop":
			var i: int = int(ev["i"])
			var c: Vector2 = _bp(i)
			var d: int = int(ev["depth"])
			var col: Color = Color("ffffff").lerp(PINK, clampf(float(d) / 6.0, 0.0, 1.0))
			if bool(ev["mega"]):
				col = GOLD
			if _rings.size() < 90:
				_rings.append({"p": c, "t": 0.0, "col": col})
			for k in 4:
				var a: float = randf() * TAU
				_spawn(c, Vector2(cos(a), sin(a)) * randf_range(70.0, 190.0) * u, randf_range(0.25, 0.5), randf_range(2.5, 5.0) * u, col)
			if _clock - _pop_snd_t > 0.03:
				_pop_snd_t = _clock
				_pop_sound(d, bool(ev["mega"]))
		"wave":
			if int(ev["count"]) > 1 or bool(ev["mega"]):
				var sp: Vector2 = _bp(int(ev["seed"]))
				_floaters.append({"p": sp, "text": "+%s" % _fmt(float(ev["total"])), "t": 0.0, "big": bool(ev["mega"])})
		"buy":
			for k in 14:
				var a2: float = randf() * TAU
				_spawn(_sheet.get_center(), Vector2(cos(a2), sin(a2)) * randf_range(150.0, 380.0) * u, randf_range(0.4, 0.8), randf_range(3.0, 6.0) * u, GOLD)


func _spawn(p: Vector2, v: Vector2, life: float, r: float, c: Color) -> void:
	if _particles.size() > 220:
		return
	_particles.append({"p": p, "v": v, "life": life, "max": life, "r": r, "c": c})


func _tick_fx(dt: float) -> void:
	var i: int = _particles.size() - 1
	while i >= 0:
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - dt
		p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * dt
		p["v"] = (p["v"] as Vector2) * (1.0 - dt * 3.0)
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)
		i -= 1
	i = _rings.size() - 1
	while i >= 0:
		var r: Dictionary = _rings[i]
		r["t"] = float(r["t"]) + dt
		if float(r["t"]) > 0.28:
			_rings.remove_at(i)
		i -= 1
	i = _floaters.size() - 1
	while i >= 0:
		var f: Dictionary = _floaters[i]
		f["t"] = float(f["t"]) + dt
		if float(f["t"]) > 1.0:
			_floaters.remove_at(i)
		i -= 1


# ---- drawing ----------------------------------------------------------------

func _draw() -> void:
	_layout()
	var v: Vector2 = _view()
	var u: float = _scale()
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(v.x, 0), Vector2(v.x, v.y), Vector2(0, v.y)]), PackedColorArray([BG_TOP, BG_TOP, BG_BOT, BG_BOT]))
	_draw_sheet(u)
	for r in _rings:
		var k: float = float(r["t"]) / 0.28
		draw_arc(r["p"], _cell * (0.3 + 0.75 * k), 0, TAU, 20, Color(r["col"], 1.0 - k), maxf(2.0, _cell * 0.07 * (1.0 - k)))
	for p in _particles:
		var a: float = clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		draw_circle(p["p"], float(p["r"]) * (0.4 + 0.6 * a), Color(p["c"], a))
	for f in _floaters:
		var k2: float = float(f["t"])
		var fs: int = int((44 if f["big"] else 30) * u)
		draw_string(_font, (f["p"] as Vector2) + Vector2(-30.0 * u, -_cell * 0.5 - 70.0 * u * k2), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(GOLD if f["big"] else INK, 1.0 - k2))
	_draw_hud(u)
	_draw_upgrades(u)
	_draw_pad(u)
	_draw_aim(u)


func _draw_sheet(u: float) -> void:
	var pad_r: Rect2 = _sheet.grow(_cell * 0.62)
	_style.set_corner_radius_all(int(30 * u))
	_style.bg_color = Color(1, 1, 1, 0.45)
	_style.border_color = Color(ACCENT, 0.35)
	_style.set_border_width_all(int(3 * u))
	draw_style_box(_style, pad_r)
	var r0: float = _cell * 0.46
	for i in sim.pos.size():
		var c: Vector2 = _bp(i)
		var f: float = sim.fill[i]
		var sched: bool = sim.pop_at[i] >= 0.0
		if f >= 0.999:
			var swell: float = 1.0
			var tint: Color = Color(0.74, 0.8, 1.0, 0.45)
			if sched:
				var left: float = clampf((sim.pop_at[i] - sim.time) / 0.12, 0.0, 1.0)
				swell = 1.0 + 0.12 * (1.0 - left)
				tint = Color(1.0, 0.8, 0.9, 0.6)
			var r: float = r0 * swell
			draw_circle(c, r, tint)
			draw_arc(c, r, 0, TAU, 28, Color(ACCENT, 0.55), maxf(1.5, _cell * 0.035))
			draw_arc(c, r * 0.68, 3.5, 4.8, 8, Color(1, 1, 1, 0.9), maxf(2.0, _cell * 0.05))
			draw_circle(c + Vector2(-r * 0.38, -r * 0.4), r * 0.1, Color(1, 1, 1, 0.95))
		elif f > 0.0:
			var e: float = 1.0 - pow(1.0 - f, 2.0)
			draw_circle(c, r0 * e, Color(0.78, 0.84, 1.0, 0.3 * e))
			draw_arc(c, r0 * e, 0, TAU, 20, Color(ACCENT, 0.4 * e), maxf(1.5, _cell * 0.03))
		else:
			# a popped bubble: a small flat wrinkle, so you can see what is empty
			draw_arc(c, r0 * 0.38, 0.4, 5.2, 10, Color(ACCENT, 0.3), maxf(1.5, _cell * 0.03))


func _fmt(n: float) -> String:
	if n >= 1000000.0:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000.0:
		return "%.0fK" % (n / 1000.0)
	if n >= 1000.0:
		return "%.1fK" % (n / 1000.0)
	return str(int(n))


func _draw_hud(u: float) -> void:
	var col: Rect2 = _column()
	var cx: float = col.position.x + col.size.x * 0.5
	var y: float = 52.0 * u
	var ic: Vector2 = Vector2(cx - 92.0 * u, y + 6.0 * u)
	draw_circle(ic, 24.0 * u, Color(0.74, 0.8, 1.0, 0.6))
	draw_arc(ic, 24.0 * u, 0, TAU, 24, ACCENT, 3.0 * u)
	draw_circle(ic + Vector2(-8.0 * u, -8.0 * u), 4.0 * u, Color.WHITE)
	if numbers_hidden:
		var best: float = 1e30
		for i in 5:
			if not sim.maxed(i):
				best = minf(best, sim.cost(i))
		var f: float = clampf(sim.pop / best, 0.0, 1.0) if best < 1e29 else 1.0
		draw_rect(Rect2(cx - 50.0 * u, y - 4.0 * u, 160.0 * u, 20.0 * u), Color(INK, 0.15))
		draw_rect(Rect2(cx - 50.0 * u, y - 4.0 * u, 160.0 * u * f, 20.0 * u), ACCENT)
	else:
		draw_string(_font, Vector2(cx - 56.0 * u, y + 26.0 * u), _fmt(_shown), HORIZONTAL_ALIGNMENT_LEFT, -1, int(64.0 * u), INK)
	_icon_button(_rects["reset"], "reset", _clock < _reset_armed_until)
	_icon_button(_rects["mute"], "mute", muted)
	_icon_button(_rects["info"], "info", panel_open)
	if panel_open:
		_draw_panel(u)


func _draw_panel(u: float) -> void:
	var r: Rect2 = _rects["panel"]
	_style.set_corner_radius_all(int(22 * u))
	_style.bg_color = Color(1, 1, 1, 0.94)
	_style.border_color = Color(INK, 0.4)
	_style.set_border_width_all(int(2 * u))
	draw_style_box(_style, r)
	var t: float = _t()
	var lines: PackedStringArray = PackedStringArray([
		"t %.0fs   view %dx%d   dpr %.1f" % [t, int(_view().x), int(_view().y), metrics.dpr],
		"touches %d (%.1f/min)  field %d  accepted %d" % [metrics.gestures_raw, metrics.per_minute(metrics.gestures_raw, t), metrics.gestures_field, metrics.accepted],
		"upgrade taps %d  bought %d  cancelled %d" % [metrics.upgrade_taps, metrics.upgrade_buys, metrics.cancelled],
		"finger down %.1fs = %.1f%% of time" % [metrics.down_time + _live_down(), 100.0 * metrics.input_fraction(t, _live_down())],
		"travel %.0f px = %.2f x screen width" % [metrics.travel_px, metrics.travel_norm],
		"POP %.0f   per min %.0f" % [sim.earned, sim.earned / maxf(t / 60.0, 1.0 / 60.0)],
		"waves %d  avg %.1f pops  max %d  avg %.2fs" % [sim.wave_total, (float(sim.wave_pops_sum) / float(sim.wave_total)) if sim.wave_total > 0 else 0.0, sim.wave_max, (sim.wave_secs_sum / float(sim.wave_total)) if sim.wave_total > 0 else 0.0],
		"sheet full %d/%d  refill %.1fs" % [sim.full_count(), sim.pos.size(), sim.refill_time()],
		"first action %.1fs  first buy %.1fs  levels %s" % [metrics.first_action_t, metrics.first_buy_t, str(sim.lv)],
	])
	for i in lines.size():
		draw_string(_font, r.position + Vector2(18.0 * u, (34.0 + 33.0 * float(i)) * u), lines[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 30.0 * u, int(22.0 * u), INK)
	for k in ["copy", "num"]:
		var b: Rect2 = _rects[k]
		var label: String = "COPIED" if (k == "copy" and _clock < _copied_until) else ("COPY" if k == "copy" else ("NUM ON" if numbers_hidden else "NUM OFF"))
		_style.set_corner_radius_all(int(14 * u))
		_style.bg_color = Color(ACCENT, 0.9 if _g_target == k else 0.25)
		_style.border_color = Color(ACCENT, 0.8)
		_style.set_border_width_all(int(2 * u))
		draw_style_box(_style, b)
		draw_string(_font, b.position + Vector2(0, 36.0 * u), label, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, int(24.0 * u), INK)


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
	elif kind == "info":
		draw_circle(c + Vector2(0, -rad * 0.42), rad * 0.11, ink)
		draw_line(c + Vector2(0, -rad * 0.15), c + Vector2(0, rad * 0.5), ink, 5.0)
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
		var fill: float = 1.0 if maxed else clampf(sim.pop / sim.cost(i), 0.0, 1.0)
		_style.set_corner_radius_all(int(18 * u))
		_style.bg_color = Color(1, 1, 1, 0.92 if afford or pressed else 0.72)
		_style.border_color = Color(GOLD, 0.6 + 0.4 * pulse) if afford else Color(INK, 0.25)
		_style.set_border_width_all(int((5 if afford else 2) * u))
		var rr: Rect2 = r.grow(-3.0 * u) if pressed else r
		draw_style_box(_style, rr)
		var fh: float = (rr.size.y - 12.0 * u) * fill
		draw_rect(Rect2(rr.position.x + 6.0 * u, rr.end.y - 6.0 * u - fh, 7.0 * u, fh), Color(ACCENT, 0.9) if not afford else Color(GOLD, 0.95))
		_icon(i, rr.get_center() + Vector2(3.0 * u, -4.0 * u), rr.size.x * 0.27, INK if not maxed else Color("5f9b72"))
		for k in Sim.MAX_LEVEL:
			var px: float = rr.position.x + rr.size.x * 0.5 - 4.5 * 6.4 * u + float(k) * 6.4 * u + 3.0 * u
			draw_circle(Vector2(px, rr.end.y - 9.0 * u), 2.3 * u, ACCENT if k < sim.lv[i] else Color(INK, 0.18))
		if i == Sim.I_MEGA and sim.mega_unlocked():
			var prog: float = clampf(sim.mega_clock / sim.mega_period(), 0.0, 1.0)
			draw_arc(rr.get_center(), rr.size.x * 0.5 - 2.0 * u, -PI * 0.5, -PI * 0.5 + TAU * prog, 28, Color(GOLD, 0.95), 4.0 * u)
		if _buy_flash[i] > 0.0:
			draw_arc(rr.get_center(), rr.size.x * (0.5 + 0.5 * (1.0 - _buy_flash[i])), 0, TAU, 28, Color(GOLD, _buy_flash[i]), 5.0 * u)
		if not numbers_hidden and not maxed:
			draw_string(_font, Vector2(rr.position.x + 8.0 * u, rr.position.y + 19.0 * u), _fmt(sim.cost(i)), HORIZONTAL_ALIGNMENT_RIGHT, rr.size.x - 16.0 * u, int(18.0 * u), Color(INK, 0.85))


func _icon(i: int, c: Vector2, s: float, col: Color) -> void:
	match i:
		0: # radius: a dot with a ring that reaches out
			draw_circle(c, s * 0.28, col)
			draw_arc(c, s * 0.7, 0, TAU, 20, col, s * 0.14)
			draw_arc(c, s * 1.05, 0.3, 2.0, 10, col, s * 0.12)
		1: # chain: three linked dots
			for k in 3:
				draw_circle(c + Vector2((float(k) - 1.0) * s * 0.8, (float(k % 2) - 0.5) * s * 0.5), s * 0.28, col)
			draw_line(c + Vector2(-s * 0.8, 0), c + Vector2(0, -s * 0.25), col, s * 0.1)
			draw_line(c + Vector2(0, -s * 0.25), c + Vector2(s * 0.8, 0), col, s * 0.1)
		2: # value: a coin with a plus
			draw_arc(c, s * 0.9, 0, TAU, 24, col, s * 0.16)
			draw_line(c + Vector2(-s * 0.4, 0), c + Vector2(s * 0.4, 0), col, s * 0.18)
			draw_line(c + Vector2(0, -s * 0.4), c + Vector2(0, s * 0.4), col, s * 0.18)
		3: # refill: a circular arrow
			draw_arc(c, s * 0.8, 0.5, TAU - 0.5, 20, col, s * 0.16)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.95, -s * 0.5), c + Vector2(s * 0.3, -s * 0.45), c + Vector2(s * 0.85, s * 0.1)]), col)
		_: # mega: a big burst
			for k in 8:
				var a: float = float(k) * PI * 0.25
				var d: Vector2 = Vector2(cos(a), sin(a))
				draw_line(c + d * s * 0.4, c + d * s * (1.05 if k % 2 == 0 else 0.75), col, s * 0.17)
			draw_circle(c, s * 0.3, col)


func _draw_pad(u: float) -> void:
	var r: Rect2 = _rects["pad"]
	var idle: float = _clock - _last_input_t
	var invite: float = 0.0
	if not _ever_popped:
		invite = 1.0
	elif idle > 6.0:
		invite = clampf((idle - 6.0) / 2.0, 0.0, 1.0)
	var down: bool = _gid != -99 and _g_target == ""
	var ready: bool = sim.mega_ready()
	var pulse: float = 0.5 + 0.5 * sin(_clock * 5.0)
	_style.set_corner_radius_all(int(34 * u))
	_style.bg_color = Color(ACCENT, 0.12 + 0.08 * invite + (0.12 if down else 0.0))
	_style.border_color = Color(GOLD, 0.6 + 0.4 * pulse) if ready else Color(ACCENT, 0.5 + 0.25 * invite)
	_style.set_border_width_all(int((6 if ready else 4) * u))
	draw_style_box(_style, r)
	# the pad is a small live map of the sheet
	var inner: Rect2 = r.grow(-26.0 * u)
	for i in sim.pos.size():
		var p: Vector2 = sim.pos[i]
		var nx: float = p.x / (float(Sim.COLS) - 0.5)
		var ny: float = p.y / (float(Sim.ROWS - 1) * 0.866)
		var c: Vector2 = inner.position + Vector2(nx * inner.size.x, ny * inner.size.y)
		var f: float = sim.fill[i]
		draw_circle(c, 8.0 * u * (0.35 + 0.65 * minf(f, 1.0)), Color(ACCENT, 0.15 + 0.45 * f))
	if down and _g_pad:
		var q: Vector2 = Vector2(clampf(_g_pos.x, r.position.x, r.end.x), clampf(_g_pos.y, r.position.y, r.end.y))
		draw_circle(q, 30.0 * u, Color(INK, 0.18))
		draw_arc(q, 30.0 * u, 0, TAU, 24, Color(ACCENT, 0.9), 4.0 * u)
	elif invite > 0.0:
		var t: float = fmod(_clock * 0.9, 1.4)
		var c2: Vector2 = r.get_center() + Vector2(10.0 * u, 18.0 * u)
		var s: float = 1.0 - clampf(t / 0.25, 0.0, 1.0) * 0.18
		draw_circle(c2, 30.0 * u * s, Color(INK, 0.45 * invite))
		draw_circle(c2, 17.0 * u * s, Color(1, 1, 1, 0.8 * invite))
		if t > 0.25 and t < 0.8:
			draw_arc(c2, (30.0 + (t - 0.25) * 130.0) * u, 0, TAU, 24, Color(ACCENT, 0.7 * (1.0 - (t - 0.25) / 0.55) * invite), 4.0 * u)


# While the finger is down: the ring on the sheet where the pop will begin.
func _draw_aim(u: float) -> void:
	if _gid == -99 or _g_target != "":
		return
	_layout()
	var at: Vector2 = _aim(_g_pos, _g_pad)
	var best: int = -1
	var bd: float = 1e9
	for i in sim.pos.size():
		if sim.poppable(i):
			var d: float = sim.pos[i].distance_to(at)
			if d < bd:
				bd = d
				best = i
	if best < 0:
		return
	var c: Vector2 = _bp(best)
	var pulse: float = 0.5 + 0.5 * sin(_clock * 12.0)
	draw_arc(c, _cell * (0.6 + 0.06 * pulse), 0, TAU, 28, Color(PINK, 0.95), maxf(3.0, _cell * 0.07))
	# the reach of the wave, so a bigger Radius is something you can see
	var rad: float = sim.radius() * (1.7 if sim.mega_ready() else 1.0) * _cell
	draw_arc(c, rad, 0, TAU, 48, Color(PINK, 0.3), 2.0 * u)


# ---- sound ------------------------------------------------------------------

func _build_sfx() -> void:
	for k in 6:
		_pop_streams.append(_tone(380.0 + 90.0 * float(k), 160.0 + 40.0 * float(k), 0.09, 0.32, 0.25))
	var defs: Dictionary = {
		"buy": [660.0, 990.0, 0.2, 0.3, 0.0],
		"tick": [420.0, 380.0, 0.05, 0.2, 0.0],
		"mega": [300.0, 900.0, 0.35, 0.35, 0.1],
	}
	for k in defs:
		var d: Array = defs[k]
		_sfx[k] = _tone(float(d[0]), float(d[1]), float(d[2]), float(d[3]), float(d[4]))
		_sfx_t[k] = -9.0
	for i in 8:
		var pl: AudioStreamPlayer = AudioStreamPlayer.new()
		pl.volume_db = -7.0
		add_child(pl)
		_players.append(pl)


func _tone(f0: float, f1: float, dur: float, vol: float, noise: float) -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(float(rate) * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var ph: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 13
	for i in n:
		var t: float = float(i) / float(n)
		ph += TAU * lerpf(f0, f1, t) / float(rate)
		var env: float = pow(1.0 - t, 2.5) * minf(1.0, t * 60.0)
		var s: float = (sin(ph) * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise) * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func _play(stream: AudioStream) -> void:
	if muted:
		return
	var pl: AudioStreamPlayer = _players[_pool_i]
	_pool_i = (_pool_i + 1) % _players.size()
	pl.stream = stream
	pl.play()


func _pop_sound(depth: int, mega: bool) -> void:
	_play(_sfx["mega"] if mega and depth == 0 else _pop_streams[mini(depth, _pop_streams.size() - 1)])


func _blip(name: String) -> void:
	if not _sfx.has(name) or _clock - float(_sfx_t[name]) < 0.05:
		return
	_sfx_t[name] = _clock
	_play(_sfx[name])


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
	rects["sheet"] = [_sheet.position.x / v.x, _sheet.position.y / v.y, _sheet.size.x / v.x, _sheet.size.y / v.y]
	var st: Dictionary = {
		"t": snappedf(sim.time, 0.01),
		"pop": snappedf(sim.pop, 0.1),
		"earned": snappedf(sim.earned, 0.1),
		"lv": sim.lv,
		"triggers": sim.triggers,
		"pops": sim.pops,
		"full": sim.full_count(),
		"total": sim.pos.size(),
		"pending": sim.pending.size(),
		"lastWave": sim.last_wave_count,
		"lastWaveSecs": snappedf(sim.last_wave_secs, 0.01),
		"megaReady": sim.mega_ready(),
		"refill": snappedf(sim.refill_time(), 0.01),
		"muted": muted,
		"hidden": numbers_hidden,
		"view": [v.x, v.y],
		"rects": rects,
		"m": {"raw": metrics.gestures_raw, "field": metrics.gestures_field, "accepted": metrics.accepted, "upTaps": metrics.upgrade_taps, "buys": metrics.upgrade_buys, "cancelled": metrics.cancelled, "downS": snappedf(metrics.down_time, 0.001), "inputFrac": snappedf(metrics.input_fraction(_t(), _live_down()), 0.0001), "travelNorm": snappedf(metrics.travel_norm, 0.01), "elapsed": snappedf(_t(), 0.01)},
		"costs": _costs(),
		"summary": _summary(),
	}
	_win.set("__bubble", JSON.stringify(st))
