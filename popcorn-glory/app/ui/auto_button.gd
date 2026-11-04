class_name PopAutoButton
extends PopPressArea

## The Popcorn Stand's second purchase (Step 10): the next machine that takes
## over a job. A motor (the shake) or the helper kettle (the hold and the
## release, by itself), its price, and what it changes in numbers:
##   motor  -- x1.3 on every batch (the even pop without shaking)
##   helper -- +now > +next per helper batch, and its cycle in seconds
## Hidden until unlock.auto; a gold star when the ladder is done.

var kind := ""          # "motor" | "helper" | "" (done)
var price := -1
var money := 0
var rung := 0           # rungs bought so far
var gain_now := 0
var gain_next := 0
var cycle_now := 0.0
var cycle_next := 0.0
var mult := 1.0
var _shine := 0.0
var _t := 0.0


func set_offer(p_kind: String, p_price: int, p_money: int, p_rung: int, now: int, next: int, c_now: float, c_next: float, p_mult: float) -> void:
	var changed := p_kind != kind or p_price != price or p_money != money or p_rung != rung or now != gain_now or next != gain_next
	kind = p_kind
	price = p_price
	money = p_money
	rung = p_rung
	gain_now = now
	gain_next = next
	cycle_now = c_now
	cycle_next = c_next
	mult = p_mult
	enabled = price >= 0 and money >= price
	if changed:
		queue_redraw()


func progress() -> float:
	return clampf(float(money) / float(price), 0.0, 1.0) if price > 0 else 0.0


func _process(delta: float) -> void:
	_t += delta
	_step_deny(delta)
	var target := 1.0 if enabled else 0.0
	if not is_equal_approx(_shine, target) or enabled:
		_shine = move_toward(_shine, target, delta * 4.0)
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	r.position.y += sin(_t * 6.0) * 3.0 * _shine - (3.0 if held else 0.0)
	r.position.x += deny_offset()
	var rad := size.y * 0.24
	PopMachineArt._round_rect(self, Rect2(r.position + Vector2(0, 6), r.size), rad, PopPalette.SHADOW)
	PopMachineArt._round_rect(self, r, rad, Color(0.93, 0.96, 1.0, 0.95))
	if kind == "":
		PopMachineArt._round_rect(self, r, rad, Color(0.93, 0.96, 1.0, 0.95))
		draw_colored_polygon(PopMachineArt._star(r.get_center(), size.y * 0.3, size.y * 0.13), PopPalette.GOLD)
		return
	var p := progress()
	if p > 0.0:
		var fh := (r.size.y - 10.0) * p
		PopMachineArt._round_rect(self, Rect2(r.position.x + 5, r.end.y - 5 - fh, r.size.x - 10, fh), rad * 0.8,
			Color(0.55, 0.75, 1.0).lerp(Color(0.8, 0.9, 1.0), 0.5 - 0.5 * _shine))
	var pts := PopMachineArt.round_rect_points(r, rad)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.3, 0.55, 0.95) if enabled else PopPalette.DISABLED, 5.0)
	var cy := r.get_center().y
	var icon_c := Vector2(r.position.x + r.size.y * 0.6, cy)
	var ink := PopPalette.INK if enabled else PopPalette.DISABLED.darkened(0.25)
	if kind == "motor":
		# A gear.
		var g := r.size.y * 0.28
		for i in 8:
			var a := TAU * float(i) / 8.0 + _t * (2.0 if enabled else 0.0)
			draw_line(icon_c, icon_c + Vector2(cos(a), sin(a)) * g * 1.3, ink, g * 0.35)
		draw_circle(icon_c, g, Color(0.35, 0.4, 0.5) if enabled else PopPalette.DISABLED)
		draw_circle(icon_c, g * 0.4, Color(0.93, 0.96, 1.0))
	else:
		# The helper kettle at its next look, as a silhouette.
		PopMachineArt.draw(self, icon_c + Vector2(0, r.size.y * 0.36), r.size.y * 0.62, clampi(rung * 2, 0, 14), 0.0, 0.3,
			Color(PopPalette.INK, 0.35 + 0.5 * _shine))
	var font := ThemeDB.fallback_font
	var fs := int(size.y * 0.3)
	var cx := r.position.x + r.size.y * 1.2
	PopMachineArt.draw_coin(self, Vector2(cx + fs * 0.45, cy - fs * 0.42), fs * 0.42)
	var ptext := PopMoneyView._format(price)
	var pfs := fs
	while pfs > 14 and font.get_string_size(ptext, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x > r.end.x - (cx + fs * 1.05) - 16:
		pfs -= 2
	draw_string(font, Vector2(cx + fs * 1.05, cy - fs * 0.06), ptext, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, ink)
	var gs := int(fs * 0.72)
	var gy := cy + fs * 0.92
	var line := ""
	if kind == "motor":
		line = "+%s > +%s" % [PopMoneyView._format(gain_now), PopMoneyView._format(gain_next)] if gain_next > 0 else "x%s" % str(snappedf(mult, 0.01))
	else:
		line = "+%s > +%s   %.1fs" % [PopMoneyView._format(gain_now), PopMoneyView._format(gain_next), cycle_next]
		if cycle_now > 0.0:
			line = "+%s > +%s   %.1f > %.1fs" % [PopMoneyView._format(gain_now), PopMoneyView._format(gain_next), cycle_now, cycle_next]
	while gs > 12 and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x > r.end.x - cx - 24:
		gs -= 2
	draw_string(font, Vector2(cx + fs * 0.1, gy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, gs,
		Color(PopPalette.INK, 0.75) if enabled else PopPalette.DISABLED.darkened(0.2))
