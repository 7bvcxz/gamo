extends "res://variants/perfect/perfect_view.gd"

## The three-floor factory (Step 16, design/VISION.md 3, ART_DIRECTION.md):
##   TOP     the shop -- awning, sign, counter, the first customer waiting
##   MIDDLE  packing  -- the raw bin, the packer, the shelf
##   BOTTOM  the kitchen -- the hand's kettle and its ring (B), automation slots
## A glass tube on the right carries goods upward. The floors are drawn into a
## layer that redraws only when the layout or the selection changes, and the
## ring/effects layers redraw only while something moves (QUALITY_GATES R-01).
## Pressing cooks only on the bottom floor; a tap on a floor (or its badge, or
## keys 1-3) opens that floor's detail: what it is and its next form, locked
## until its step arrives. Landscape screens: floors on the left 60%, the cards
## and the detail on the right (design/mood/b_desktop.svg).

## Floors inside the scene rect, top to bottom (portrait): the kitchen is the
## tallest -- the hand's ring must be at least 40% of the width (G-03).
const BANDS := [Vector2(0.0, 0.25), Vector2(0.25, 0.47), Vector2(0.47, 1.0)]
const TOP := 0
const MID := 1
const LOW := 2
## The idle hint: for a newcomer from 8 s, then in 6 s bursts after 20 s idle
## (root AGENTS: help after 20 seconds of wandering, not forever).
const HINT_BURST_MS := 6000
const HINT_IDLE_MS := 20000

var selected := -1               ## the floor whose detail is open, -1 none
var floor_layer := Node2D.new()
var customer_node := Node2D.new()
var detail_layer := Node2D.new()   ## above everything: the open floor's detail
## Step 18: the moving goods and people, keyed by the model's ids.
const Actor := preload("res://variants/factory/actor.gd")
var actor_layer := Node2D.new()
var customers := {}       ## customer id -> actor
var cargo := {}           ## lot or pack id -> actor
var leaving: Array = []   ## customers walking out
## What the pictures did, for the tests (G-13): {id, kind, what, t}.
var cargo_log: Array = []
var _cooking := false            ## this press started on the bottom floor
var _floors_key := ""


func setup(p_rules: PopRules) -> void:
	super(p_rules)
	selected = -1
	# A new run (restart, a new factory): no journey of the old one may linger.
	for a in actor_layer.get_children():
		a.queue_free()
	customers.clear()
	cargo.clear()
	leaving.clear()
	cargo_log.clear()
	if floor_layer.get_parent() == null:
		floor_layer.name = "Floors"
		add_child(floor_layer)
		move_child(floor_layer, 0)
		floor_layer.draw.connect(func() -> void: _draw_floors(floor_layer))
		customer_node.name = "Customer"
		add_child(customer_node)
		move_child(customer_node, 1)
		customer_node.draw.connect(func() -> void: _draw_customer(customer_node))
		actor_layer.name = "Actors"
		add_child(actor_layer)
		move_child(actor_layer, 2)
		detail_layer.name = "Detail"
		add_child(detail_layer)
		detail_layer.draw.connect(func() -> void:
			if selected >= 0:
				_draw_detail(detail_layer, selected, detail_rect()))
	_floors_key = ""
	_wide_default = true


var _wide_default := true


# -- geometry -------------------------------------------------------------

func is_wide() -> bool:
	return size.x > size.y * 1.15


func scene_rect() -> Rect2:
	if is_wide():
		return Rect2(Vector2.ZERO, Vector2(size.x * 0.6, size.y))
	return Rect2(Vector2.ZERO, size)


func floor_rect(i: int) -> Rect2:
	var sr := scene_rect()
	var b: Vector2 = BANDS[i]
	return Rect2(Vector2(sr.position.x + 16, sr.position.y + sr.size.y * b.x + 6), Vector2(sr.size.x - 32, sr.size.y * (b.y - b.x) - 12))


func badge_rect(i: int) -> Rect2:
	var r := floor_rect(i)
	return Rect2(r.position + Vector2(10, 10), Vector2(64, 64))


func news_rect() -> Rect2:
	var r := floor_rect(TOP)
	return Rect2(Vector2(r.end.x - 74, r.position.y + 10), Vector2(64, 64))


## The open floor's detail: inside that floor on a portrait screen, in the right
## column under the card on a landscape one.
func detail_rect() -> Rect2:
	if selected < 0:
		return Rect2()
	if is_wide():
		var x := size.x * 0.62 + 16
		return Rect2(Vector2(x, 210), Vector2(size.x - x - 16, size.y - 230))
	var r := floor_rect(selected)
	if selected == LOW:
		# Beside the ring, never over it: the kitchen's free right side.
		var x := machine_centre().x + ring_radius() + machine_size() * 0.09
		return Rect2(Vector2(x, r.position.y + 12), Vector2(r.end.x - 12 - x, r.size.y - 24))
	var w := minf(r.size.x * 0.62, 420.0)
	return Rect2(Vector2(r.position.x + (r.size.x - w) * 0.5, r.position.y + 12), Vector2(w, r.size.y - 24))


func tube_rect() -> Rect2:
	var top := floor_rect(TOP)
	var low := floor_rect(LOW)
	var x := scene_rect().end.x - 44
	return Rect2(Vector2(x, top.end.y - top.size.y * 0.45), Vector2(30, low.position.y + low.size.y * 0.35 - (top.end.y - top.size.y * 0.45)))


func machine_size() -> float:
	var low := floor_rect(LOW)
	return minf(low.size.y * 0.64, low.size.x * 0.52)


## The ring is centred in the kitchen (a little below the middle, room above
## for the popcorn to fly): the machine's base is placed from that centre.
func machine_base() -> Vector2:
	var low := floor_rect(LOW)
	var centre_y := low.position.y + low.size.y * 0.53
	return Vector2(low.position.x + low.size.x * 0.43, centre_y + PopMachineArt.height_at(rules.level if rules else 0, machine_size()) * 0.5)


func extra_rects() -> Dictionary:
	var out := {"floor_top": floor_rect(TOP), "floor_mid": floor_rect(MID), "floor_low": floor_rect(LOW),
		"badge_top": badge_rect(TOP), "badge_mid": badge_rect(MID), "badge_low": badge_rect(LOW),
		"news": news_rect(), "tube": tube_rect()}
	var c := machine_centre()
	var r := ring_radius() + machine_size() * 0.045
	out["ring"] = Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
	if selected >= 0:
		out["detail"] = detail_rect()
	return out


func _floor_at(p: Vector2) -> int:
	for i in 3:
		if floor_rect(i).has_point(p):
			return i
	return -1


# -- input --------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		var f := _floor_at(mb.position)
		for i in 3:
			if badge_rect(i).has_point(mb.position):
				accept_event()
				toggle_floor(i)
				return
		if f == LOW and not detail_rect().has_point(mb.position):
			_cooking = true
			super(event)
			return
		accept_event()
		if f >= 0:
			toggle_floor(f)
		elif selected >= 0 and not detail_rect().has_point(mb.position):
			toggle_floor(-1)
		return
	if _cooking:
		_cooking = false
		super(event)
	else:
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1:
			toggle_floor(LOW)
		KEY_2:
			toggle_floor(MID)
		KEY_3:
			toggle_floor(TOP)
		_:
			return
	get_viewport().set_input_as_handled()


## Opens a floor's detail, or closes it if it is already open (-1 closes).
func toggle_floor(i: int) -> void:
	selected = -1 if i == selected or i < 0 else i
	_floors_key = ""
	_sound("clink", 1.2 if selected >= 0 else 0.9, -12.0)


# -- frame-by-frame -----------------------------------------------------------

func _hint_visible() -> bool:
	if rules == null or bool(_r()["heating"]):
		return false
	var idle := now_ms - maxi(last_input_ms, 0)
	if last_input_ms < 0:
		return idle >= HINT_RING_MS
	if idle < HINT_IDLE_MS:
		return false
	return fmod(float(idle - HINT_IDLE_MS), float(HINT_IDLE_MS)) < float(HINT_BURST_MS)


func _needs_redraw() -> bool:
	if rules == null:
		return false
	return bool(_r()["heating"]) or fx.alive > 0 or not _gains.is_empty() or _flash > 0.0 or _mark_age < MARK_S \
		or _hint_visible() or _squash != 0.0 or _jump > 0.0 or _redraw_once \
		or not _chain.is_empty() or _fountain > 0.0 or _meter_flash > 0.0 or _burst_glow > 0.0


var _redraw_once := true


func _process(delta: float) -> void:
	super(delta)
	_redraw_once = false
	# On a landscape screen the right column shows the kitchen's detail until a floor is chosen.
	if _wide_default and is_wide() and size.x > 0.0:
		_wide_default = false
		if selected < 0:
			selected = LOW
	var key := "%s|%d|%d|%s" % [size, selected, rules.level if rules else 0, _inventory_key()]
	if key != _floors_key:
		_floors_key = key
		floor_layer.queue_redraw()
		customer_node.queue_redraw()
		detail_layer.queue_redraw()
		_redraw_once = true
	_process_glass()
	_step_actors(delta)


## Step 19: the heat knob at the kettle's right foot turns with the heat (and
## springs back on release) -- the hand's action has a part that moves with it.
func _draw_over(ci: CanvasItem, base: Vector2, size_px: float) -> void:
	super(ci, base, size_px)
	var st := _r()
	var heat := float(st["heat_ms"]) if bool(st["heating"]) else 0.0
	var burn := float((st["window"] as Array)[2])
	var k := clampf(heat / maxf(1.0, burn), 0.0, 1.0)
	var c := base + Vector2(size_px * 0.42, -size_px * 0.12)
	var r := size_px * 0.06
	ci.draw_circle(c, r + 3.0, PopTokens.MACHINE_LINE)
	ci.draw_circle(c, r, PopTokens.STEEL)
	var a := -PI * 0.75 + k * PI * 1.5
	ci.draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.85, PopTokens.MACHINE_DEEP, r * 0.35)
	var col := PopTokens.SKY if k < 0.57 else (PopPalette.GOLD if k < 0.8 else PopTokens.WARN)
	ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.85, r * 0.22, col if bool(st["heating"]) else PopTokens.STEEL_DEEP)


func _draw_hints(ci: CanvasItem, base: Vector2, size_px: float) -> void:
	if _hint_visible():
		_draw_hint_gesture(ci, size_px, last_input_ms < 0 and now_ms >= HINT_HAND_MS)


func on_events(events: Array[Dictionary]) -> void:
	if not events.is_empty():   # (called every frame, mostly with nothing)
		_redraw_once = true
	var rest: Array[Dictionary] = []
	for e: Dictionary in events:
		if String(e["type"]) == "earn":
			# A sale: the coin and the +N at the counter, where the pack met the customer.
			var at := _counter_point()
			fx.coin(at, machine_size() / 900.0)
			_gain(int(e["data"].get("amount", 0)))
			_gains[-1]["at"] = at
			_sound("coin", 1.0, -6.0)
		else:
			rest.append(e)
	_flow_events(events)
	super(rest)


# -- the floors (drawn once per change) ----------------------------------------

func _draw_floors(ci: CanvasItem) -> void:
	var cols := [PopTokens.FLOOR_TOP, PopTokens.FLOOR_MID, PopTokens.FLOOR_LOW]
	for i in 3:
		PopFactoryArt.floor_panel(ci, floor_rect(i), cols[i], i == selected)
	_draw_shop(ci, floor_rect(TOP))
	_draw_packing(ci, floor_rect(MID))
	_draw_kitchen(ci, floor_rect(LOW))
	var tube := tube_rect()
	PopFactoryArt.glass(ci, tube, tube.size.x * 0.5)
	for i in 3:
		_draw_badge(ci, i)
	_draw_news(ci)


func _draw_shop(ci: CanvasItem, r: Rect2) -> void:
	PopFactoryArt.awning(ci, Rect2(r.position + Vector2(90, 10), Vector2(r.size.x - 180, r.size.y * 0.12)), 10)
	# The sign: a chalkboard with a popcorn cup (level 1 of the sign's forms).
	var sign := Rect2(Vector2(r.position.x + r.size.x * 0.08, r.position.y + r.size.y * 0.3), Vector2(r.size.y * 0.42, r.size.y * 0.32))
	PopFactoryArt.shadow(ci, sign, PopTokens.R_PART)
	PopMachineArt._round_rect(ci, sign, PopTokens.R_PART, Color(0.24, 0.27, 0.25))
	PopFactoryArt.bag(ci, sign.get_center() + Vector2(0, sign.size.y * 0.3), sign.size.y * 0.42)
	var counter := counter_rect()
	PopFactoryArt.machine(ci, counter)


func counter_rect() -> Rect2:
	var r := floor_rect(TOP)
	return Rect2(Vector2(r.position.x + r.size.x * 0.06, r.end.y - r.size.y * 0.3), Vector2(r.size.x * 0.8, r.size.y * 0.14))


const CUSTOMER_COLOURS := [Color(0.435, 0.714, 0.91), Color(0.561, 0.878, 0.769), Color(1.0, 0.7, 0.42), Color(0.78, 0.6, 0.88), Color(0.95, 0.55, 0.6)]
const SKIN := [Color(0.96, 0.82, 0.68), Color(0.85, 0.63, 0.48), Color(0.97, 0.88, 0.78), Color(0.72, 0.54, 0.4), Color(0.9, 0.72, 0.58)]


## The queue at the counter, head first from the left (only real customers --
## the model's queue; Step 17), the one being served at the hand-over spot.
func _draw_customer(_ci: CanvasItem) -> void:
	return   # Step 18: customers are actors (they walk); kept for the layer order.


func _draw_customer_static(ci: CanvasItem) -> void:
	if rules == null:
		return
	var c := counter_rect()
	var head := clampf(floor_rect(TOP).size.y * 0.1, 14.0, 26.0)
	var gap := head * 2.7
	var x0 := c.position.x + c.size.x * 0.42
	var queue: Array = rules.get("queue")
	if not (rules.get("serving") as Dictionary).is_empty():
		var sv: Dictionary = rules.get("serving")
		var id := int(sv["customer"]["id"])
		PopFactoryArt.customer(ci, Vector2(c.position.x + c.size.x * 0.28, c.position.y + 2), head, CUSTOMER_COLOURS[id % 5], SKIN[id % 5])
		PopFactoryArt.bag(ci, Vector2(c.position.x + c.size.x * 0.2, c.position.y + 2), head * 1.1)
	for i in queue.size():
		var id := int(queue[i]["id"])
		PopFactoryArt.customer(ci, Vector2(x0 + gap * i, c.position.y + 2), head, CUSTOMER_COLOURS[id % 5], SKIN[id % 5])


func _draw_packing(ci: CanvasItem, r: Rect2) -> void:
	var belt := Rect2(Vector2(r.position.x + 30, r.end.y - r.size.y * 0.2), Vector2(r.size.x - 110, r.size.y * 0.08))
	PopFactoryArt.steel(ci, belt, belt.size.y * 0.5)
	var hs := r.size.y * 0.46
	var hop := Rect2(Vector2(r.position.x + r.size.x * 0.14, r.position.y + r.size.y * 0.16), Vector2(hs * 0.9, hs))
	PopFactoryArt.glass(ci, hop, PopTokens.R_PART)
	# The raw bin's real portions: one puff per portion, piled from the bottom.
	var portions := int(rules.bin_portions()) if rules else 0
	var cap := int(rules.state()["bin_cap"]) if rules else 1
	var per_row := 4
	var pr := hop.size.x / float(per_row + 1) * 0.55
	for k in mini(portions, cap):
		var col := k % per_row
		var row := k / per_row
		PopFactoryArt.popcorn(ci, Vector2(hop.position.x + hop.size.x * (0.2 + 0.2 * col) + (row % 2) * pr * 0.4, hop.end.y - pr * 1.1 - row * pr * 1.2), pr)
	var pk := Rect2(Vector2(r.position.x + r.size.x * 0.38, r.position.y + r.size.y * 0.14), Vector2(r.size.y * 0.8, r.size.y * 0.58))
	PopFactoryArt.machine(ci, pk)
	ci.draw_circle(pk.get_center(), pk.size.y * 0.28, Color(1, 1, 1, 0.7))
	if rules and not (rules.get("packing") as Dictionary).is_empty():
		PopFactoryArt.bag(ci, Vector2(pk.get_center().x, pk.end.y + 4), r.size.y * 0.15)   # the pack being filled
	# The shelf: one bag per real sealed pack, empty places dashed.
	var shelf_n := (int(rules.state()["shelf"]) - _bags_flying_to_shelf()) if rules else 0
	var shelf_cap := int(rules.state()["shelf_cap"]) if rules else 0
	# Two rows of places, right of the packer and left of the tube.
	var per := maxi(1, (shelf_cap + 1) / 2)
	var span := tube_rect().position.x - 16 - (r.position.x + r.size.x * 0.62)
	var w := minf(r.size.y * 0.14, span / (float(per) * 1.2))
	for k in shelf_cap:
		var foot := Vector2(r.position.x + r.size.x * 0.62 + (k % per) * w * 1.2 + w * 0.6, belt.position.y - (k / per) * w * 1.65)
		if k < shelf_n:
			PopFactoryArt.bag(ci, foot, w)
		else:
			PopMachineArt._round_rect(ci, Rect2(foot - Vector2(w * 0.5, w * 1.5), Vector2(w, w * 1.5)), 4, Color(1, 1, 1, 0.35))


func _draw_kitchen(ci: CanvasItem, r: Rect2) -> void:
	var sh := r.size.y * 0.26
	for j in 2:
		var slot := Rect2(Vector2(r.end.x - sh * 0.82 - 70, r.position.y + r.size.y * 0.12 + j * sh * 1.15), Vector2(sh * 0.82, sh))
		PopFactoryArt.dashed_slot(ci, slot)


func _draw_badge(ci: CanvasItem, i: int) -> void:
	var b := badge_rect(i)
	var c := b.get_center()
	var on := i == selected
	ci.draw_circle(c, b.size.x * 0.5, PopPalette.GOLD if on else Color.WHITE)
	ci.draw_arc(c, b.size.x * 0.5, 0, TAU, 32, PopPalette.INK, 3.0)
	var s := b.size.x * 0.22
	match i:
		TOP:   # a shop front: awning and a door
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.9), Vector2(s * 2.0, s * 0.6)), PopTokens.MACHINE)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.9, -s * 0.3), Vector2(s * 1.8, s * 1.2)), PopPalette.INK, false, 3.0)
		MID:   # a bag
			PopFactoryArt.bag(ci, c + Vector2(0, s * 1.0), s * 1.3)
		LOW:   # a kettle
			PopMachineArt._round_rect(ci, Rect2(c + Vector2(-s, -s * 0.9), Vector2(s * 2.0, s * 0.5)), 4, PopTokens.MACHINE)
			PopMachineArt._round_rect(ci, Rect2(c + Vector2(-s * 0.85, -s * 0.4), Vector2(s * 1.7, s * 0.9)), 4, Color(0.9, 0.96, 1.0))
			PopMachineArt._round_rect(ci, Rect2(c + Vector2(-s, s * 0.5), Vector2(s * 2.0, s * 0.5)), 4, PopTokens.MACHINE)


## The news paper, top right of the shop: reserved (Step 37 fills it), grey until then.
func _draw_news(ci: CanvasItem) -> void:
	var n := news_rect()
	var c := n.get_center()
	ci.draw_circle(c, n.size.x * 0.5, Color(1, 1, 1, 0.7))
	ci.draw_arc(c, n.size.x * 0.5, 0, TAU, 32, Color(PopPalette.INK, 0.4), 3.0)
	var p := Rect2(c - Vector2(16, 12), Vector2(32, 24))
	ci.draw_rect(p, Color(1, 1, 1))
	ci.draw_rect(p, Color(PopPalette.INK, 0.45), false, 3.0)
	ci.draw_line(p.position + Vector2(6, 8), p.position + Vector2(26, 8), Color(PopPalette.INK, 0.45), 3.0)
	ci.draw_line(p.position + Vector2(6, 15), p.position + Vector2(20, 15), Color(PopPalette.INK, 0.45), 3.0)


## A floor's detail: its form now, an arrow, and its next form dimmed with a lock.
func _draw_detail(ci: CanvasItem, i: int, d: Rect2) -> void:
	PopFactoryArt.shadow(ci, d, PopTokens.R_BUTTON)
	PopMachineArt._round_rect(ci, d, PopTokens.R_BUTTON, Color(1, 1, 1, 0.96))
	var pts := PopMachineArt.round_rect_points(d, PopTokens.R_BUTTON)
	pts.append(pts[0])
	ci.draw_polyline(pts, PopPalette.GOLD, 5.0, true)
	var vertical := d.size.y > d.size.x * 1.15
	var h: float
	var a: Vector2
	var b: Vector2
	if vertical:   # now above, next below, the arrow pointing down (the kitchen's numbers on top)
		var top := 0.36 if i == LOW else 0.0
		h = minf(d.size.x * 0.55, d.size.y * (0.3 - top * 0.3))
		a = Vector2(d.get_center().x, d.position.y + d.size.y * (0.42 + top * 0.5))
		b = Vector2(d.get_center().x, d.position.y + d.size.y * 0.94)
	else:
		h = minf(d.size.y * 0.7, d.size.x * 0.32)
		a = Vector2(d.position.x + d.size.x * 0.25, d.get_center().y + h * 0.4)
		b = Vector2(d.position.x + d.size.x * 0.75, d.get_center().y + h * 0.4)
	_form(ci, i, 0, a, h, false)
	_form(ci, i, 1, b, h * 1.1, true)
	var m := (a + b) * 0.5 + (Vector2(0, -h * 0.35) if vertical else Vector2(0, -h * 0.4))
	var dir := Vector2(0, 1) if vertical else Vector2(1, 0)
	var side := Vector2(-dir.y, dir.x)
	ci.draw_line(m - dir * h * 0.18, m + dir * h * 0.14, PopPalette.INK, 6.0)
	ci.draw_colored_polygon(PackedVector2Array([m + dir * h * 0.22, m + dir * h * 0.08 - side * h * 0.1, m + dir * h * 0.08 + side * h * 0.1]), PopPalette.INK)
	# The lock on the next form -- except the kitchen's, which can be bought now.
	if i != LOW:
		var lk := b + Vector2(0, -h * 0.55)
		PopMachineArt._round_rect(ci, Rect2(lk - Vector2(14, 8), Vector2(28, 22)), 4, PopPalette.INK)
		ci.draw_arc(lk + Vector2(0, -8), 9, PI, TAU, 12, PopPalette.INK, 4.0)
	else:
		_draw_kettle_numbers(ci, d)


## Step 19: what the next kettle level changes, now -> next, by icon and number
## (no words): popcorn per perfect pop, the gold's width, the cooling time.
## A row that improves shows its next number in green with a chevron.
func _draw_kettle_numbers(ci: CanvasItem, d: Rect2) -> void:
	if rules == null or not rules.has_method("kettle_stats"):
		return
	var now: Dictionary = rules.kettle_stats(rules.level)
	var nxt: Dictionary = rules.kettle_stats(rules.level + 1)
	var font := ThemeDB.fallback_font
	var fs := int(clampf(d.size.x * 0.1, 18.0, 30.0))
	var rows := [["portions", now["portions"], nxt["portions"], true], ["gold_ms", now["gold_ms"], nxt["gold_ms"], true],
		["recovery_ms", now["recovery_ms"], nxt["recovery_ms"], false]]
	var y := d.position.y + fs * 1.3
	for row: Array in rows:
		var ic := Vector2(d.position.x + fs * 1.1, y - fs * 0.35)
		match String(row[0]):
			"portions":
				PopFactoryArt.popcorn(ci, ic, fs * 0.42)
			"gold_ms":
				ci.draw_arc(ic, fs * 0.42, -PI * 0.8, -PI * 0.2, 12, PopPalette.GOLD, fs * 0.22)
			"recovery_ms":
				ci.draw_arc(ic, fs * 0.42, -PI / 2, PI, 14, Color(0.35, 0.33, 0.33, 0.9), fs * 0.16)
		var better: bool = (int(row[2]) > int(row[1])) if bool(row[3]) else (int(row[2]) < int(row[1]))
		var x := d.position.x + fs * 2.0
		ci.draw_string(font, Vector2(x, y), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopPalette.INK)
		var x2 := x + fs * 2.4
		ci.draw_string(font, Vector2(x2, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PopPalette.INK, 0.5))
		ci.draw_string(font, Vector2(x2 + fs * 0.9, y), str(row[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopTokens.OK if better else Color(PopPalette.INK, 0.45))
		y += fs * 1.35


## Form `k` (0 = now, 1 = next) of a floor's station, bottom-centre at `foot`.
func _form(ci: CanvasItem, floor_i: int, k: int, foot: Vector2, h: float, dim: bool) -> void:
	match floor_i:
		LOW:
			var lv := mini((rules.level if rules else 0) + k, 14)
			PopMachineArt.draw(ci, foot, h * 1.3, lv)
			if dim:
				PopMachineArt._round_rect(ci, Rect2(foot - Vector2(h * 0.6, h * 1.15), Vector2(h * 1.2, h * 1.15)), 8, Color(1, 1, 1, 0.55))
		MID:
			if k == 0:   # a scoop and a paper bag
				PopFactoryArt.machine(ci, Rect2(foot - Vector2(h * 0.35, h * 0.7), Vector2(h * 0.7, h * 0.7)), dim)
				PopFactoryArt.bag(ci, foot + Vector2(h * 0.5, 0), h * 0.28)
			else:        # a filling head over a cup
				PopFactoryArt.machine(ci, Rect2(foot - Vector2(h * 0.4, h), Vector2(h * 0.8, h * 0.55)), dim)
				ci.draw_circle(foot - Vector2(0, h * 0.72), h * 0.18, Color(1, 1, 1, 0.7))
				PopFactoryArt.bag(ci, foot, h * 0.3, PopTokens.MACHINE if not dim else PopPalette.DISABLED)
		TOP:
			if k == 0:   # the chalkboard
				PopMachineArt._round_rect(ci, Rect2(foot - Vector2(h * 0.45, h * 0.7), Vector2(h * 0.9, h * 0.6)), PopTokens.R_PART, Color(0.24, 0.27, 0.25))
			else:        # a lit marquee
				var m := Rect2(foot - Vector2(h * 0.5, h * 0.8), Vector2(h, h * 0.62))
				PopMachineArt._round_rect(ci, m, PopTokens.R_PART, Color(0.35, 0.1, 0.16) if not dim else PopPalette.DISABLED)
				for q in 6:
					ci.draw_circle(Vector2(m.position.x + m.size.x * (0.1 + 0.16 * q), m.position.y + 8), 5, PopTokens.BRASS if not dim else Color(1, 1, 1, 0.5))


# -- Step 17: the truth of the model on screen --------------------------------

## What the static floors show: changes only when the stock does (so they
## redraw only then, R-01).
func _inventory_key() -> String:
	if rules == null:
		return ""
	return "%d|%d|%d|%d|%s|%s" % [rules.bin_portions(), (rules.get("shelf") as Array).size(), (rules.get("queue") as Array).size(),
		(rules.get("lift") as Array).size(), not (rules.get("packing") as Dictionary).is_empty(), not (rules.get("serving") as Dictionary).is_empty()]


## The kettle's glass shows its waiting lot (the backpressure is visible).
func _process_glass() -> void:
	if rules == null:
		return
	var g: Dictionary = rules.get("glass")
	var fill := 0.15
	if not g.is_empty():
		fill = 0.25 + 0.65 * clampf(float(g["portions"]) / maxf(1.0, float(rules.kettle_capacity())), 0.0, 1.0)
	machine_node.set_look(rules.level, machine_size(), fill)


## A press while the glass is full: the kettle shakes and puffs (the model refuses it).
func _press() -> void:
	if rules != null and not (rules.get("glass") as Dictionary).is_empty() and not bool(_r()["heating"]):
		squash(0.0, 6.0)
		_sound("thud", 1.4, -12.0)
		_redraw_once = true
		if not reduced_motion:
			fx.smoke(machine_top(), 3, machine_size() / 900.0, rng)
	super()


## Money appears at the counter, when the pack reaches the customer -- not at the kettle.
func _counter_point() -> Vector2:
	var c := counter_rect()
	return Vector2(c.position.x + c.size.x * 0.28, c.position.y - 40)


# -- Step 18: the journeys ----------------------------------------------------

func _bags_flying_to_shelf() -> int:
	var n := 0
	for a in cargo.values():
		if a.kind == Actor.BAG and a.get_meta("to", "") == "shelf":
			n += 1
	return n


func _new_actor(kind: String, id: int) -> Node2D:
	var a: Node2D = Actor.new()
	a.kind = kind
	a.model_id = id
	actor_layer.add_child(a)
	return a


func _log(id: int, kind: String, what: String) -> void:
	cargo_log.append({"id": id, "kind": kind, "what": what, "t": now_ms})
	if cargo_log.size() > 400:
		cargo_log.pop_front()


func _head_px() -> float:
	return clampf(floor_rect(TOP).size.y * 0.1, 14.0, 26.0)


func _queue_spot(i: int) -> Vector2:
	var c := counter_rect()
	return Vector2(c.position.x + c.size.x * 0.42 + _head_px() * 2.7 * i, c.position.y + 2)


func _handoff_spot() -> Vector2:
	var c := counter_rect()
	return Vector2(c.position.x + c.size.x * 0.26, c.position.y + 2)


func _door() -> Vector2:
	var r := floor_rect(TOP)
	return Vector2(r.end.x + _head_px() * 2.0, counter_rect().position.y + 2)


func _shelf_spot(k: int) -> Vector2:
	var r := floor_rect(MID)
	var shelf_cap := int(rules.state()["shelf_cap"])
	var per := maxi(1, (shelf_cap + 1) / 2)
	var span := tube_rect().position.x - 16 - (r.position.x + r.size.x * 0.62)
	var w := minf(r.size.y * 0.14, span / (float(per) * 1.2))
	var belt_y := r.end.y - r.size.y * 0.2
	return Vector2(r.position.x + r.size.x * 0.62 + (k % per) * w * 1.2 + w * 0.6, belt_y - (k / per) * w * 1.65)


func _bag_px() -> float:
	return floor_rect(MID).size.y * 0.16


func _bin_top() -> Vector2:
	var r := floor_rect(MID)
	var hs := r.size.y * 0.46
	return Vector2(r.position.x + r.size.x * 0.14 + hs * 0.45, r.position.y + r.size.y * 0.16 + hs * 0.3)


func _packer_out() -> Vector2:
	var r := floor_rect(MID)
	return Vector2(r.position.x + r.size.x * 0.38 + r.size.y * 0.4, r.position.y + r.size.y * 0.14 + r.size.y * 0.58 + 4)


func _seconds(key: String) -> float:
	var t: Dictionary = rules.economy.table("factory")
	match key:
		"lift":
			return float(t["lift_ms"]) / 1000.0
		"serve":
			return float(t["service_ms"]) / 1000.0
	return 0.45


func _flow_events(events: Array[Dictionary]) -> void:
	var tube_x := tube_rect().get_center().x
	for e: Dictionary in events:
		var d: Dictionary = e["data"]
		match String(e["type"]):
			"lot_lifted":
				# Up the glass tube from the kettle to the raw bin, in the lift's time.
				var a := _new_actor(Actor.LOT, int(d["lot"]))
				a.size_px = _bag_px() * 0.85
				var top := machine_top()
				var bin := _bin_top()
				a.start(PackedVector2Array([top, Vector2(tube_x, top.y), Vector2(tube_x, bin.y - 40), bin]), _seconds("lift"), reduced_motion)
				cargo[int(d["lot"])] = a
				_log(int(d["lot"]), "lot", "start")
			"lot_binned":
				_end_cargo(int(d["lot"]), "lot")
			"pack_shelved":
				var b := _new_actor(Actor.BAG, int(d["pack"]))
				b.size_px = _bag_px()
				b.set_meta("to", "shelf")
				var k := maxi(0, int(rules.state()["shelf"]) - 1)
				b.start(PackedVector2Array([_packer_out(), _shelf_spot(k)]), 0.45, reduced_motion)
				b.set_meta("end_on_arrival", true)
				cargo[int(d["pack"])] = b
				_log(int(d["pack"]), "bag", "start")
			"serve_started":
				# The pack leaves the shelf, rides the tube up to the counter; the customer steps to the hand-over spot.
				var pid := int(d["pack"])
				var from := _shelf_spot(int(rules.state()["shelf"]))
				var bag: Node2D
				var redirected := cargo.has(pid)
				if redirected:
					# Still flying to the shelf when a customer took it: the same bag
					# turns towards the counter from where it is (no second bag, no jump).
					bag = cargo[pid]
					from = bag.position
					bag.remove_meta("end_on_arrival")
				else:
					bag = _new_actor(Actor.BAG, pid)
					bag.size_px = _bag_px()
				bag.set_meta("to", "counter")
				var hand := _handoff_spot() - Vector2(_head_px() * 1.4, _head_px() * 0.8)
				bag.start(PackedVector2Array([from, Vector2(tube_x, from.y), Vector2(tube_x, hand.y), hand]), _seconds("serve"), reduced_motion)
				cargo[pid] = bag
				_log(pid, "bag", "redirect" if redirected else "serve")
				var cid := int(d["customer"])
				if customers.has(cid):
					customers[cid].walk_to(_handoff_spot())
			"sale":
				var pid := int(d["pack"])
				_end_cargo(pid, "bag")
				var cid := int(d["customer"])
				if customers.has(cid):
					var c: Node2D = customers[cid]
					c.carrying = true
					c.queue_redraw()
					c.walk_to(_door())
					leaving.append(c)
					customers.erase(cid)
				_log(pid, "bag", "sold")
			"customer_left":
				var cid := int(d["customer"])
				if customers.has(cid):
					var c: Node2D = customers[cid]
					c.walk_to(_door())
					leaving.append(c)
					customers.erase(cid)


func _end_cargo(id: int, kind: String) -> void:
	if cargo.has(id):
		var a: Node2D = cargo[id]
		cargo.erase(id)
		a.queue_free()
		_log(id, kind, "end")


## Customers follow the model: every id in the queue (and the one being served)
## has an actor; a new one walks in from the door; each walks to its place.
func _reconcile_customers() -> void:
	if rules == null:
		return
	var queue: Array = rules.get("queue")
	var want := {}
	for i in queue.size():
		var id := int(queue[i]["id"])
		want[id] = i
		if not customers.has(id):
			var a := _new_actor(Actor.CUSTOMER, id)
			a.size_px = _head_px()
			a.body = CUSTOMER_COLOURS[id % 5]
			a.skin = SKIN[id % 5]
			a.position = _door() if now_ms > 500 else _queue_spot(i)
			customers[id] = a
		customers[id].walk_to(_queue_spot(i))
	var sv: Dictionary = rules.get("serving")
	if not sv.is_empty():
		want[int(sv["customer"]["id"])] = -1


func _step_actors(delta: float) -> void:
	_reconcile_customers()
	for a in cargo.values():
		a.step(delta)
	for id in cargo.keys():
		var a: Node2D = cargo[id]
		if a.done and a.has_meta("end_on_arrival"):
			_end_cargo(int(id), "bag")
			_redraw_once = true
			floor_layer.queue_redraw()   # the bag lands on the static shelf
	for a in customers.values():
		a.step(delta)
	var still: Array = []
	for c: Node2D in leaving:
		c.step(delta)
		if c.position.distance_to(_door()) < 2.0:
			c.queue_free()
		else:
			still.append(c)
	leaving = still


## For the tests: the journeys in flight and the record of them.
func debug_state() -> Dictionary:
	var flying := []
	for id in cargo.keys():
		var a: Node2D = cargo[id]
		flying.append({"id": int(id), "kind": a.kind, "to": a.get_meta("to", ""), "x": a.position.x, "y": a.position.y})
	return {"flying": flying, "customers": customers.size(), "leaving": leaving.size(), "log": cargo_log.duplicate()}

