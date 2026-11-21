class_name PopUpgradeButton
extends PopPressArea

## The one upgrade: the next machine (a silhouette until affordable, then in colour) and its price. The button
## fills from the bottom as money nears the price and shines when it can be
## bought -- the picture of "what comes next", with no words.

var stage := 1          # the stage this purchase leads to
var price := 0          # -1: nothing left to buy
var money := 0
## Set when the run is finished (the stand, Step 12): the active time it took,
## shown under the star -- the ending, in numbers.
var done_label := ""
var gain_now := -1     # what one action pays now and after this purchase
var gain_next := -1
var _shine := 0.0
var _t := 0.0


func set_offer(next_stage: int, p_price: int, p_money: int) -> void:
	if next_stage != stage or p_price != price or p_money != money:
		stage = next_stage
		price = p_price
		money = p_money
		enabled = price >= 0 and money >= price
		queue_redraw()


## Step 20: what the card sells can change (the factory's open floor): a
## picture to draw instead of the kettle (Callable(ci, foot, h, stage, colour)),
## the prefix of the gain numbers ("+" coins, "" packs a minute).
var art := Callable()
var gain_prefix := "+"
var art_key := ""


func set_art(key: String, p_art: Callable, prefix: String) -> void:
	if key != art_key:
		art_key = key
		art = p_art
		gain_prefix = prefix
		queue_redraw()


func set_gain(now: int, next: int) -> void:
	if now != gain_now or next != gain_next:
		gain_now = now
		gain_next = next
		queue_redraw()


func progress() -> float:
	if price <= 0:
		return 1.0 if price == 0 else 0.0
	return clampf(float(money) / float(price), 0.0, 1.0)


## Step 46: everything is drawn on this face, and the face bobs, presses and shakes by its
## position. Until 0.46 the button redrew itself every frame while it could be bought (the
## bob was in the drawing): its rounded plates, outline, coin and the next machine's picture
## are polygons, and each redrawn polygon is a new GL id the web build never gives back
## (QUALITY_GATES R-01). Now it redraws when what it shows changes.
var _face := Node2D.new()
## ... and the next machine's picture on its own child: the face redraws with the wallet (the
## fill, the price), the picture only when the offer or its colour (the shine) changes.
var _pic := Node2D.new()
var _pic_key := ""


func _ready() -> void:
	_face.name = "Face"
	add_child(_face)
	_face.draw.connect(func() -> void: _draw_face(_face))
	_pic.name = "Picture"
	_face.add_child(_pic)
	_pic.draw.connect(func() -> void: _draw_pic(_pic))


func _process(delta: float) -> void:
	_t += delta
	_step_deny(delta)
	var target := 1.0 if enabled else 0.0
	if not is_equal_approx(_shine, target):
		_shine = move_toward(_shine, target, delta * 4.0)
		queue_redraw()
	_face.position = Vector2(deny_offset(), sin(_t * 6.0) * 4.0 * _shine - (3.0 if held else 0.0))


## Every queue_redraw() of the button (its offers, a press, the hover) redraws the face; the
## picture when what it shows changed.
func _draw() -> void:
	_face.queue_redraw()
	var key := "%s|%d|%d|%s|%.2f|%s" % [art_key, stage, price, size, _sil_alpha(), art.is_valid()]
	if key != _pic_key:
		_pic_key = key
		_pic.queue_redraw()


func _sil_alpha() -> float:
	return 0.35 + 0.5 * _shine if _shine < 0.5 else 0.0


func _draw_face(ci: CanvasItem) -> void:
	var r := Rect2(Vector2.ZERO, size)
	var rad := size.y * 0.22
	_round(ci, Rect2(r.position + Vector2(0, 8), r.size), rad, PopPalette.SHADOW)
	_round(ci, r, rad, Color(1, 1, 1, 0.92))
	if price < 0:
		# Nothing more to buy: a gold star where the next machine would be.
		if done_label == "":
			ci.draw_colored_polygon(PopMachineArt._star(r.get_center(), size.y * 0.32, size.y * 0.14), PopPalette.GOLD)
			return
		var sc := r.get_center() - Vector2(size.y * 0.75, 0)
		ci.draw_colored_polygon(PopMachineArt._star(sc, size.y * 0.32, size.y * 0.14), PopPalette.GOLD)
		var f := ThemeDB.fallback_font
		var tfs := int(size.y * 0.36)
		ci.draw_string(f, Vector2(sc.x + size.y * 0.5, r.get_center().y + tfs * 0.36), done_label, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, PopPalette.INK)
		return
	# The fill: money's share of the price, rising from the bottom.
	var p := progress()
	if p > 0.0:
		var fh := (r.size.y - 12.0) * p
		_round(ci, Rect2(r.position.x + 6, r.end.y - 6 - fh, r.size.x - 12, fh), rad * 0.8,
			PopPalette.GOLD.lerp(Color(1, 0.93, 0.6), 0.5 - 0.5 * _shine))
	_outline(ci, r, rad, PopPalette.GOLD if enabled else PopPalette.DISABLED, 7.0 if hovered and enabled else 5.0)
	# (the next machine's picture: _draw_pic, on its own child)
	# Price: coin + number.
	var font := ThemeDB.fallback_font
	var fs := int(size.y * 0.3)
	var text := PopMoneyView._format(price)
	var cx := r.position.x + r.size.y * 1.25
	var showing_gain := gain_now > 0 and gain_next > 0
	var py := r.get_center().y - (fs * 0.42 if showing_gain else 0.0)
	PopMachineArt.draw_coin(ci, Vector2(cx + fs * 0.45, py), fs * 0.42)
	# A long price shrinks to fit before the arrow (Step 11: '14,000' ran into it).
	var pfs := fs
	var avail := (r.end.x - r.size.y * 0.42 - r.size.y * 0.24) - (cx + fs * 1.05)
	while pfs > 14 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x > avail:
		pfs -= 2
	ci.draw_string(font, Vector2(cx + fs * 1.05, py + pfs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs,
		PopPalette.INK if enabled else PopPalette.DISABLED.darkened(0.25))
	if showing_gain:
		# What it gives, in the same "+N" that floats over the machine when it
		# pays: +now, a small arrow, +next (next in the arrow's red).
		var gs := int(fs * 0.72)
		var gy := r.get_center().y + fs * 0.98
		var ink := Color(PopPalette.INK, 0.7) if enabled else PopPalette.DISABLED.darkened(0.2)
		var now_s := gain_prefix + PopMoneyView._format(gain_now)
		var next_s := gain_prefix + PopMoneyView._format(gain_next)
		var gx := cx + fs * 0.1
		# The whole line fits before the arrow (Step 11: large numbers ran under it).
		var room := (r.end.x - r.size.y * 0.42 - r.size.y * 0.24) - gx
		while gs > 12 and font.get_string_size(now_s + next_s, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x + gs * 1.05 > room:
			gs -= 2
		ci.draw_string(font, Vector2(gx, gy), now_s, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, ink)
		gx += font.get_string_size(now_s, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x + gs * 0.3
		var ay := gy - gs * 0.33
		ci.draw_colored_polygon(PackedVector2Array([Vector2(gx, ay - gs * 0.3), Vector2(gx + gs * 0.45, ay), Vector2(gx, ay + gs * 0.3)]), ink)
		gx += gs * 0.75
		ci.draw_string(font, Vector2(gx, gy), next_s, HORIZONTAL_ALIGNMENT_LEFT, -1, gs,
			PopPalette.RED if enabled else PopPalette.DISABLED.darkened(0.25))
	# An up-arrow: "this makes the machine bigger".
	var a := Vector2(r.end.x - r.size.y * 0.42, r.get_center().y)
	var k := r.size.y * 0.16
	var col := PopPalette.RED if enabled else PopPalette.DISABLED
	ci.draw_colored_polygon(PackedVector2Array([a + Vector2(0, -k * 1.4), a + Vector2(k, -k * 0.2), a + Vector2(-k, -k * 0.2)]), col)
	ci.draw_rect(Rect2(a + Vector2(-k * 0.4, -k * 0.25), Vector2(k * 0.8, k * 1.4)), col)


## The next machine: a quiet silhouette while it is out of reach; in its own colours once it
## can be bought (Step 40: the reveal -- what you are about to get, not a grey shape).
func _draw_pic(ci: CanvasItem) -> void:
	if price < 0:
		return
	var r := Rect2(Vector2.ZERO, size)
	var a := _sil_alpha()
	var sil := Color(PopPalette.INK, a) if a > 0.0 else Color(0, 0, 0, 0)
	# Sized so the tallest stage (with its star) stays inside the button.
	if art.is_valid():
		art.call(ci, Vector2(r.position.x + r.size.y * 0.62, r.end.y - r.size.y * 0.16), r.size.y * 0.74, stage, sil)
	else:
		PopMachineArt.draw(ci, Vector2(r.position.x + r.size.y * 0.62, r.end.y - r.size.y * 0.1),
			r.size.y * 0.74, stage, 0.0, 0.3, sil)


func _round(ci: CanvasItem, rr: Rect2, rad: float, col: Color) -> void:
	PopMachineArt._round_rect(ci, rr, rad, col)


func _outline(ci: CanvasItem, rr: Rect2, rad: float, col: Color, w: float) -> void:
	var pts := PopMachineArt.round_rect_points(rr, rad)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, w)
