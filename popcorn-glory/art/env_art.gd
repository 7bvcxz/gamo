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
const STEEL := Color(0.78, 0.8, 0.82)
const STEEL_HI := Color(0.86, 0.88, 0.9)
const BRASS := Color(0.86, 0.68, 0.36)
const MINT := Color(0.72, 0.9, 0.84)
const LEAF := Color(0.46, 0.72, 0.5)


static func _r(ci: Object, r: Rect2, c: Color) -> void:
	ci.draw_rect(r, c)


## Paints rects into an Image (the bake target): the same `draw_rect` as a CanvasItem, at the
## screen's pixel scale; a translucent rect blends over what is under its middle.
class Baker:
	var img: Image
	var o: Vector2
	var k: float

	func _init(p_img: Image, p_o: Vector2, p_k: float) -> void:
		img = p_img
		o = p_o
		k = p_k

	func draw_rect(r: Rect2, c: Color) -> void:
		var p0 := ((r.position - o) * k).round()
		var p1 := ((r.end - o) * k).round()
		var rr := Rect2i(Vector2i(p0), Vector2i(p1 - p0)).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		if rr.size.x <= 0 or rr.size.y <= 0:
			return
		if c.a < 1.0:
			var base := img.get_pixelv(rr.get_center())
			if base.a > 0.0:
				c = Color(base.lerp(Color(c, 1.0), c.a), base.a)
		img.fill_rect(rr, c)


static var _baked := {}


## Draws `paint(baker)` as one texture over `area` (made once per key and screen scale): a wall of
## many rects is one render object.
static func _bake(ci: CanvasItem, key: String, area: Rect2, paint: Callable) -> void:
	var k := clampf((ci.get_viewport().get_final_transform() * ci.get_global_transform_with_canvas()).get_scale().x, 0.5, 2.0)
	var full := "%s|%.3f" % [key, k]
	var tex: ImageTexture = _baked.get(full)
	if tex == null:
		var img := Image.create(maxi(1, ceili(area.size.x * k)), maxi(1, ceili(area.size.y * k)), false, Image.FORMAT_RGBA8)
		paint.call(Baker.new(img, area.position, k))
		tex = ImageTexture.create_from_image(img)
		if _baked.size() > 8:   # (a resize makes new keys: keep only the latest few)
			_baked.clear()
		_baked[full] = tex
	ci.draw_texture_rect(tex, area, false)


## The kitchen. `kettles`: auto kettles built (lamps lit: 1 + one per four, up to 3 -- all on the
## brick wall, never over the machine places). `level`: the kitchen's lines bought (1-3): a second
## line brings a brushed-steel wainscot and a second pipe, the third a glossy checkered floor and a
## pressure gauge -- the room grows with the factory.
static func kitchen(ci: CanvasItem, r: Rect2, kettles: int, level: int = 1) -> void:
	var inner := r.grow(-INSET)
	var fh := inner.size.y * 0.16
	var floor := Rect2(Vector2(inner.position.x, inner.end.y - fh), Vector2(inner.size.x, fh))
	var wall := Rect2(inner.position + Vector2(0, inner.size.y * 0.1), Vector2(inner.size.x * 0.52, 0))
	wall.size.y = floor.position.y - wall.position.y
	# (the tiles, the bricks and the steel are baked into one texture per size and level: drawn as
	# rects they were ~250 render objects every frame, +50% at the 44-machine factory)
	var paint := func(b: Object) -> void:
		# floor: a band of dark warm tiles at the bottom (the cooker stands on it)
		_r(b, floor, Color(0.9, 0.72, 0.56))
		var tw := fh * 1.1
		var n := int(inner.size.x / tw)
		for k in n:
			if level >= 3:
				# glossy checkered tiles: cream and a soft cherry, two rows, a shine on each cream one
				for row in 2:
					var tr := Rect2(Vector2(floor.position.x + k * tw, floor.position.y + 3 + row * (fh - 3) * 0.5), Vector2(tw, (fh - 3) * 0.5))
					var cream := (k + row) % 2 == 0
					_r(b, tr, Color(0.99, 0.93, 0.84) if cream else Color(0.93, 0.6, 0.56))
					if cream:
						_r(b, Rect2(tr.position + Vector2(tw * 0.15, 2), Vector2(tw * 0.3, 2)), Color(1, 1, 1, 0.6))
			elif k % 2 == 0:
				_r(b, Rect2(Vector2(floor.position.x + k * tw, floor.position.y + fh * 0.12), Vector2(tw, fh * 0.88)), Color(0.87, 0.67, 0.51))
		_r(b, Rect2(floor.position, Vector2(floor.size.x, 3)), Color(0.8, 0.58, 0.42))
		# brick wall behind the hand's kettle (left part; the machine places stand on the right)
		_r(b, wall, MORTAR)
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
					_r(b, Rect2(Vector2(x0, y + 1.5), Vector2(x1 - x0, bh - 3)), BRICK_DARK if (row * 7 + k * 3) % 5 == 0 else BRICK)
				x += bw
				k += 1
		if level >= 2:
			# a brushed-steel wainscot along the wall's foot: panels with a highlight and two rivets each
			var sh := wall.size.y * 0.24
			var steel := Rect2(Vector2(wall.position.x, wall.end.y - sh), Vector2(wall.size.x, sh))
			_r(b, steel, STEEL)
			var pw := maxf(40.0, steel.size.x / 4.0)
			var px := steel.position.x
			while px < steel.end.x - 4:
				var pr := Rect2(Vector2(px + 2, steel.position.y + 3), Vector2(minf(pw, steel.end.x - px) - 4, sh - 5))
				_r(b, pr, STEEL_HI)
				_r(b, Rect2(pr.position, Vector2(pr.size.x, maxf(2.0, sh * 0.12))), Color(1, 1, 1, 0.55))
				px += pw
			_r(b, Rect2(steel.position, Vector2(steel.size.x, 2)), STEEL.darkened(0.25))
		# a soft fade where the wall meets the room (no hard edge)
		for q in 4:
			var a := 0.22 * (1.0 - q / 4.0)
			_r(b, Rect2(Vector2(wall.end.x + q * 6, wall.position.y), Vector2(6, wall.size.y)), Color(MORTAR, a))
	_bake(ci, "kitchen|%s|%d" % [inner, level], inner, paint)
	if level >= 2:   # the wainscot's rivets (round: on the canvas, over the baked panels)
		var sh := wall.size.y * 0.24
		var pw := maxf(40.0, wall.size.x / 4.0)
		var px := wall.position.x
		while px < wall.end.x - 4:
			var prw := minf(pw, wall.end.x - px) - 4
			for rx: float in [0.12, 0.88]:
				ci.draw_circle(Vector2(px + 2 + prw * rx, wall.end.y - sh + 3 + (sh - 5) * 0.5 + sh * 0.12), maxf(1.6, sh * 0.05), STEEL.darkened(0.2))
			px += pw
	# copper pipe along the top with two joints and a valve wheel
	var py := inner.position.y + inner.size.y * 0.07
	var ph := maxf(6.0, inner.size.y * 0.03)
	_r(ci, Rect2(Vector2(inner.position.x + 60, py), Vector2(inner.size.x - 80, ph)), COPPER)
	_r(ci, Rect2(Vector2(inner.position.x + 60, py), Vector2(inner.size.x - 80, ph * 0.35)), COPPER_HI)
	for jx in [0.35, 0.7]:
		_r(ci, Rect2(Vector2(inner.position.x + inner.size.x * jx - ph * 0.6, py - ph * 0.3), Vector2(ph * 1.2, ph * 1.6)), COPPER.darkened(0.12))
	if level >= 2:
		# a second, thinner pipe under the first (steam for the new line), over the machine places
		var p2 := py + ph * 1.9
		_r(ci, Rect2(Vector2(inner.position.x + inner.size.x * 0.55, p2), Vector2(inner.size.x * 0.45 - 20, ph * 0.6)), STEEL.darkened(0.08))
		_r(ci, Rect2(Vector2(inner.position.x + inner.size.x * 0.55, p2), Vector2(inner.size.x * 0.45 - 20, ph * 0.2)), Color(1, 1, 1, 0.5))
	if level >= 3:
		# a pressure gauge on the copper pipe (on the brick side, clear of the machine places): a brass ring, a cream face, a red needle
		var gc := Vector2(inner.position.x + inner.size.x * 0.225, py + ph * 0.5)   # between the first two lamps
		var gr := maxf(9.0, inner.size.y * 0.04)
		ci.draw_circle(gc, gr, BRASS)
		ci.draw_circle(gc, gr * 0.78, Color(0.99, 0.97, 0.9))
		ci.draw_colored_polygon(PackedVector2Array([gc + Vector2(-gr * 0.08, gr * 0.08), gc + Vector2(gr * 0.5, -gr * 0.45), gc + Vector2(gr * 0.08, gr * 0.08)]), Color(0.86, 0.27, 0.24))
		ci.draw_circle(gc, gr * 0.12, LAMP_SHADE)
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


## The packing workshop. `level`: its lines bought (1-3): a second line brings a mint accent band
## and a second window, the third a wall clock and a potted plant.
static func packing(ci: CanvasItem, r: Rect2, level: int = 1) -> void:
	var inner := r.grow(-INSET)
	var fh := inner.size.y * 0.14
	var floor := Rect2(Vector2(inner.position.x, inner.end.y - fh), Vector2(inner.size.x, fh))
	# pale tiles over the upper wall (large tiles: few shapes)
	var wall := Rect2(inner.position + Vector2(70, 0), Vector2(inner.size.x - 140, floor.position.y - inner.position.y))
	var paint := func(b: Object) -> void:   # (baked: ~90 tiles as one render object)
		var ts := maxf(18.0, wall.size.y / 4.0)
		_r(b, wall, TILE_LINE)
		var cols := int(wall.size.x / ts)
		var rows := int(wall.size.y / ts)
		for row in rows:
			for col in cols:
				var band := level >= 2 and row == rows - 1
				_r(b, Rect2(wall.position + Vector2(col * ts + 1.5, row * ts + 1.5), Vector2(ts - 3, ts - 3)),
					(MINT if col % 2 == 0 else MINT.lightened(0.25)) if band else (TILE if (row + col) % 3 != 0 else TILE.darkened(0.025)))
	_bake(ci, "packing|%s|%d" % [wall, level], wall, paint)
	# daylight windows high on the wall, between the station and the shelf (a second with the second line)
	var wxs := [0.49] if level < 2 else [0.42, 0.56]
	for wx: float in wxs:
		var win := Rect2(Vector2(inner.position.x + inner.size.x * wx, inner.position.y + inner.size.y * 0.06), Vector2(inner.size.x * 0.1, inner.size.y * 0.3))
		_r(ci, win.grow(4), FRAME)
		_r(ci, win, DAY)
		_r(ci, Rect2(win.position, Vector2(win.size.x, win.size.y * 0.35)), DAY.lightened(0.25))
		_r(ci, Rect2(Vector2(win.get_center().x - 2, win.position.y), Vector2(4, win.size.y)), FRAME)
		ci.draw_colored_polygon(PackedVector2Array([win.position + Vector2(win.size.x * 0.15, win.size.y), win.end, win.end + Vector2(win.size.x * 0.6, floor.position.y - win.end.y), Vector2(win.position.x + win.size.x * 0.4, floor.position.y)]), Color(1, 1, 1, 0.16))
	if level >= 3:
		# a round wall clock right of the windows, and a potted plant at the wall's right end
		var cc := Vector2(inner.position.x + inner.size.x * 0.72, inner.position.y + inner.size.y * 0.2)
		var cr := maxf(10.0, inner.size.y * 0.09)
		ci.draw_circle(cc, cr, MINT.darkened(0.25))
		ci.draw_circle(cc, cr * 0.8, Color(1, 1, 0.97))
		_r(ci, Rect2(cc - Vector2(1.5, cr * 0.55), Vector2(3, cr * 0.55)), LAMP_SHADE)
		_r(ci, Rect2(cc - Vector2(0, 1.5), Vector2(cr * 0.4, 3)), LAMP_SHADE)
		var pc := Vector2(wall.end.x - 18, floor.position.y)
		var ps := maxf(14.0, inner.size.y * 0.13)
		for lf in 5:
			var a := -PI * 0.5 + (lf - 2) * 0.45
			ci.draw_colored_polygon(_ellipse(pc + Vector2(cos(a), sin(a)) * ps * 0.75 + Vector2(0, -ps * 0.6), ps * 0.22, ps * 0.42, 10), LEAF if lf % 2 == 0 else LEAF.lightened(0.18))
		ci.draw_colored_polygon(PackedVector2Array([pc + Vector2(-ps * 0.4, -ps * 0.6), pc + Vector2(ps * 0.4, -ps * 0.6), pc + Vector2(ps * 0.3, 0), pc + Vector2(-ps * 0.3, 0)]), Color(0.9, 0.55, 0.4))
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


## The shop. `look`: the sign's look (0-8) -- the street gets livelier with it. `level`: the shop's
## lines bought (1-2): the second brings a second row of string lights and a striped entrance mat.
static func shop(ci: CanvasItem, r: Rect2, look: int, level: int = 1) -> void:
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
	var paint := func(b: Object) -> void:   # (the panes, the sky and the houses baked: one render object)
		for p in panes:
			var w := Rect2(Vector2(x0 + p * (pw + gap), top), Vector2(pw, wy))
			_r(b, w.grow(5), FRAME)
			# a dusk sky in four bands, then the houses across the street
			for band in 4:
				_r(b, Rect2(Vector2(w.position.x, w.position.y + w.size.y * band / 4.0), Vector2(w.size.x, w.size.y / 4.0 + 1)), DUSK_TOP.lerp(DUSK_LOW, band / 3.0))
			var hx := w.position.x
			var hk := p * 3
			while hx < w.end.x:
				var hw := minf(w.size.x * (0.22 + 0.08 * ((hk * 7) % 3)), w.end.x - hx)
				var hh := w.size.y * (0.35 + 0.12 * ((hk * 5) % 3))
				var house := Rect2(Vector2(hx, w.end.y - hh), Vector2(hw, hh))
				_r(b, house, HOUSE.lerp(Color(0.6, 0.52, 0.7), ((hk * 3) % 2) * 0.5))
				# its windows: more lit as the sign grows (the street wakes up)
				var lit_share := clampf(0.2 + look * 0.1, 0.2, 1.0)
				for wi in 2:
					var wr := Rect2(house.position + Vector2(hw * (0.2 + 0.4 * wi), hh * 0.25), Vector2(hw * 0.22, hh * 0.18))
					if wr.end.x <= w.end.x:
						_r(b, wr, WIN_LIT if float((hk * 13 + wi * 7) % 10) / 10.0 < lit_share else Color(0.55, 0.5, 0.66))
				hx += hw + 2
				hk += 1
	_bake(ci, "shop|%s|%d" % [inner, look], Rect2(Vector2(x0 - 5, top - 5), Vector2(x1 - x0 + 10, wy + 10)), paint)
	for p in panes:
		var w := Rect2(Vector2(x0 + p * (pw + gap), top), Vector2(pw, wy))
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
		if level >= 2 and q < nb - 1:
			# the second row, lower and offset, in mint and gold
			var by2 := top + wy * 0.08 + sin((t + 0.5 / nb) * PI * 3.0) * 4.0
			ci.draw_circle(Vector2(bx + (x1 - x0 + 40) / (nb - 1) * 0.5, by2), 3.0, Color(0.6, 0.92, 0.82) if q % 2 == 0 else Color(1.0, 0.85, 0.45))
	# the wooden floor
	_r(ci, floor, WOOD)
	var bw := floor.size.x / 9.0
	for q in 9:
		if q % 2 == 0:
			_r(ci, Rect2(Vector2(floor.position.x + q * bw, floor.position.y + 3), Vector2(bw, floor.size.y - 3)), WOOD_DARK)
	_r(ci, Rect2(floor.position, Vector2(floor.size.x, 3)), WOOD_DARK.darkened(0.15))
	if level >= 2:
		# a striped entrance mat on the floor under the waiting space
		var mat := Rect2(Vector2(x0 + (x1 - x0) * 0.3, floor.position.y + fh * 0.25), Vector2((x1 - x0) * 0.4, fh * 0.55))
		_r(ci, mat, Color(0.88, 0.36, 0.34))
		var stripes := 8
		for q in stripes:
			if q % 2 == 0:
				_r(ci, Rect2(Vector2(mat.position.x + mat.size.x * q / stripes, mat.position.y + 3), Vector2(mat.size.x / stripes, mat.size.y - 6)), Color(0.99, 0.9, 0.78))


## Step 40: the packing floor's raw bin was a pale glass box floating on the tiles. It stands on
## steel legs down to the belt, with a funnel spout under it (behind the glass) ...
static func hopper_back(ci: CanvasItem, hop: Rect2, belt_y: float) -> void:
	var lw := maxf(4.0, hop.size.x * 0.07)
	for fx: float in [0.12, 0.88]:
		var x := hop.position.x + hop.size.x * fx - lw * 0.5
		_r(ci, Rect2(Vector2(x, hop.end.y - 6), Vector2(lw, belt_y - hop.end.y + 6)), STEEL.darkened(0.1))
		_r(ci, Rect2(Vector2(x, hop.end.y - 6), Vector2(lw * 0.35, belt_y - hop.end.y + 6)), Color(1, 1, 1, 0.45))
	var c := hop.get_center().x
	var sw := hop.size.x * 0.34
	ci.draw_colored_polygon(PackedVector2Array([Vector2(c - sw * 0.5, hop.end.y - 4), Vector2(c + sw * 0.5, hop.end.y - 4),
		Vector2(c + sw * 0.2, hop.end.y + hop.size.y * 0.12), Vector2(c - sw * 0.2, hop.end.y + hop.size.y * 0.12)]), STEEL)
	_r(ci, Rect2(Vector2(c - sw * 0.2, hop.end.y + hop.size.y * 0.12), Vector2(sw * 0.4, 3)), STEEL.darkened(0.25))


## ... and a brushed rim with two bolts along its top, so it reads as a metal-and-glass bin.
static func hopper_rim(ci: CanvasItem, hop: Rect2) -> void:
	var rh := maxf(6.0, hop.size.y * 0.09)
	var rim := Rect2(Vector2(hop.position.x - 3, hop.position.y - rh * 0.4), Vector2(hop.size.x + 6, rh))
	_r(ci, rim, STEEL.darkened(0.05))
	_r(ci, Rect2(rim.position, Vector2(rim.size.x, rh * 0.35)), STEEL_HI.lightened(0.3))
	for bx: float in [0.15, 0.85]:
		ci.draw_circle(Vector2(rim.position.x + rim.size.x * bx, rim.get_center().y + rh * 0.1), maxf(1.5, rh * 0.18), STEEL.darkened(0.3))


static func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
