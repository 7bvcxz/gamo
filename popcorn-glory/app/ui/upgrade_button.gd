class_name PopUpgradeButton
extends PopPressArea

## The one upgrade: the next machine's silhouette and its price. The button
## fills from the bottom as money nears the price and shines when it can be
## bought -- the picture of "what comes next", with no words.

var stage := 1          # the stage this purchase leads to
var price := 0          # -1: nothing left to buy
var money := 0
var _shine := 0.0
var _t := 0.0


func set_offer(next_stage: int, p_price: int, p_money: int) -> void:
	if next_stage != stage or p_price != price or p_money != money:
		stage = next_stage
		price = p_price
		money = p_money
		enabled = price >= 0 and money >= price
		queue_redraw()


func progress() -> float:
	if price <= 0:
		return 1.0 if price == 0 else 0.0
	return clampf(float(money) / float(price), 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if enabled else 0.0
	if not is_equal_approx(_shine, target) or enabled:
		_shine = move_toward(_shine, target, delta * 4.0)
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bob := sin(_t * 6.0) * 4.0 * _shine
	r.position.y += bob - (3.0 if held else 0.0)
	var rad := size.y * 0.22
	_round(Rect2(r.position + Vector2(0, 8), r.size), rad, PopPalette.SHADOW)
	_round(r, rad, Color(1, 1, 1, 0.92))
	if price < 0:
		# Nothing more to buy: a gold star where the next machine would be.
		draw_colored_polygon(PopMachineArt._star(r.get_center(), size.y * 0.32, size.y * 0.14), PopPalette.GOLD)
		return
	# The fill: money's share of the price, rising from the bottom.
	var p := progress()
	if p > 0.0:
		var fh := (r.size.y - 12.0) * p
		_round(Rect2(r.position.x + 6, r.end.y - 6 - fh, r.size.x - 12, fh), rad * 0.8,
			PopPalette.GOLD.lerp(Color(1, 0.93, 0.6), 0.5 - 0.5 * _shine))
	_outline(r, rad, PopPalette.GOLD if enabled else PopPalette.DISABLED, 7.0 if hovered and enabled else 5.0)
	# The next machine, as a silhouette (bright when affordable).
	var sil := Color(PopPalette.INK, 0.35 + 0.5 * _shine)
	# Sized so the tallest stage (with its star) stays inside the button.
	PopMachineArt.draw(self, Vector2(r.position.x + r.size.y * 0.62, r.end.y - r.size.y * 0.1),
		r.size.y * 0.74, stage, 0.0, 0.3, sil)
	# Price: coin + number.
	var font := ThemeDB.fallback_font
	var fs := int(size.y * 0.3)
	var text := PopMoneyView._format(price)
	var cx := r.position.x + r.size.y * 1.25
	PopMachineArt.draw_coin(self, Vector2(cx + fs * 0.45, r.get_center().y), fs * 0.42)
	draw_string(font, Vector2(cx + fs * 1.05, r.get_center().y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		PopPalette.INK if enabled else PopPalette.DISABLED.darkened(0.25))
	# An up-arrow: "this makes the machine bigger".
	var a := Vector2(r.end.x - r.size.y * 0.42, r.get_center().y)
	var k := r.size.y * 0.16
	var col := PopPalette.RED if enabled else PopPalette.DISABLED
	draw_colored_polygon(PackedVector2Array([a + Vector2(0, -k * 1.4), a + Vector2(k, -k * 0.2), a + Vector2(-k, -k * 0.2)]), col)
	draw_rect(Rect2(a + Vector2(-k * 0.4, -k * 0.25), Vector2(k * 0.8, k * 1.4)), col)


func _round(rr: Rect2, rad: float, col: Color) -> void:
	PopMachineArt._round_rect(self, rr, rad, col)


func _outline(rr: Rect2, rad: float, col: Color, w: float) -> void:
	var pts := PopMachineArt.round_rect_points(rr, rad)
	pts.append(pts[0])
	draw_polyline(pts, col, w)
