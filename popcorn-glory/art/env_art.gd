class_name PopEnvArt
extends RefCounted
## Step 40: the three rooms behind the machines -- original, procedural (no generated or stock
## images: the image service is a paid one, and the art direction is candy-coloured shapes).
##  * the kitchen (bottom): a warm brick wall, a copper pipe along the top, hanging lamps whose
##    glow pools on the floor -- one lamp lit for the humble first kettle, two more as kettles come
##  * the packing workshop (middle): clean pale tiles, a daylight window, an epoxy floor with a
##    safety stripe
##  * the shop (top): street windows with a dusk sky and the houses opposite, string lights,
##    a wooden floor -- busier (lit windows across the street) as the sign grows
## Everything is filled shapes (no anti-aliased lines: each is many render objects) drawn once
## when the floor layer redraws, and low in contrast: the machines and the hand's kettle stay
## the brightest things on each floor. Insets keep every shape inside the rounded panel.

const INSET := 14.0

const BRICK := Color(0.97, 0.8, 0.64)
const BRICK_DARK := Color(0.95, 0.75, 0.59)
const MORTAR := Color(0.99, 0.88, 0.73)
const COPPER := Color(0.82, 0.5, 0.3)
const COPPER_HI := Color(0.95, 0.68, 0.45)
const LAMP_SHADE := Color(0.33, 0.25, 0.24)
const GLOW := Color(1.0, 0.9, 0.55)
const TILE := Color(0.95, 0.96, 0.93)
const TILE_LINE := Color(0.86, 0.9, 0.86)
const EPOXY := Color(0.8, 0.88, 0.86)
const DAY := Color(0.78, 0.9, 0.98)
const WOOD := Color(0.86, 0.62, 0.42)
const WOOD_DARK := Color(0.78, 0.53, 0.35)
const DUSK_TOP := Color(0.62, 0.72, 0.96)
const DUSK_LOW := Color(1.0, 0.8, 0.7)
const HOUSE := Color(0.7, 0.6, 0.76)
const WIN_LIT := Color(1.0, 0.86, 0.5)
const FRAME := Color(0.98, 0.93, 0.84)


static func _r(ci: CanvasItem, r: Rect2, c: Color) -> void:
	ci.draw_rect(r, c)


## The kitchen. `kettles`: auto kettles built (lamps lit: 1 + one per four, up to 3 -- all on the
## brick wall, never over the machine places).
static func kitchen(ci: CanvasItem, r: Rect2, kettles: int) -> void:
	var inner := r.grow(-INSET)
	# floor: a band of dark warm tiles at the bottom (the cooker stands on it)
	var fh := inner.size.y * 0.16
	var floor := Rect2(Vector2(inner.position.x, inner.end.y - fh), Vector2(inner.size.x, fh))
	_r(ci, floor, Color(0.9, 0.72, 0.56))
	var tw := fh * 1.1
	var n := int(inner.size.x / tw)
	for k in n:
		if k % 2 == 0:
			_r(ci, Rect2(Vector2(floor.position.x + k * tw, floor.position.y + fh * 0.12), Vector2(tw, fh * 0.88)), Color(0.87, 0.67, 0.51))
	_r(ci, Rect2(floor.position, Vector2(floor.size.x, 3)), Color(0.8, 0.58, 0.42))
	# brick wall behind the hand's kettle (left part; the machine places stand on the right)
	var wall := Rect2(inner.position + Vector2(0, inner.size.y * 0.1), Vector2(inner.size.x * 0.52, inner.size.y * 0.74 - fh * 0.0))
	wall.size.y = floor.position.y - wall.position.y
	_r(ci, wall, MORTAR)
	var bh := maxf(10.0, inner.size.y * 0.055)
	var bw := bh * 2.6
	var rows := int(wall.size.y / bh)
	for row in rows:
		var off := (bw * 0.5) if row % 2 == 1 else 0.0
		var x := wall.position.x - off
		var y := wall.position.y + row * bh
		var k := 0
		while x < wall.end.x:
			var x0 := maxf(x + 1.5, wall.position.x)
			var x1 := minf(x + bw - 1.5, wall.end.x)
			if x1 > x0:
				_r(ci, Rect2(Vector2(x0, y + 1.5), Vector2(x1 - x0, bh - 3)), BRICK_DARK if (row * 7 + k * 3) % 5 == 0 else BRICK)
			x += bw
			k += 1
	# a soft fade where the wall meets the room (no hard edge)
	for q in 4:
		var a := 0.22 * (1.0 - q / 4.0)
		_r(ci, Rect2(Vector2(wall.end.x + q * 6, wall.position.y), Vector2(6, wall.size.y)), Color(MORTAR, a))
	# copper pipe along the top with two joints and a valve wheel
	var py := inner.position.y + inner.size.y * 0.07
	var ph := maxf(6.0, inner.size.y * 0.03)
	_r(ci, Rect2(Vector2(inner.position.x + 60, py), Vector2(inner.size.x - 80, ph)), COPPER)
	_r(ci, Rect2(Vector2(inner.position.x + 60, py), Vector2(inner.size.x - 80, ph * 0.35)), COPPER_HI)
	for jx in [0.35, 0.7]:
		_r(ci, Rect2(Vector2(inner.position.x + inner.size.x * jx - ph * 0.6, py - ph * 0.3), Vector2(ph * 1.2, ph * 1.6)), COPPER.darkened(0.12))
	# hanging lamps: the first over the hand's kettle, the others along the room
	var lit := clampi(1 + kettles / 4, 1, 3)
	# (right of the floor badge in the top-left corner, clear of the ring's smoke icon at its top)
	var xs := [inner.position.x + inner.size.x * 0.15, inner.position.x + inner.size.x * 0.47, inner.position.x + inner.size.x * 0.3]
	for i in 3:
		var x: float = xs[i]
		var on := i < lit
		var cord_top := py + ph
		var shade_y := cord_top + inner.size.y * (0.05 if i == 0 else 0.03)
		_r(ci, Rect2(Vector2(x - 1, cord_top), Vector2(2, shade_y - cord_top)), LAMP_SHADE)
		var sw := inner.size.y * (0.075 if i == 0 else 0.05)
		if on:   # the glow: two soft cones and a pool on the floor
			for g in 2:
				var spread := sw * (1.6 + g * 1.2)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - sw * 0.5, shade_y + sw * 0.4), Vector2(x + sw * 0.5, shade_y + sw * 0.4),
					Vector2(x + spread, floor.position.y), Vector2(x - spread, floor.position.y)]), Color(GLOW, 0.11 - g * 0.04))
			ci.draw_colored_polygon(_ellipse(Vector2(x, floor.position.y + fh * 0.3), sw * 2.2, fh * 0.28, 14), Color(GLOW, 0.22))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - sw * 0.25, shade_y), Vector2(x + sw * 0.25, shade_y), Vector2(x + sw * 0.55, shade_y + sw * 0.45), Vector2(x - sw * 0.55, shade_y + sw * 0.45)]), LAMP_SHADE)
		ci.draw_circle(Vector2(x, shade_y + sw * 0.47), sw * 0.2, GLOW if on else Color(0.75, 0.72, 0.65))


## The packing workshop.
static func packing(ci: CanvasItem, r: Rect2) -> void:
	var inner := r.grow(-INSET)
	var fh := inner.size.y * 0.14
	var floor := Rect2(Vector2(inner.position.x, inner.end.y - fh), Vector2(inner.size.x, fh))
	# pale tiles over the upper wall (large tiles: few shapes)
	var wall := Rect2(inner.position + Vector2(70, 0), Vector2(inner.size.x - 140, floor.position.y - inner.position.y))
	var ts := maxf(18.0, wall.size.y / 4.0)
	_r(ci, wall, TILE_LINE)
	var cols := int(wall.size.x / ts)
	var rows := int(wall.size.y / ts)
	for row in rows:
		for col in cols:
			_r(ci, Rect2(wall.position + Vector2(col * ts + 1.5, row * ts + 1.5), Vector2(ts - 3, ts - 3)), TILE if (row + col) % 3 != 0 else TILE.darkened(0.025))
	# a daylight window high on the wall, between the station and the shelf
	var win := Rect2(Vector2(inner.position.x + inner.size.x * 0.49, inner.position.y + inner.size.y * 0.06), Vector2(inner.size.x * 0.1, inner.size.y * 0.3))
	_r(ci, win.grow(4), FRAME)
	_r(ci, win, DAY)
	_r(ci, Rect2(win.position, Vector2(win.size.x, win.size.y * 0.35)), DAY.lightened(0.25))
	_r(ci, Rect2(Vector2(win.get_center().x - 2, win.position.y), Vector2(4, win.size.y)), FRAME)
	ci.draw_colored_polygon(PackedVector2Array([win.position + Vector2(win.size.x * 0.15, win.size.y), win.end, win.end + Vector2(win.size.x * 0.6, floor.position.y - win.end.y), Vector2(win.position.x + win.size.x * 0.4, floor.position.y)]), Color(1, 1, 1, 0.16))
	# the epoxy floor with a safety stripe along its front
	_r(ci, floor, EPOXY)
	_r(ci, Rect2(floor.position, Vector2(floor.size.x, 3)), EPOXY.darkened(0.12))
	var sw := fh * 0.9
	var k := 0
	var x := floor.position.x + 20
	while x + sw < floor.end.x - 20:
		if k % 2 == 0:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x, floor.end.y - fh * 0.25), Vector2(x + sw * 0.5, floor.end.y - fh * 0.25), Vector2(x + sw * 0.7, floor.end.y - 2), Vector2(x + sw * 0.2, floor.end.y - 2)]), Color(0.98, 0.82, 0.35, 0.55))
		x += sw * 0.5
		k += 1


## The shop. `look`: the sign's look (0-8) -- the street gets livelier with it.
static func shop(ci: CanvasItem, r: Rect2, look: int) -> void:
	var inner := r.grow(-INSET)
	var fh := inner.size.y * 0.14
	var floor := Rect2(Vector2(inner.position.x, inner.end.y - fh), Vector2(inner.size.x, fh))
	# street windows behind the waiting space (between the sign and the paper)
	var top := inner.position.y + inner.size.y * 0.18
	var wy := floor.position.y - top - inner.size.y * 0.12
	var x0 := inner.position.x + inner.size.x * 0.3
	var x1 := inner.end.x - 80
	var panes := 3
	var gap := 10.0
	var pw := (x1 - x0 - gap * (panes - 1)) / panes
	for p in panes:
		var w := Rect2(Vector2(x0 + p * (pw + gap), top), Vector2(pw, wy))
		_r(ci, w.grow(5), FRAME)
		# a dusk sky in four bands, then the houses across the street
		for b in 4:
			_r(ci, Rect2(Vector2(w.position.x, w.position.y + w.size.y * b / 4.0), Vector2(w.size.x, w.size.y / 4.0 + 1)), DUSK_TOP.lerp(DUSK_LOW, b / 3.0))
		var hx := w.position.x
		var hk := p * 3
		while hx < w.end.x:
			var hw := minf(w.size.x * (0.22 + 0.08 * ((hk * 7) % 3)), w.end.x - hx)
			var hh := w.size.y * (0.35 + 0.12 * ((hk * 5) % 3))
			var house := Rect2(Vector2(hx, w.end.y - hh), Vector2(hw, hh))
			_r(ci, house, HOUSE.lerp(Color(0.6, 0.52, 0.7), ((hk * 3) % 2) * 0.5))
			# its windows: more lit as the sign grows (the street wakes up)
			var lit_share := clampf(0.2 + look * 0.1, 0.2, 1.0)
			for wi in 2:
				var wr := Rect2(house.position + Vector2(hw * (0.2 + 0.4 * wi), hh * 0.25), Vector2(hw * 0.22, hh * 0.18))
				if wr.end.x <= w.end.x:
					_r(ci, wr, WIN_LIT if float((hk * 13 + wi * 7) % 10) / 10.0 < lit_share else Color(0.55, 0.5, 0.66))
			hx += hw + 2
			hk += 1
		# a pane's shine
		ci.draw_colored_polygon(PackedVector2Array([w.position + Vector2(w.size.x * 0.1, 0), w.position + Vector2(w.size.x * 0.32, 0), w.position + Vector2(w.size.x * 0.12, w.size.y), w.position + Vector2(0, w.size.y), w.position + Vector2(0, w.size.y * 0.55)]), Color(1, 1, 1, 0.14))
	# string lights across the wall under the awning
	var ly := top - 6
	var nb := 14
	for q in nb:
		var t := float(q) / float(nb - 1)
		var bx := lerpf(x0 - 20, x1 + 20, t)
		var by := ly + sin(t * PI * 3.0) * -4.0 + 4.0
		ci.draw_circle(Vector2(bx, by), 3.4, Color(1.0, 0.85, 0.45) if q % 3 != 1 else Color(1.0, 0.55, 0.6))
	# the wooden floor
	_r(ci, floor, WOOD)
	var bw := floor.size.x / 9.0
	for q in 9:
		if q % 2 == 0:
			_r(ci, Rect2(Vector2(floor.position.x + q * bw, floor.position.y + 3), Vector2(bw, floor.size.y - 3)), WOOD_DARK)
	_r(ci, Rect2(floor.position, Vector2(floor.size.x, 3)), WOOD_DARK.darkened(0.15))


static func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
