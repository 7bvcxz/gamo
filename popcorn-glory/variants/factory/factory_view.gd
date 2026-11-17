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
## Step 26: a chosen machine (by id) or an empty place ({floor, k}); the card and the detail follow it.
var sel_machine := -1
var sel_slot := {}
const FLOOR_NAME := ["shop", "packing", "kitchen"]
const MACHINE_OF := {"kitchen": "cooker", "packing": "bagger", "shop": "kiosk"}
const FLOOR_INDEX := {"shop": 0, "packing": 1, "kitchen": 2}
const FLOOR_OF_TYPE := {"cooker": "kitchen", "bagger": "packing", "kiosk": "shop"}
var floor_layer := Node2D.new()
## Step 33: what changes with the goods (the shop's sign and counter, the bin, the
## station, the shelf) and each machine are their own nodes -- forty machines that
## change state every step no longer redraw the whole factory.
var goods_layer := Node2D.new()
var machine_layer := Node2D.new()
var _mnodes := {}            ## machine id -> its node
## Step 33: each machine's picture (type, tier, size) drawn once into a small texture: a
## machine is then one textured quad (its icon was a dozen draw calls -- forty-four of
## them were 40% of a frame's draw calls). The state badge and gauges stay vector.
var _icon_root := Node.new()
var _icon_cache := {}
var _goods_key := ""
var redraws := {"floors": 0, "goods": 0, "machines": 0, "detail": 0}   ## for the perf tests
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
## Step 20: the packing station. Bags being filled (pack id -> its fill), the
## nozzles of the current tier, the station's status icon (starved / blocked).
var filling := {}
var nozzles: Array = []
var _nozzle_key := ""
var status_node := Node2D.new()
var bell_node := Node2D.new()      ## Step 21: swings just before the next customer comes in
## The idle hint as nodes drawn once and moved (Step 21 fix of an R-01 regression:
## the hint used to redraw the whole ring layer every frame for as long as nobody
## touched the factory; 0.19.0's meter and knob made each redraw heavier).
var hint_node := Node2D.new()
var hint_dot := Node2D.new()
var hint_gold := Node2D.new()
var hint_finger := Node2D.new()
var _hint_key := ""
## Step 28: each machine's moving part (drawn once, moved by rotation/position/scale)
## and the kernels in flight from a hopper to a kettle.
var _motion := {}
var overview := false          ## Step 32: the upkeep overview is open
var _overview_t := 0.0
var _low_wallet := false
var ov_machine := -1           ## Step 33: the machine picked in the overview (its diagnostics)
var _heat_node: Node2D = null   ## Step 29: the kitchen's thermometer beside its places
var _heat_shown := -1.0
var _kernel_flights: Array = []
## Step 23: the bottleneck cue (a soft outline round the floor that holds the
## next one back, pulsing by its alpha -- drawn once per floor change) and the
## understated numbers by a badge on hover or press.
var cue_node := Node2D.new()
var _cue := ""
var _cue_key := ""
var stats_node := Node2D.new()
var _hover := -1
var _stats_key := ""
var _status := ""
var _clock := 0.0
var _cooking := false            ## this press started on the bottom floor
var _floors_key := ""


func setup(p_rules: PopRules) -> void:
	super(p_rules)
	selected = -1
	# A new run (restart, a new factory): no journey of the old one may linger.
	for a in actor_layer.get_children():
		a.queue_free()
	customers.clear()
	_arrived.clear()
	cargo.clear()
	_pool = {"lot": [], "bag": []}
	leaving.clear()
	cargo_log.clear()
	filling.clear()
	nozzles.clear()
	_motion.clear()
	for n: Node in machine_layer.get_children():
		n.queue_free()
	_mnodes.clear()
	for n: Node in _icon_root.get_children():
		n.queue_free()
	_icon_cache.clear()
	_goods_key = ""
	_kernel_flights.clear()
	_nozzle_key = ""
	_status = ""
	_cue_key = ""
	_stats_key = ""
	if floor_layer.get_parent() == null:
		floor_layer.name = "Floors"
		add_child(floor_layer)
		move_child(floor_layer, 0)
		floor_layer.draw.connect(func() -> void:
			redraws["floors"] = int(redraws["floors"]) + 1
			_draw_floors(floor_layer))
		goods_layer.name = "Goods"
		add_child(goods_layer)
		move_child(goods_layer, 1)
		goods_layer.draw.connect(func() -> void:
			redraws["goods"] = int(redraws["goods"]) + 1
			_draw_shop(goods_layer, floor_rect(TOP))
			_draw_packing(goods_layer, packing_rect()))
		machine_layer.name = "Machines"
		add_child(machine_layer)
		move_child(machine_layer, 2)
		_icon_root.name = "IconCache"
		add_child(_icon_root)
		customer_node.name = "Customer"
		add_child(customer_node)
		move_child(customer_node, 3)
		customer_node.draw.connect(func() -> void: _draw_customer(customer_node))
		actor_layer.name = "Actors"
		add_child(actor_layer)
		move_child(actor_layer, 4)
		status_node.name = "PackerStatus"
		add_child(status_node)
		move_child(status_node, 5)
		status_node.draw.connect(func() -> void: _draw_status(status_node))
		hint_node.name = "Hint"
		add_child(hint_node)
		for n: Node2D in [hint_dot, hint_gold, hint_finger]:
			hint_node.add_child(n)
		hint_dot.draw.connect(func() -> void: hint_dot.draw_circle(Vector2.ZERO, machine_size() * 0.03, Color(1, 1, 1, 0.9)))
		hint_gold.draw.connect(func() -> void: _draw_hint_gold(hint_gold))
		hint_finger.draw.connect(func() -> void: _draw_hint_finger(hint_finger))
		hint_node.visible = false
		cue_node.name = "BottleneckCue"
		add_child(cue_node)
		cue_node.draw.connect(func() -> void: _draw_cue(cue_node))
		stats_node.name = "StageNumbers"
		add_child(stats_node)
		stats_node.draw.connect(func() -> void: _draw_stage_numbers(stats_node))
		bell_node.name = "Bell"
		add_child(bell_node)
		bell_node.draw.connect(func() -> void: PopFactoryArt.bell(bell_node, _head_px() * 0.9))
		detail_layer.name = "Detail"
		detail_layer.z_index = 10   # above everything, also the front row of the queue (z 1, Step 31)
		add_child(detail_layer)
		detail_layer.draw.connect(func() -> void:
			redraws["detail"] = int(redraws["detail"]) + 1
			if overview:
				_draw_overview(detail_layer, detail_rect())
			elif selected >= 0:
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
	if overview:   # Step 32: over the shop floor, like a machine's detail (on desktop, the side panel)
		if is_wide():
			var xo := size.x * 0.62 + 16
			return Rect2(Vector2(xo, 210), Vector2(size.x - xo - 16, size.y - 230))
		# Step 33: over the shop and the packing floor (the kitchen and its lines stay in view).
		var tt := floor_rect(TOP)
		var mid := floor_rect(MID)
		return Rect2(tt.position + Vector2(8, 6), Vector2(tt.size.x - 16, mid.end.y - tt.position.y - 12))
	if selected < 0:
		return Rect2()
	if is_wide():
		var x := size.x * 0.62 + 16
		return Rect2(Vector2(x, 210), Vector2(size.x - x - 16, size.y - 230))
	# Beside the ring, never over it: the kitchen's free right side -- for every
	# floor (Steps 20, 22: the floor being chosen for stays in view).
	var r := floor_rect(LOW)
	var x := machine_centre().x + ring_radius() + machine_size() * 0.09
	if sel_machine >= 0 or not sel_slot.is_empty():
		# Step 28: the kitchen's eight places fill its column, so a machine's detail sits
		# over the shop floor (the machines and the ring stay in view).
		# Step 33: a shop place's card over the packing floor -- never over the place chosen.
		var t := floor_rect(MID) if _sel_floor() == "shop" else floor_rect(TOP)
		return Rect2(t.position + Vector2(12, 8), Vector2(t.size.x - 24, t.size.y - 16))
	return Rect2(Vector2(x, r.position.y + 12), Vector2(r.end.x - 12 - x, r.size.y - 24))


func _sel_floor() -> String:
	if not sel_slot.is_empty():
		return String(sel_slot.get("floor", ""))
	if sel_machine >= 0 and rules:
		return String((rules.machine(sel_machine) as Dictionary).get("floor", ""))
	return ""


func tube_rect() -> Rect2:
	var top := floor_rect(TOP)
	var low := floor_rect(LOW)
	var x := scene_rect().end.x - 44
	return Rect2(Vector2(x, top.end.y - top.size.y * 0.45), Vector2(30, low.position.y + low.size.y * 0.35 - (top.end.y - top.size.y * 0.45)))


func machine_size() -> float:
	var low := floor_rect(LOW)
	var s := minf(low.size.y * 0.64, low.size.x * 0.52)
	# Step 33: a kitchen of several lines gives the hand's kettle a little less room.
	return s * 0.8 if dense("kitchen") else s


## Step 33: a floor that has bought a second line draws its places compactly, a group per line.
func dense(floor: String) -> bool:
	return rules != null and int((rules.get("floor_lines") as Dictionary).get(floor, 1)) >= 2


## The packing floor's own picture (bin, station, shelf): the whole floor, or above the
## strip of places once it has several lines.
func packing_rect() -> Rect2:
	var r := floor_rect(MID)
	if not dense("packing"):
		return r
	return Rect2(r.position, Vector2(r.size.x, r.size.y - _pack_strip().size.y - 6))


## Step 33: the packing lines' places, one row along the bottom of the floor.
func _pack_strip() -> Rect2:
	var r := floor_rect(MID)
	var h := clampf(r.size.y * 0.27, 34.0, 64.0)
	return Rect2(Vector2(r.position.x + 10, r.end.y - h - 4), Vector2(tube_rect().position.x - 10 - r.position.x - 10, h))


## The kitchen's places as groups, one per line (then the distributors' places).
func _line_groups(floor: String) -> Array:
	var base := int((rules.economy.table("factory")["slots"] as Dictionary)[floor])
	var out: Array = [base]
	var table: Array = (rules.economy.table("factory").get("lines", {}) as Dictionary).get(floor, [])
	for i in mini(int((rules.get("floor_lines") as Dictionary).get(floor, 1)) - 1, table.size()):
		out.append(int((table[i] as Dictionary)["places"]))
	var sum := 0
	for g: int in out:
		sum += g
	if int(rules.slots(floor)) > sum:
		out.append(int(rules.slots(floor)) - sum)
	return out


const LINE_GAP := 12.0


## The dense kitchen: right of the ring, a grid whose rows never mix two lines
## (columns that divide a line's eight places), as large as fits.
func _kitchen_cell(k: int) -> Rect2:
	var r := floor_rect(LOW)
	var left := machine_centre().x + ring_radius() + machine_size() * 0.06
	var right := tube_rect().position.x - 6
	var area := Rect2(Vector2(left, r.position.y + 10), Vector2(right - left, r.size.y - 20))
	var groups := _line_groups("kitchen")
	var gap := 6.0
	var best := 0.0
	var cols := 4
	for c in [2, 4, 8]:
		var rows := 0
		for g: int in groups:
			rows += ceili(float(g) / c)
		var w := minf((area.size.x - gap * (c - 1)) / c, (area.size.y - LINE_GAP * (groups.size() - 1) - gap * (rows - 1)) / rows * 0.82)
		if w > best:
			best = w
			cols = c
	var h := best / 0.82
	var row := 0
	var gi := 0
	var j := k
	while gi < groups.size() and j >= int(groups[gi]):
		row += ceili(float(groups[gi]) / cols)
		j -= int(groups[gi])
		gi += 1
	row += j / cols
	return Rect2(Vector2(area.position.x + (j % cols) * (best + gap), area.position.y + row * (h + gap) + gi * LINE_GAP), Vector2(best, h))


## The ring is centred in the kitchen (a little below the middle, room above
## for the popcorn to fly): the machine's base is placed from that centre.
func machine_base() -> Vector2:
	var low := floor_rect(LOW)
	var centre_y := low.position.y + low.size.y * 0.53
	var fx_ := 0.31 if dense("kitchen") else 0.43   # Step 33: room for three lines of places
	return Vector2(low.position.x + low.size.x * fx_, centre_y + PopMachineArt.height_at(rules.level if rules else 0, machine_size()) * 0.5)


func extra_rects() -> Dictionary:
	var out := {"floor_top": floor_rect(TOP), "floor_mid": floor_rect(MID), "floor_low": floor_rect(LOW),
		"badge_top": badge_rect(TOP), "badge_mid": badge_rect(MID), "badge_low": badge_rect(LOW),
		"news": news_rect(), "tube": tube_rect()}
	var c := machine_centre()
	var r := ring_radius() + machine_size() * 0.045
	out["ring"] = Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
	if selected >= 0 or overview:
		out["detail"] = detail_rect()
	if rules and not (rules.get("machines") as Array).is_empty():
		out["overview"] = overview_button_rect()   # Step 32
	if overview:
		out["pause_all"] = _pause_all_rect()
		var L := _ov_layout(detail_rect())
		for f: String in OV_FLOORS:
			if int(rules.line_cost(f)) >= 0:
				out["ov_line_%s" % f] = L["lines"][f]
		for id: int in L["machines"]:
			out["ovm_%d" % id] = L["machines"][id]
	# Step 26: every machine place, and the chosen machine's two buttons.
	for f: String in FLOOR_NAME:
		for k in (int(rules.slots(f)) if rules else 0):
			out["slot_%s_%d" % [f, k]] = slot_rect(f, k)
	if sel_machine >= 0:
		var b := _machine_buttons()
		out["m_pause"] = b["pause"]
		out["m_sell"] = b["sell"]
		out["m_group"] = _group_rect(detail_rect())   # Step 33: the floor's pause (for the tests)
		var fr := _flavor_rects(detail_rect())
		for f: String in fr.keys():
			out["flavor_%s" % f] = fr[f]   # Step 34: a coater's flavors
	if not sel_slot.is_empty():
		var rs := _picker_rects(detail_rect())
		var choices := _floor_choices(String(sel_slot["floor"]))
		for i in rs.size():
			out["pick_%s" % choices[i]] = rs[i]   # Step 28: the kitchen picker
	return out


func _floor_at(p: Vector2) -> int:
	for i in 3:
		if floor_rect(i).has_point(p):
			return i
	return -1


# -- input --------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm != null:
		_hover = -1
		for i in 3:
			if badge_rect(i).grow(6).has_point(mm.position):
				_hover = i
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		var f := _floor_at(mb.position)
		if _machine_press(mb.position):
			accept_event()
			return
		for i in 3:
			if badge_rect(i).has_point(mb.position):
				accept_event()
				_clear_machine_selection()
				toggle_floor(i)
				return
		if f == LOW and not detail_rect().has_point(mb.position):
			_cooking = true
			super(event)
			return
		accept_event()
		if f >= 0 and not detail_rect().has_point(mb.position):
			_clear_machine_selection()
			toggle_floor(f)
		elif selected >= 0 and not detail_rect().has_point(mb.position):
			_clear_machine_selection()
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
		or _squash != 0.0 or _jump > 0.0 or _redraw_once \
		or not _chain.is_empty() or _fountain > 0.0 or _meter_flash > 0.0 or _burst_glow > 0.0


var _redraw_once := true


func _process(delta: float) -> void:
	_slot_cache.clear()
	super(delta)
	_redraw_once = false
	# On a landscape screen the right column shows the kitchen's detail until a floor is chosen.
	if _wide_default and is_wide() and size.x > 0.0:
		_wide_default = false
		if selected < 0:
			selected = LOW
	# Step 33: three keys -- the floors' structure, the goods, the open panel -- and each
	# machine its own (_step_machine_nodes).
	var key := "%s|%d|%d|%s" % [size, selected, rules.level if rules else 0, _structure_key()]
	if key != _floors_key:
		_floors_key = key
		floor_layer.queue_redraw()
		goods_layer.queue_redraw()
		customer_node.queue_redraw()
		detail_layer.queue_redraw()
		_redraw_once = true
	var gkey := _inventory_key()
	if gkey != _goods_key:
		_goods_key = gkey
		goods_layer.queue_redraw()
		if selected >= 0 and not overview:
			detail_layer.queue_redraw()
		_redraw_once = true
	_overview_t += delta
	if _overview_t >= 0.5:   # the overview's numbers (and the wallet's warning) twice a second
		_overview_t = 0.0
		_low_wallet = bool(rules.upkeep_overview()["low_wallet"]) if rules else false
		if overview:
			detail_layer.queue_redraw()
	_step_machine_nodes()
	_process_glass()
	_step_actors(delta)
	_clock += delta
	_step_station(delta)
	_step_bell()
	_step_hint()
	_step_cues()
	_step_machine_motion(delta)


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


func _draw_hints(_ci: CanvasItem, _base: Vector2, _size_px: float) -> void:
	pass   # the factory's hint is its own nodes (_step_hint)


## The hint: a dot runs round the ring from the top to the gold (the heat of a
## good hold), the gold flashes, and a finger rests pressed on the kettle for a
## newcomer -- the same gesture as B's, but nothing is redrawn while it plays.
func _step_hint() -> void:
	if rules == null:
		return
	var show := _hint_visible()
	hint_node.visible = show
	if not show:
		return
	var w: Array = _r()["window"]
	var key := "%s|%s|%d" % [size, w, rules.level]
	if key != _hint_key:
		_hint_key = key
		for n: Node2D in [hint_dot, hint_gold, hint_finger]:
			n.queue_redraw()
	var burn := float(w[2])
	var loop := fmod(_t, 2.4) / 2.4
	var gold_mid := (float(w[0]) + float(w[1])) / 2.0
	var heat := gold_mid * clampf(loop / 0.8, 0.0, 1.0)
	var a := -PI / 2 + TAU * heat / burn
	hint_dot.position = machine_centre() + Vector2(cos(a), sin(a)) * ring_radius()
	hint_gold.visible = loop > 0.8
	hint_finger.visible = last_input_ms < 0 and now_ms >= HINT_HAND_MS


func _draw_hint_gold(ci: CanvasItem) -> void:
	if rules == null:
		return
	var w: Array = _r()["window"]
	var burn := float(w[2])
	var top := -PI / 2
	ci.draw_arc(machine_centre(), ring_radius(), top + TAU * float(w[0]) / burn, top + TAU * float(w[1]) / burn, 24, Color(1, 1, 1, 0.9), machine_size() * 0.09)


func _draw_hint_finger(ci: CanvasItem) -> void:
	var p := machine_centre() + Vector2(machine_size() * 0.06, machine_size() * 0.08)
	ci.draw_circle(p, 22, PopPalette.CREAM)
	ci.draw_rect(Rect2(p.x - 22, p.y, 44, 70), PopPalette.CREAM)
	ci.draw_circle(p + Vector2(0, -6), 10, Color(1, 0.85, 0.8))
	ci.draw_arc(p, 22, PI, TAU, 16, PopPalette.INK, 4.0)
	ci.draw_arc(p + Vector2(0, -22), 30, 0, TAU, 24, Color(PopPalette.INK, 0.35), 3.0)


func on_events(events: Array[Dictionary]) -> void:
	if not events.is_empty():   # (called every frame, mostly with nothing)
		_redraw_once = true
		_slot_cache.clear()   # Step 33: a line bought or a machine built moves the places
	var rest: Array[Dictionary] = []
	for e: Dictionary in events:
		if String(e["type"]) == "earn":
			# A sale: the coin and the +N at the counter, where the pack met the customer.
			var at := _counter_point()
			fx.coin(at, machine_size() / 900.0)
			_gain(int(e["data"].get("amount", 0)))
			_gains[-1]["at"] = at
			_sound("coin", 1.0, -6.0)
		elif String(e["type"]) in ["auto_lot", "machine_assisted", "machine_upgraded", "machine_sold", "machine_paused", "kernels_loaded", "overheat"]:
			_machine_event(e)
		elif String(e["type"]) == "station_upgrade":
			# Each floor's own flourish (Step 24): the station sparkles where it
			# stands with a rising chime and a clink of its new heads; the sign
			# lights up with a fanfare and a burst of gold over the shop.
			var tier := int(e["data"].get("tier", 1))
			var st_name := String(e["data"].get("station", ""))
			if st_name in ["cooker", "bagger", "kiosk"]:
				# Step 26: a new machine sparkles in its place.
				_sound("upgrade", 1.15)
				if not reduced_motion:
					fx.sparkle(slot_rect(String(FLOOR_OF_TYPE[st_name]), int(e["data"].get("slot", 0))).get_center(), machine_size() / 900.0, rng, 6, 100.0)
			elif st_name == "sign":
				_sound("fanfare", 1.0 + 0.04 * tier, -6.0)
				if not reduced_motion:
					fx.burst(_sign_rect().get_center(), 10 + tier * 2, machine_size() / 900.0, rng, PopPalette.GOLD, 0.8, 1.0)
					fx.sparkle(_sign_rect().get_center(), machine_size() / 900.0, rng, 6, 120.0)
			else:
				_sound("upgrade", 1.0 + 0.06 * tier)
				_sound("clink", 1.1 + 0.05 * tier, -8.0)
				if not reduced_motion:
					fx.sparkle(_station_rect().get_center(), machine_size() / 900.0, rng, 6, 120.0)
			_nozzle_key = ""
		else:
			rest.append(e)
	_flow_events(events)
	super(rest)


# -- the floors (drawn once per change) ----------------------------------------

func _draw_floors(ci: CanvasItem) -> void:
	var cols := [PopTokens.FLOOR_TOP, PopTokens.FLOOR_MID, PopTokens.FLOOR_LOW]
	for i in 3:
		PopFactoryArt.floor_panel(ci, floor_rect(i), cols[i], i == selected)
	_draw_kitchen(ci, floor_rect(LOW))   # (the shop and the packing floor: goods_layer, Step 33)
	_draw_machines(ci)
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
	PopFactoryArt.shop_sign(ci, sign, int(rules.shop_sign()["look"]) if rules else 0)
	PopFactoryArt.bag(ci, sign.get_center() + Vector2(-sign.size.x * 0.18, sign.size.y * 0.3), sign.size.y * 0.42)
	# Step 21: the stock, on the board -- one gold dot per sealed pack ready, an
	# empty ring per free place; out of stock with someone waiting: the bag in red.
	if rules:
		var ready := (rules.get("shelf") as Array).size()
		var cap := int(rules.economy.table("factory")["shelf_packs"])
		var dr := sign.size.y * 0.06
		for k in cap:
			var p := Vector2(sign.position.x + sign.size.x * (0.62 + 0.18 * (k % 2)), sign.position.y + sign.size.y * (0.16 + 0.19 * (k / 2)))
			if k < ready:
				ci.draw_circle(p, dr, PopPalette.GOLD)
			else:
				ci.draw_arc(p, dr, 0, TAU, 10, Color(1, 1, 1, 0.45), 1.5)
		if ready == 0 and not (rules.get("queue") as Array).is_empty():
			# Out of stock with someone waiting: the bag greys and a red no-entry sign sits on it.
			var bp := sign.get_center() + Vector2(-sign.size.x * 0.18, sign.size.y * 0.3)
			PopMachineArt._round_rect(ci, Rect2(bp - Vector2(sign.size.y * 0.3, sign.size.y * 0.7), Vector2(sign.size.y * 0.6, sign.size.y * 0.72)), 4, Color(0.24, 0.27, 0.25))
			PopFactoryArt.bag(ci, bp, sign.size.y * 0.42, Color(0.6, 0.6, 0.62))
			var nc := bp + Vector2(sign.size.y * 0.2, -sign.size.y * 0.5)
			ci.draw_circle(nc, sign.size.y * 0.14, PopTokens.WARN)
			ci.draw_rect(Rect2(nc - Vector2(sign.size.y * 0.09, sign.size.y * 0.025), Vector2(sign.size.y * 0.18, sign.size.y * 0.05)), Color.WHITE)
	var counter := counter_rect()
	PopFactoryArt.machine(ci, counter)
	# The handover places, one per lane (a mat on the counter).
	if rules:
		for lane in int(rules.lanes()):
			var h := _handoff_spot(lane)
			PopMachineArt._round_rect(ci, Rect2(h + Vector2(-_head_px() * 1.2, -4), Vector2(_head_px() * 2.4, 8)), 4, Color(1, 1, 1, 0.5))


func counter_rect() -> Rect2:
	var r := floor_rect(TOP)
	return Rect2(Vector2(r.position.x + r.size.x * 0.06, r.end.y - r.size.y * 0.3), Vector2(r.size.x * 0.8, r.size.y * 0.14))


const CUSTOMER_COLOURS := [Color(0.435, 0.714, 0.91), Color(0.561, 0.878, 0.769), Color(1.0, 0.7, 0.42), Color(0.78, 0.6, 0.88), Color(0.95, 0.55, 0.6)]
const SKIN := [Color(0.96, 0.82, 0.68), Color(0.85, 0.63, 0.48), Color(0.97, 0.88, 0.78), Color(0.72, 0.54, 0.4), Color(0.9, 0.72, 0.58)]


## The queue at the counter, head first from the left (only real customers --
## the model's queue; Step 17), the one being served at the hand-over spot.
func _draw_customer(_ci: CanvasItem) -> void:
	return   # Step 18: customers are actors (they walk); kept for the layer order.


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
	var kinds := _bin_kinds(mini(portions, cap))   # Step 34: each portion in its flavor
	for k in mini(portions, cap):
		var col := k % per_row
		var row := k / per_row
		var at := Vector2(hop.position.x + hop.size.x * (0.2 + 0.2 * col) + (row % 2) * pr * 0.4, hop.end.y - pr * 1.1 - row * pr * 1.2)
		if k < kinds.size() and String(kinds[k]) not in ["plain", "premium", "bargain"]:
			PopFactoryArt.flavor_popcorn(ci, at, pr, String(kinds[k]))
		else:
			PopFactoryArt.popcorn(ci, at, pr)
	# Step 20: the station at its tier (the nozzles and the bags in it are actors).
	if rules:
		PopFactoryArt.packer(ci, _station_rect(), int(rules.packer()["look"]), int(rules.packer()["per_cycle"]))
	# The shelf: one bag per real sealed pack, empty places dashed.
	var shelf_n := (int(rules.state()["shelf"]) - _bags_flying_to_shelf()) if rules else 0
	var shelf_cap := int(rules.state()["shelf_cap"]) if rules else 0
	# Two rows of places, right of the packer and left of the tube.
	var per := maxi(1, (shelf_cap + 1) / 2)
	var span := tube_rect().position.x - 16 - (r.position.x + r.size.x * 0.62)
	var w := minf(r.size.y * 0.14, span / (float(per) * 1.2))
	if rules and String(rules.packer_state()) == "blocked":
		# The shelf is full: a red outline around it (the station's status icon says so too).
		var sr := Rect2(Vector2(r.position.x + r.size.x * 0.62 - 6, belt.position.y - w * 3.3), Vector2(span + 4, w * 3.3 + 6))
		var sp := PopMachineArt.round_rect_points(sr, 8)
		sp.append(sp[0])
		ci.draw_polyline(sp, PopTokens.WARN, 4.0, true)
	for k in shelf_cap:
		var foot := Vector2(r.position.x + r.size.x * 0.62 + (k % per) * w * 1.2 + w * 0.6, belt.position.y - (k / per) * w * 1.65)
		if k < shelf_n:
			var shelved: Array = rules.get("shelf") if rules else []
			var prem := k < shelved.size() and String((shelved[k] as Dictionary).get("recipe", "")) == "premium"
			var barg := k < shelved.size() and String((shelved[k] as Dictionary).get("recipe", "")) == "bargain"
			var rec := String((shelved[k] as Dictionary).get("recipe", "plain")) if k < shelved.size() else "plain"
			if k < shelved.size() and int((shelved[k] as Dictionary).get("size", 2)) == 1:
				PopFactoryArt.cup(ci, foot, w * 0.9)   # Step 30: a cup
				if rec not in ["plain", "premium", "bargain"]:   # Step 34: its flavor's kernels on top
					PopFactoryArt.flavor_popcorn(ci, foot - Vector2(0, w * 1.05), w * 0.3, rec)
			elif rec not in ["plain", "premium", "bargain"]:
				PopFactoryArt.sku_bag(ci, foot, w, rec)   # Step 34: the flavor's own bag
			else:
				PopFactoryArt.bag(ci, foot, w, PopTokens.STEEL_DEEP if barg else PopTokens.MACHINE, false, 0, 2, prem, barg)
		else:
			PopMachineArt._round_rect(ci, Rect2(foot - Vector2(w * 0.5, w * 1.5), Vector2(w, w * 1.5)), 4, Color(1, 1, 1, 0.35))


func _draw_kitchen(_ci: CanvasItem, _r: Rect2) -> void:
	pass   # its machine places are drawn with the others (_draw_machines, Step 26)


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
		MID:   # a bag, and a dot for the station's state (green working, blue starved, red shelf full)
			PopFactoryArt.bag(ci, c + Vector2(0, s * 1.0), s * 1.3)
			if rules:
				var st := String(rules.packer_state())
				var dot := PopTokens.OK if st == "run" else (PopTokens.SKY if st == "starved" else (PopTokens.WARN if st == "blocked" else PopTokens.STEEL))
				ci.draw_circle(c + Vector2(b.size.x * 0.36, b.size.y * 0.36), b.size.x * 0.13, dot)
				ci.draw_arc(c + Vector2(b.size.x * 0.36, b.size.y * 0.36), b.size.x * 0.13, 0, TAU, 16, PopPalette.INK, 2.0)
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
	if sel_machine >= 0 or not sel_slot.is_empty():
		_draw_machine_detail(ci, d)   # Step 26: a machine's own numbers, not the floor's forms
		return
	var vertical := d.size.y > d.size.x * 1.15
	var h: float
	var a: Vector2
	var b: Vector2
	if vertical:   # now above, next below, the arrow pointing down (the kitchen's numbers on top)
		var top := 0.36
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
	if sel_machine >= 0 or not sel_slot.is_empty():
		_draw_machine_detail(ci, d)
	elif i == TOP:
		_draw_sign_numbers(ci, d)
	elif i == MID:
		_draw_packer_numbers(ci, d)
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
		MID:   # the packing station at this tier and the next (Step 20)
			var tiers: Array = rules.economy.table("factory")["packer"] if rules else []
			if tiers.is_empty():
				return
			var t: Dictionary = tiers[mini(int(rules.get("packer_tier")) + k, tiers.size() - 1)]
			_station_picture(ci, foot, h, int(t["look"]), int(t["per_cycle"]))
			if dim:
				PopMachineArt._round_rect(ci, Rect2(foot - Vector2(h * 0.75, h * 1.0), Vector2(h * 1.5, h * 1.05)), 8, Color(1, 1, 1, 0.5))
		TOP:   # the sign at this tier and the next (Step 22)
			var tiers: Array = rules.economy.table("factory")["sign"] if rules else []
			if tiers.is_empty():
				return
			var t: Dictionary = tiers[mini(int(rules.get("sign_tier")) + k, tiers.size() - 1)]
			PopFactoryArt.shop_sign(ci, Rect2(foot - Vector2(h * 0.55, h * 0.75), Vector2(h * 1.1, h * 0.62)), int(t["look"]))
			if dim:
				PopMachineArt._round_rect(ci, Rect2(foot - Vector2(h * 0.6, h * 0.95), Vector2(h * 1.2, h * 0.95)), 8, Color(1, 1, 1, 0.5))


# -- Step 17: the truth of the model on screen --------------------------------

## What the static floors show: changes only when the stock does (so they
## redraw only then, R-01).
func _inventory_key() -> String:
	if rules == null:
		return ""
	var sel := ""
	if sel_machine >= 0:   # the open machine's own numbers
		var m: Dictionary = rules.machine(sel_machine)
		sel = "%s:%d:%d:%s" % [m.get("state", ""), int(m.get("tier", 0)), int(m.get("done", 0)), m.get("flavor", "")]
	var lp := ""
	if rules.parallel_lines():
		for line in rules.packing_lines():
			lp += "%d," % rules.line_portions(line)
	return "%d|%d|%d|%d|%s|%s" % [rules.bin_portions(), (rules.get("shelf") as Array).size(), (rules.get("queue") as Array).size(),
		(rules.get("lift") as Array).size(), (rules.get("packing") as Array).size(), not (rules.get("serving") as Dictionary).is_empty()] + "|%d|%s" % [rules.get("packer_tier"), rules.packer_state()] \
		+ "|%d|%s|%s|%s|%d" % [sel_machine, sel_slot, sel, lp, rules.get("sign_tier")] \
		+ "|%d|%d" % [int((rules.get("stats") as Dictionary).get("coated_portions", 0)), int((rules.get("stats") as Dictionary).get("sold", 0))]


## Step 33: what the floor layer draws -- the places (which hold what), the lines, the
## stations that are open, the wallet's warning on the overview button.
func _structure_key() -> String:
	if rules == null:
		return ""
	return "%s|%s|%s|%s|%s|%s" % [",".join((rules.get("machines") as Array).map(func(m: Dictionary) -> String: return "%d:%s:%d" % [m["id"], m["floor"], m["slot"]])),
		rules.get("floor_lines"), sel_slot, rules.station_open("bagger"), rules.station_open("kiosk"), _low_wallet] + "|%d|%d" % [rules.get("packer_tier"), rules.get("sign_tier")]


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


## Step 33: lots and bags are pooled -- a busy factory reuses the same few nodes
## instead of making and freeing one per lot (no churn for the garbage collector);
## at most CARGO_MAX journeys are drawn at once (the model moves every good either way;
## the bin, the shelf and the counters show the real amounts).
const CARGO_MAX := 40
var _pool := {"lot": [], "bag": []}
var cargo_stats := {"peak": 0, "skipped": 0, "made": 0, "reused": 0}


func _cargo_full() -> bool:
	if cargo.size() >= CARGO_MAX:
		cargo_stats["skipped"] = int(cargo_stats["skipped"]) + 1
		return true
	return false


func _new_actor(kind: String, id: int) -> Node2D:
	var a: Node2D = null
	if _pool.has(kind) and not (_pool[kind] as Array).is_empty():
		a = (_pool[kind] as Array).pop_back()
		a.open = false
		a.fill = 0
		a.of = 2
		a.done = false
		a.steps = false
		a.easing_to = false
		a.carrying = false
		a.recipe = "plain"
		a.visible = true
		for meta in ["to", "end_on_arrival"]:
			if a.has_meta(meta):
				a.remove_meta(meta)
		a.queue_redraw()
		cargo_stats["reused"] = int(cargo_stats["reused"]) + 1
	else:
		a = Actor.new()
		a.kind = kind
		actor_layer.add_child(a)
		if _pool.has(kind):   # lots and bags (customers are not pooled)
			cargo_stats["made"] = int(cargo_stats["made"]) + 1
	a.model_id = id
	return a


## Step 34: the flavor of a pack the model holds (shelf, station, serving, a filler's hands).
func _pack_recipe(pid: int) -> String:
	if rules == null:
		return "plain"
	for arr: Array in [rules.get("shelf"), rules.get("packing")]:
		for p: Dictionary in arr:
			if int(p["id"]) == pid:
				return String(p["recipe"])
	for sv: Dictionary in rules.get("serves"):
		if int(sv["pack"]["id"]) == pid:
			return String(sv["pack"]["recipe"])
	for m: Dictionary in rules.get("machines"):
		var h: Dictionary = m["held"]
		if not h.is_empty() and int(h.get("id", -1)) == pid:
			return String(h.get("recipe", "plain"))
	return "plain"


## Step 34: the bin's portions oldest first, by flavor (one entry a portion, up to n).
func _bin_kinds(n: int) -> Array:
	var out: Array = []
	if rules == null:
		return out
	for lot: Dictionary in rules.get("bin"):
		for q in int(lot["portions"]):
			if out.size() >= n:
				return out
			out.append(String(lot["recipe"]))
	return out


func _log(id: int, kind: String, what: String) -> void:
	cargo_log.append({"id": id, "kind": kind, "what": what, "t": now_ms})
	if cargo_log.size() > 400:
		cargo_log.pop_front()


func _head_px() -> float:
	return clampf(floor_rect(TOP).size.y * 0.1, 14.0, 26.0)


## The queue's places, head first from the hand-over towards the door; the gap
## shrinks so a full queue (queue_cap) fits before the door without overlap.
## A queue too long for one row wraps into a second row behind it (heads above
## the front row's shoulders), so a big shop never piles people on each other.
func _queue_spot(i: int) -> Vector2:
	# Step 31: the queue stands right of the counter's lanes, up to the shop's machines;
	# who does not fit there waits in a second row behind the lanes (never off the floor --
	# rows that climbed upward hid customers behind the awning once four places and four
	# lanes took the room).
	var c := counter_rect()
	var hp := _head_px()
	var lanes := int(rules.lanes()) if rules else 1
	var x0 := maxf(c.position.x + c.size.x * 0.42, _handoff_spot(lanes - 1).x + hp * 2.2)
	var cap := maxi(1, int(rules.queue_cap())) if rules else 5
	var x_end := floor_rect(TOP).end.x - hp * 1.6
	if rules:
		x_end = slot_rect("shop", int(rules.slots("shop")) - 1).position.x - hp * 0.5
	var room := maxf(0.0, x_end - x0)
	var first := clampi(int(room / (hp * 2.3)), 0, cap)
	if i < first:
		var gap := minf(hp * 2.7, room / float(maxi(1, first)))
		return Vector2(x0 + gap * (float(i) + 0.5), c.position.y + 2)
	var j := i - first
	var left := cap - first
	var start := c.position.x + c.size.x * 0.22
	var gap2 := minf(hp * 2.3, (x_end - start) / float(maxi(1, left)))
	return Vector2(start + gap2 * (float(j) + 0.5), c.position.y + 2 - hp * 1.25)


## The hand-over places, one per lane, from the counter's left part rightwards
## (a bigger shop reveals more of them; Step 22).
func _handoff_spot(lane: int = 0) -> Vector2:
	var c := counter_rect()
	if lane >= 100:   # Step 26: a kiosk's customer stands in front of it (Step 31: the express window's too)
		return Vector2(slot_rect("shop", lane - (200 if lane >= 200 else 100)).get_center().x, c.position.y + 2)
	# Step 31: up to six counter lanes share the space left of the shop's machines.
	var start := c.position.x + c.size.x * 0.26
	var room := slot_rect("shop", int(rules.slots("shop")) - 1).position.x - _head_px() * 1.2 - start if rules else 0.0
	var n := maxi(2, int(rules.lanes())) if rules else 2
	var step := minf(_head_px() * 2.5, room / float(n)) if room > 0.0 else _head_px() * 2.5
	return Vector2(start + step * lane, c.position.y + 2)


func _door() -> Vector2:
	var r := floor_rect(TOP)
	return Vector2(r.end.x + _head_px() * 2.0, counter_rect().position.y + 2)


func _shelf_spot(k: int) -> Vector2:
	var r := packing_rect()
	var shelf_cap := int(rules.state()["shelf_cap"])
	var per := maxi(1, (shelf_cap + 1) / 2)
	var span := tube_rect().position.x - 16 - (r.position.x + r.size.x * 0.62)
	var w := minf(r.size.y * 0.14, span / (float(per) * 1.2))
	var belt_y := r.end.y - r.size.y * 0.2
	return Vector2(r.position.x + r.size.x * 0.62 + (k % per) * w * 1.2 + w * 0.6, belt_y - (k / per) * w * 1.65)


func _bag_px() -> float:
	return packing_rect().size.y * 0.16


func _bin_top() -> Vector2:
	var r := packing_rect()
	var hs := r.size.y * 0.46
	return Vector2(r.position.x + r.size.x * 0.14 + hs * 0.45, r.position.y + r.size.y * 0.16 + hs * 0.3)


func _packer_out() -> Vector2:
	var r := packing_rect()
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
				if _cargo_full():
					continue
				var a := _new_actor(Actor.LOT, int(d["lot"]))
				a.size_px = _bag_px() * 0.85
				var top := machine_top()
				if d.has("machine") and rules and not (rules.machine(int(d["machine"])) as Dictionary).is_empty():
					var mm: Dictionary = rules.machine(int(d["machine"]))
					top = slot_rect(String(mm["floor"]), int(mm["slot"])).get_center()
				var bin := _bin_top()
				var path := PackedVector2Array([top, Vector2(tube_x, top.y), Vector2(tube_x, bin.y - 40), bin])
				if d.has("machine") and rules and not (rules.machine(int(d["machine"])) as Dictionary).is_empty():
					var by := _kitchen_belt_y(int(rules.machine(int(d["machine"]))["slot"]))
					if by > 0.0:   # Step 33: down to its line's belt, along it to the tube
						path = PackedVector2Array([top, Vector2(top.x, by), Vector2(tube_x, by), Vector2(tube_x, bin.y - 40), bin])
				a.start(path, _seconds("lift"), reduced_motion)
				cargo[int(d["lot"])] = a
				_log(int(d["lot"]), "lot", "start")
			"lot_binned":
				_end_cargo(int(d["lot"]), "lot")
			"coat_started", "lot_coated":
				# Step 34: plain popcorn hops from the bin into the coater; the batch comes back
				# in its flavor (the same portions, a new colour).
				if _cargo_full() or rules == null or (rules.machine(int(d["machine"])) as Dictionary).is_empty():
					continue
				var cm: Dictionary = rules.machine(int(d["machine"]))
				var cr := slot_rect(String(cm["floor"]), int(cm["slot"]))
				var bin_at := _bin_top()
				var c_at := Vector2(cr.get_center().x, cr.position.y + cr.size.y * 0.3)
				var lid := int(d["lot"])
				var a := _new_actor(Actor.LOT, lid)
				a.size_px = _bag_px() * 0.55
				a.recipe = "plain" if String(e["type"]) == "coat_started" else String(d.get("flavor", "plain"))
				var mid := Vector2((bin_at.x + c_at.x) * 0.5, minf(bin_at.y, c_at.y) - 36.0)
				var path := PackedVector2Array([bin_at, mid, c_at]) if String(e["type"]) == "coat_started" else PackedVector2Array([c_at, mid, bin_at])
				a.start(path, 0.6, reduced_motion)
				a.set_meta("end_on_arrival", true)
				cargo[-lid if String(e["type"]) == "coat_started" else lid] = a
				_sound("pop_1", 0.8 if String(e["type"]) == "coat_started" else 1.6, -20.0)
			"pack_started":
				# Step 20: an empty open bag indexes in under its head; its fill follows the model's clock.
				var pid := int(d["pack"])
				var bag := _new_actor(Actor.BAG, pid)
				bag.size_px = _bag_px()
				bag.open = true
				bag.of = int(d["size"])
				bag.recipe = String(d.get("recipe", "plain"))
				bag.position = _entry_foot()
				filling[pid] = {"t0": int(e["t"]), "ms": int(d.get("ms", 3000)), "head": int(d.get("head", 0)), "size": int(d["size"]),
					"dropped": 0, "landed": 0, "sealed": false, "bag": bag, "puffs": []}
				_log(pid, "fill", "start")
			"pack_shelved":
				var pid := int(d["pack"])
				var from := _packer_out()
				if d.has("machine") and rules and not (rules.machine(int(d["machine"])) as Dictionary).is_empty():
					var bm: Dictionary = rules.machine(int(d["machine"]))
					var br := slot_rect(String(bm["floor"]), int(bm["slot"]))
					from = Vector2(br.get_center().x, br.end.y)
				var b: Node2D
				if filling.has(pid):
					# The same bag, sealed, slides from under its head to its place on the shelf.
					var f: Dictionary = filling[pid]
					for puff: Node2D in f["puffs"]:
						puff.queue_free()
					b = f["bag"]
					b.open = false
					b.fill = 0
					b.queue_redraw()
					from = b.position
					filling.erase(pid)
					_log(pid, "fill", "end")
				else:
					if _cargo_full():
						continue
					b = _new_actor(Actor.BAG, pid)
					b.size_px = _bag_px()
				b.recipe = _pack_recipe(pid)
				b.queue_redraw()
				b.set_meta("to", "shelf")
				var k := maxi(0, int(rules.state()["shelf"]) - 1)
				var sh: Array = rules.get("shelf")
				for q in sh.size():
					if int(sh[q]["id"]) == pid:
						k = q
				var spot := _shelf_spot(k)
				b.start(PackedVector2Array([from, Vector2(spot.x, from.y), spot]), 0.45, reduced_motion)
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
					if _cargo_full():
						var cid0 := int(d["customer"])
						if not customers.has(cid0):
							customers[cid0] = _make_customer(cid0, _arrived.get(cid0, {}), _door())
						customers[cid0].walk_to(_handoff_spot(int(d.get("lane", 0))))
						continue
					bag = _new_actor(Actor.BAG, pid)
					bag.size_px = _bag_px()
				bag.recipe = _pack_recipe(pid)
				bag.queue_redraw()
				bag.set_meta("to", "counter")
				var lane := int(d.get("lane", 0))
				var hand := _handoff_spot(lane) - Vector2(_head_px() * 1.4, _head_px() * 0.8)
				bag.start(PackedVector2Array([from, Vector2(tube_x, from.y), Vector2(tube_x, hand.y), hand]), _seconds("serve"), reduced_motion)
				cargo[pid] = bag
				_log(pid, "bag", "redirect" if redirected else "serve")
				var cid := int(d["customer"])
				if not customers.has(cid):   # served the step they came in: they still walk in
					customers[cid] = _make_customer(cid, _arrived.get(cid, {}), _door())
				if customers.has(cid):
					customers[cid].walk_to(_handoff_spot(lane))
			"handed_over":
				# Step 31: the bag is theirs; they carry it to the auto cashier's drawer and pay there.
				_end_cargo(int(d["pack"]), "bag")
				var hcid := int(d["customer"])
				if customers.has(hcid):
					var hc: Node2D = customers[hcid]
					hc.carrying = true
					hc.queue_redraw()
					for mm: Dictionary in rules.get("machines"):
						if String(mm["type"]) == "S03":
							hc.walk_to(Vector2(slot_rect("shop", int(mm["slot"])).get_center().x, counter_rect().position.y + 2))
							break
			"sale":
				var pid := int(d["pack"])
				_end_cargo(pid, "bag")
				if not reduced_motion and customers.has(int(d["customer"])):
					var cc: Node2D = customers[int(d["customer"])]
					fx.burst(cc.position + Vector2(0, -_head_px() * 2.0), 3, machine_size() / 1500.0, rng, PopPalette.GOLD, 0.7, 0.8)   # coins pop
				var cid := int(d["customer"])
				if customers.has(cid):
					var c: Node2D = customers[cid]
					c.carrying = true
					c.mood = "happy"
					c.queue_redraw()
					if not reduced_motion:
						fx.sparkle(c.position + Vector2(0, -_head_px() * 3.2), machine_size() / 1400.0, rng, 3, 60.0)
					c.walk_to(_door())
					leaving.append(c)
					customers.erase(cid)
				_log(pid, "bag", "sold")
			"customer_arrived":
				_sound("ding", 1.7, -16.0)
				_arrived[int(d["customer"])] = d.get("order", {})
				if _arrived.size() > 64:
					_arrived.erase(_arrived.keys()[0])
			"customer_left":
				var cid := int(d["customer"])
				if customers.has(cid):
					var c: Node2D = customers[cid]
					c.mood = "sad"
					c.queue_redraw()
					c.walk_to(_door())
					leaving.append(c)
					customers.erase(cid)


func _end_cargo(id: int, kind: String) -> void:
	if cargo.has(id):
		var a: Node2D = cargo[id]
		cargo.erase(id)
		if _pool.has(a.kind) and (_pool[a.kind] as Array).size() < CARGO_MAX:
			a.visible = false
			(_pool[a.kind] as Array).append(a)
		else:
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
			customers[id] = _make_customer(id, queue[i]["order"], _door() if now_ms > 500 else _queue_spot(i))
		customers[id].walk_to(_queue_spot(i))
		# The second row stands behind the first (z 0 is still above the floor; -1 hid them under it).
		customers[id].z_index = 0 if _queue_spot(i).y < counter_rect().position.y - 1.0 else 1
		# Their face follows their patience (calm, then impatient below a third).
		var left := float(queue[i]["patience_ms"]) / float(rules.economy.table("factory")["customers"]["patience_ms"])
		var mood := "impatient" if left < 0.34 else "wait"
		if customers[id].mood != mood:
			customers[id].mood = mood
			customers[id].queue_redraw()
	var sv: Dictionary = rules.get("serving")
	if not sv.is_empty():
		want[int(sv["customer"]["id"])] = -1


func _make_customer(id: int, order: Dictionary, at: Vector2) -> Node2D:
	var a := _new_actor(Actor.CUSTOMER, id)
	a.size_px = _head_px()
	a.body = CUSTOMER_COLOURS[id % 5]
	a.skin = SKIN[id % 5]
	a.order_size = int(order.get("size", 0))
	a.order_premium = String(order.get("recipe", "plain")) == "premium"
	a.order_bargain = String(order.get("recipe", "plain")) == "bargain"
	a.order_recipe = String(order.get("recipe", "plain"))
	a.recipe = a.order_recipe   # the bag they carry out is the flavor they asked for
	a.position = at
	return a


## Step 33: who came in (their order), for a customer served in the same step they arrived
## -- a shop with lanes to spare used to sell to people who were never drawn.
var _arrived := {}


func _step_actors(delta: float) -> void:
	_reconcile_customers()
	cargo_stats["peak"] = maxi(int(cargo_stats["peak"]), cargo.size())
	for a in cargo.values():
		a.step(delta)
	for id in cargo.keys():
		var a: Node2D = cargo[id]
		if a.done and a.has_meta("end_on_arrival"):
			_end_cargo(int(id), "bag")
			_redraw_once = true
			goods_layer.queue_redraw()   # the bag lands on the shelf (the goods layer, Step 33)
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
	var fill := []
	for id in filling.keys():
		var f: Dictionary = filling[id]
		fill.append({"id": int(id), "head": f["head"], "landed": f["landed"], "size": f["size"], "sealed": f["sealed"],
			"x": (f["bag"] as Node2D).position.x, "y": (f["bag"] as Node2D).position.y})
	return {"flying": flying, "customers": customers.size(), "leaving": leaving.size(), "log": cargo_log.duplicate(),
		"filling": fill, "nozzles": nozzles.size(), "packer_status": _status,
		"moods": customers.values().map(func(a: Node2D) -> String: return a.mood), "bell": bell_swinging(),
		"cue": _cue if cue_node.visible else "", "bubbles": customers.values().map(func(a: Node2D) -> int: return a.order_size),
		"cargo_stats": cargo_stats.duplicate(), "cargo_now": cargo.size(), "pool": {"lot": (_pool["lot"] as Array).size(), "bag": (_pool["bag"] as Array).size()},
		"redraws": redraws.duplicate(), "machine_nodes": _mnodes.size(), "actor_nodes": actor_layer.get_child_count(), "dense": {"kitchen": dense("kitchen"), "packing": dense("packing"), "shop": dense("shop")},
		"ov_machine": ov_machine, "selected": selected, "sel_machine": sel_machine, "sel_slot": sel_slot}


# -- Step 20: the packing station ---------------------------------------------

## The station's body and belt on the middle floor (between the raw bin and the shelf).
func _station_rect() -> Rect2:
	var r := packing_rect()
	return Rect2(Vector2(r.position.x + r.size.x * 0.34, r.position.y + r.size.y * 0.12), Vector2(r.size.x * 0.25, r.size.y * 0.76))


func _heads() -> int:
	return int(rules.packer()["per_cycle"]) if rules else 1


## Where a head's nozzle tip rests, and the belt spot under it.
func _head_tip(i: int, n: int) -> Vector2:
	var s := _station_rect()
	return Vector2(PopFactoryArt.packer_head_x(s, i, n), s.position.y + s.size.y * 0.5)


func _head_foot(i: int, n: int) -> Vector2:
	var s := _station_rect()
	return Vector2(PopFactoryArt.packer_head_x(s, i, n), s.end.y - s.size.y * 0.12)


## Where an empty bag comes in (the station's left end, on the belt).
func _entry_foot() -> Vector2:
	var s := _station_rect()
	return Vector2(s.position.x - _bag_px() * 0.3, s.end.y - s.size.y * 0.12)


## A small picture of a station (the detail and the upgrade card).
func _station_picture(ci: CanvasItem, foot: Vector2, h: float, look: int, heads: int, mono: Color = Color(0, 0, 0, 0)) -> void:
	var r := Rect2(foot - Vector2(h * 0.62, h * 0.95), Vector2(h * 1.24, h * 0.95))
	PopFactoryArt.packer(ci, r, look, heads, mono)
	for i in heads:
		var tip := Vector2(PopFactoryArt.packer_head_x(r, i, heads), r.position.y + r.size.y * 0.5)
		var w := h * 0.17
		if mono.a > 0.0:
			ci.draw_rect(Rect2(tip - Vector2(w * 0.3, w), Vector2(w * 0.6, w)), mono)
		else:
			PopFactoryArt.nozzle(ci, w, look == 0, tip)
			PopFactoryArt.bag(ci, Vector2(tip.x, r.end.y - r.size.y * 0.12), w * 0.9)


## The upgrade card follows the open floor: the middle floor's detail sells the
## next packing station (its picture, price and packs a minute now > next).
func card_offer() -> Dictionary:
	# Step 26: a chosen machine place sells its machine; a chosen machine, its next tier.
	if rules != null and sel_machine >= 0:
		var km: Dictionary = rules.machine(sel_machine)
		if not km.is_empty() and String(km["type"]) == "cooker" and int(km.get("kernels", 0)) * 2 < int(rules.catalog("cooker").get("kernel_buffer", 5)):
			# Step 28: a hungry kettle's card refills its kernels (no hopper does it for it).
			return {"key": "refill", "stage": 0, "price": int(rules.refill_cost(km)), "now": int(km.get("kernels", 0)), "next": int(rules.catalog("cooker").get("kernel_buffer", 5)), "prefix": "",
				"art": Callable(self, "_card_machine").bind("cooker")}
	if rules != null and not sel_slot.is_empty():
		var type := _slot_type(String(sel_slot["floor"]))
		return {"key": "build_" + type, "stage": 0, "price": int(rules.build_cost(type)), "now": 0, "next": _per_min(type, 0), "prefix": "+",
			"art": Callable(self, "_card_machine").bind(type)}
	if rules != null and sel_machine >= 0 and not (rules.machine(sel_machine) as Dictionary).is_empty():
		var m: Dictionary = rules.machine(sel_machine)
		var c := int(rules.machine_upgrade_cost(m))
		return {"key": "machine_up", "stage": int(m["tier"]) + 1, "price": c, "now": _per_min(String(m["type"]), int(m["tier"])),
			"next": _per_min(String(m["type"]), int(m["tier"]) + 1) if c >= 0 else -1, "prefix": "+", "art": Callable(self, "_card_machine").bind(String(m["type"]))}
	if rules != null and selected == TOP and rules.station_open("sign"):
		# Step 22: the shop's card sells the next sign -- visitors in ten minutes, now > next.
		var st := int(rules.get("sign_tier"))
		var sc := int(rules.sign_cost())
		return {"key": "sign", "stage": st + 1, "price": sc, "now": int(round(600000.0 / rules.mean_wait_ms(st))),
			"next": int(round(600000.0 / rules.mean_wait_ms(st + 1))) if sc >= 0 else -1, "prefix": "", "art": Callable(self, "_card_sign")}
	if rules == null or selected != MID or not rules.station_open("packer"):
		return {}
	var tier := int(rules.get("packer_tier"))
	var cost := int(rules.packer_cost())
	var now := int(round(rules.packs_per_min(tier)))
	var nxt := int(round(rules.packs_per_min(tier + 1))) if cost >= 0 else -1
	return {"key": "packer", "stage": tier + 1, "price": cost, "now": now, "next": nxt, "prefix": "",
		"art": Callable(self, "_card_art")}


func card_command() -> Dictionary:
	var key := String(card_offer().get("key", ""))
	if key == "refill":
		return {"type": "refill", "id": sel_machine}
	if key.begins_with("build_"):
		return {"type": "build", "machine": key.trim_prefix("build_"), "slot": int(sel_slot["k"]), "floor": String(sel_slot["floor"])}
	if key == "machine_up":
		return {"type": "upgrade_machine", "id": sel_machine}
	match key:
		"packer":
			return {"type": "buy_packer"}
		"sign":
			return {"type": "buy_sign"}
	return {"type": "buy"}


func _card_sign(ci: CanvasItem, foot: Vector2, h: float, stage: int, sil: Color) -> void:
	var tiers: Array = rules.economy.table("factory")["sign"]
	var t: Dictionary = tiers[clampi(stage, 0, tiers.size() - 1)]
	PopFactoryArt.shop_sign(ci, Rect2(foot - Vector2(h * 0.5, h * 0.7), Vector2(h, h * 0.58)), int(t["look"]), sil)


func _card_art(ci: CanvasItem, foot: Vector2, h: float, stage: int, sil: Color) -> void:
	var tiers: Array = rules.economy.table("factory")["packer"]
	var t: Dictionary = tiers[clampi(stage, 0, tiers.size() - 1)]
	_station_picture(ci, foot, h * 0.8, int(t["look"]), int(t["per_cycle"]), sil)


func _ensure_nozzles() -> void:
	if rules == null:
		return
	var n := _heads()
	var key := "%d|%s|%d" % [int(rules.get("packer_tier")), size, n]
	if key == _nozzle_key:
		return
	_nozzle_key = key
	for z in nozzles:
		z.queue_free()
	nozzles.clear()
	for i in n:
		var z := _new_actor(Actor.NOZZLE, -1 - i)
		z.size_px = _bag_px() * 0.9
		z.scoop = int(rules.packer()["look"]) == 0
		z.position = _head_tip(i, n)
		nozzles.append(z)


## The fill of every pack in progress, by the model's clock: the bag indexes in
## (0-20%), one puff falls per real portion (20-70%), the nozzle presses down
## and seals it (72-90%). The model already moved the portions; this shows it.
func _step_station(delta: float) -> void:
	if rules == null:
		return
	_ensure_nozzles()
	var n := nozzles.size()
	var press: Array[float] = []
	press.resize(n)
	press.fill(0.0)
	for pid in filling.keys():
		var f: Dictionary = filling[pid]
		var k := clampf(float(rules.now_ms - int(f["t0"])) / maxf(1.0, float(f["ms"])), 0.0, 1.0)
		var h := clampi(int(f["head"]), 0, maxi(0, n - 1))
		var bag: Node2D = f["bag"]
		var foot := _head_foot(h, maxi(1, n))
		if k < 0.2 and not reduced_motion:
			var e := k / 0.2
			bag.position = _entry_foot().lerp(foot, e * e * (3.0 - 2.0 * e))
		else:
			bag.position = foot if k >= 0.1 or not reduced_motion else _entry_foot()
		var size_n := int(f["size"])
		while int(f["dropped"]) < size_n and k >= 0.2 + 0.5 * (float(f["dropped"]) + 0.5) / float(size_n):
			var puff := _new_actor(Actor.LOT, int(pid))
			puff.size_px = _bag_px() * 0.22
			puff.recipe = String((f["bag"] as Node2D).get("recipe"))
			var tip := _head_tip(h, maxi(1, n))
			var mouth := foot - Vector2(0, _bag_px() * 1.35)
			puff.start(PackedVector2Array([tip, mouth]), 0.22, reduced_motion)
			(f["puffs"] as Array).append(puff)
			f["dropped"] = int(f["dropped"]) + 1
		var still: Array = []
		for puff: Node2D in f["puffs"]:
			puff.step(delta)
			if puff.done or k >= 0.81:
				puff.queue_free()
				f["landed"] = int(f["landed"]) + 1
				bag.fill = int(f["landed"])
				bag.queue_redraw()
				_sound("pop_1", 1.5 + 0.1 * float(f["landed"]), -16.0)
			else:
				still.append(puff)
		f["puffs"] = still
		if k >= 0.72 and k < 0.9 and h < n:
			press[h] = maxf(press[h], sin(PI * (k - 0.72) / 0.18) * _bag_px() * 0.55)
		if not bool(f["sealed"]) and k >= 0.81:
			f["sealed"] = true
			bag.open = false
			bag.queue_redraw()
			_sound("clink", 1.25, -10.0)
	var idle := String(rules.packer_state()) != "run" and not reduced_motion
	for i in n:
		var bob := sin(_clock * 2.2 + i) * 2.5 if idle else 0.0
		nozzles[i].position = _head_tip(i, n) + Vector2(0, press[i] + bob)
	# The status icon: redrawn when the state changes, bobbing by position.
	var st := String(rules.packer_state())
	if st != _status:
		_status = st
		status_node.queue_redraw()
	var anchor := _status_anchor(st)
	status_node.position = anchor + Vector2(0, (sin(_clock * 3.0) * 3.0) if not reduced_motion else 0.0)


func _status_anchor(st: String) -> Vector2:
	var s := _station_rect()
	if st == "starved":
		return _bin_top() + Vector2(0, -_bag_px() * 0.9)
	return Vector2(s.end.x + _bag_px() * 0.45, s.position.y + s.size.y * 0.18)


## Starved: a grey puff in a dashed ring over the raw bin (it needs popcorn).
## Blocked: a red no-entry sign by the station's output (the shelf is full).
func _draw_status(ci: CanvasItem) -> void:
	var r := _bag_px() * 0.55
	match _status:
		"starved":
			ci.draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 0.85))
			for q in 12:
				var a0 := TAU * q / 12.0
				ci.draw_arc(Vector2.ZERO, r, a0, a0 + TAU / 24.0, 4, PopTokens.SKY, 3.0)
			ci.draw_circle(Vector2(-r * 0.2, r * 0.05), r * 0.3, Color(0.75, 0.75, 0.78))
			ci.draw_circle(Vector2(r * 0.22, 0), r * 0.28, Color(0.75, 0.75, 0.78))
			ci.draw_circle(Vector2(0, -r * 0.25), r * 0.28, Color(0.8, 0.8, 0.83))
		"blocked":
			ci.draw_circle(Vector2.ZERO, r, PopTokens.WARN)
			ci.draw_arc(Vector2.ZERO, r, 0, TAU, 20, PopPalette.INK, 2.5)
			ci.draw_rect(Rect2(Vector2(-r * 0.6, -r * 0.16), Vector2(r * 1.2, r * 0.32)), Color.WHITE)


## Step 20: the middle floor's numbers -- heads, seconds a cycle, packs a minute
## (now > next), and how the station has spent its time: working, starved
## (blue), blocked by a full shelf (red), measured by the model.
func _draw_packer_numbers(ci: CanvasItem, d: Rect2) -> void:
	if rules == null:
		return
	var tier := int(rules.get("packer_tier"))
	var top := int(rules.packer_cost()) < 0
	var now: Dictionary = rules.packer(tier)
	var nxt: Dictionary = rules.packer(tier + 1)
	var font := ThemeDB.fallback_font
	var fs := int(clampf(d.size.x * 0.1, 18.0, 30.0))
	var rows := [["heads", str(int(now["per_cycle"])), str(int(nxt["per_cycle"])), int(nxt["per_cycle"]) > int(now["per_cycle"])],
		["clock", "%.1f" % (float(now["ms"]) / 1000.0), "%.1f" % (float(nxt["ms"]) / 1000.0), int(nxt["ms"]) < int(now["ms"])],
		["rate", str(int(round(rules.packs_per_min(tier)))), str(int(round(rules.packs_per_min(tier + 1)))), not top]]
	var y := d.position.y + fs * 1.3
	for row: Array in rows:
		var ic := Vector2(d.position.x + fs * 1.1, y - fs * 0.35)
		match String(row[0]):
			"heads":
				PopFactoryArt.nozzle(ci, fs * 0.6, false, ic + Vector2(0, fs * 0.4))
			"clock":
				ci.draw_arc(ic, fs * 0.42, 0, TAU, 20, PopPalette.INK, 3.0)
				ci.draw_line(ic, ic + Vector2(0, -fs * 0.3), PopPalette.INK, 3.0)
				ci.draw_line(ic, ic + Vector2(fs * 0.22, 0), PopPalette.INK, 3.0)
			"rate":
				PopFactoryArt.bag(ci, ic + Vector2(0, fs * 0.45), fs * 0.55)
		var x := d.position.x + fs * 2.0
		ci.draw_string(font, Vector2(x, y), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopPalette.INK)
		if not top:
			var x2 := x + fs * 2.4
			ci.draw_string(font, Vector2(x2, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PopPalette.INK, 0.5))
			ci.draw_string(font, Vector2(x2 + fs * 0.9, y), String(row[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopTokens.OK if bool(row[3]) else Color(PopPalette.INK, 0.45))
		y += fs * 1.35
	# Time spent: working / starved / blocked (a bar, measured since the shop opened).
	var flow := maxf(1.0, float(rules.get("flow_ms")))
	var st: Dictionary = rules.get("stats")
	var starved := float(st["packer_starved_ms"]) / flow
	var blocked := float(st["packer_blocked_ms"]) / flow
	var bar := Rect2(Vector2(d.position.x + fs * 0.6, y - fs * 0.6), Vector2(d.size.x - fs * 1.2, fs * 0.5))
	ci.draw_rect(bar, PopTokens.OK)
	ci.draw_rect(Rect2(Vector2(bar.end.x - bar.size.x * (starved + blocked), bar.position.y), Vector2(bar.size.x * starved, bar.size.y)), PopTokens.SKY)
	ci.draw_rect(Rect2(Vector2(bar.end.x - bar.size.x * blocked, bar.position.y), Vector2(bar.size.x * blocked, bar.size.y)), PopTokens.WARN)
	ci.draw_rect(bar, PopPalette.INK, false, 2.0)


# -- Step 21: the shop --------------------------------------------------------

## The bell hangs over the queue's far end; it swings in the last 1.5 s before
## the next customer walks in (the model's seeded arrival time) -- anticipation
## without a timer or words.
func _step_bell() -> void:
	if rules == null:
		return
	var r := floor_rect(TOP)
	# Under the awning's right end (clear of the news paper in the corner).
	var at := Vector2(r.end.x - 108, r.position.y + 14 + r.size.y * 0.12 + _head_px() * 0.4)
	if bell_node.position != at:
		bell_node.position = at
		bell_node.queue_redraw()
	var soon := int(rules.get("next_arrival_ms")) - int(rules.get("flow_ms"))
	var swing := soon >= 0 and soon < 1500
	if reduced_motion:
		bell_node.rotation = 0.2 if swing else 0.0
	else:
		bell_node.rotation = sin(_clock * 14.0) * 0.35 if swing else move_toward(bell_node.rotation, 0.0, 0.05)


## Whether the bell is swinging now (for the tests).
func bell_swinging() -> bool:
	return absf(bell_node.rotation) > 0.01


## Step 22: the shop's numbers -- visitors a minute and the expected wait (now >
## next), the spread of the wait (its practical limits, a bar from min to max
## seconds), the counter's lanes and the queue's places.
func _draw_sign_numbers(ci: CanvasItem, d: Rect2) -> void:
	if rules == null:
		return
	var st := int(rules.get("sign_tier"))
	var top := int(rules.sign_cost()) < 0
	var now: Dictionary = rules.shop_sign(st)
	var nxt: Dictionary = rules.shop_sign(st + 1)
	var font := ThemeDB.fallback_font
	var fs := int(clampf(d.size.x * 0.1, 18.0, 30.0))
	var rows := [["people", "%.1f" % (60000.0 / rules.mean_wait_ms(st)), "%.1f" % (60000.0 / rules.mean_wait_ms(st + 1)), not top],
		["clock", "%.1f" % (rules.mean_wait_ms(st) / 1000.0), "%.1f" % (rules.mean_wait_ms(st + 1) / 1000.0), not top],
		["lanes", str(int(now["lanes"])), str(int(nxt["lanes"])), int(nxt["lanes"]) > int(now["lanes"])]]
	var y := d.position.y + fs * 1.3
	for row: Array in rows:
		var ic := Vector2(d.position.x + fs * 1.1, y - fs * 0.35)
		match String(row[0]):
			"people":
				PopFactoryArt.customer(ci, ic + Vector2(0, fs * 0.5), fs * 0.24, CUSTOMER_COLOURS[0], SKIN[0])
			"clock":
				ci.draw_arc(ic, fs * 0.42, 0, TAU, 20, PopPalette.INK, 3.0)
				ci.draw_line(ic, ic + Vector2(0, -fs * 0.3), PopPalette.INK, 3.0)
				ci.draw_line(ic, ic + Vector2(fs * 0.22, 0), PopPalette.INK, 3.0)
			"lanes":
				for q in 2:
					PopMachineArt._round_rect(ci, Rect2(ic + Vector2(-fs * 0.45, -fs * 0.3 + q * fs * 0.38), Vector2(fs * 0.9, fs * 0.22)), 3, PopTokens.MACHINE)
		var x := d.position.x + fs * 2.0
		ci.draw_string(font, Vector2(x, y), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopPalette.INK)
		if not top:
			var x2 := x + fs * 2.4
			ci.draw_string(font, Vector2(x2, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PopPalette.INK, 0.5))
			ci.draw_string(font, Vector2(x2 + fs * 0.9, y), String(row[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopTokens.OK if bool(row[3]) else Color(PopPalette.INK, 0.45))
		y += fs * 1.35
	# The spread: where the next customer can come, from the shortest to the longest wait (now, and next below it).
	var full := 20000.0
	var bar := Rect2(Vector2(d.position.x + fs * 0.6, y - fs * 0.7), Vector2(d.size.x - fs * 1.2, fs * 0.36))
	ci.draw_rect(bar, Color(PopPalette.INK, 0.08))
	for j in (1 if top else 2):
		var t: Dictionary = now if j == 0 else nxt
		var a := bar.position.x + bar.size.x * float(t["min_ms"]) / full
		var b := bar.position.x + bar.size.x * float(t["max_ms"]) / full
		var yy := bar.position.y + j * fs * 0.45
		ci.draw_rect(Rect2(Vector2(a, yy), Vector2(b - a, fs * 0.3)), PopPalette.GOLD if j == 0 else PopTokens.OK)
		ci.draw_circle(Vector2(bar.position.x + bar.size.x * float(t["mode_ms"]) / full, yy + fs * 0.15), fs * 0.12, PopPalette.INK)


# -- Step 23: seeing the bottleneck without a spreadsheet ------------------------

const CUE_FLOOR := {"production": LOW, "packaging": MID, "demand": TOP, "service": TOP}


func _step_cues() -> void:
	if rules == null:
		return
	var b := String(rules.bottleneck())
	var ck := "%s|%s" % [b, size]   # (and on a resize: drawn before the layout, it was drawn at nothing)
	if ck != _cue_key:
		_cue_key = ck
		_cue = b
		cue_node.queue_redraw()
	cue_node.modulate.a = (0.45 + 0.35 * sin(_clock * 3.0)) if not reduced_motion else 0.7
	cue_node.visible = CUE_FLOOR.has(_cue)
	var show := _hover if _hover >= 0 else selected
	var key := "%d|%s|%s|%d|%d" % [show, size, rules.get("recent")["lots"].size() + rules.get("recent")["packs"].size() * 1000 + rules.get("recent")["sales"].size() * 1000000,
		rules.bin_portions() + (rules.get("shelf") as Array).size() * 100, (rules.get("queue") as Array).size()]
	if key != _stats_key:
		_stats_key = key
		stats_node.queue_redraw()


## A soft amber outline round the floor that holds things back.
func _draw_cue(ci: CanvasItem) -> void:
	if not CUE_FLOOR.has(_cue):
		return
	# Coral, not gold: the floors' own edges and the selection are gold.
	var r := floor_rect(int(CUE_FLOOR[_cue])).grow(-7)
	var pts := PopMachineArt.round_rect_points(r, PopTokens.R_FLOOR - 5)
	pts.append(pts[0])
	ci.draw_polyline(pts, PopTokens.WARN.lerp(Color(1.0, 0.45, 0.35), 0.4), 8.0, true)


## By the hovered (or open) floor's badge: what it finished in the last minute
## (a clock and a number) and what waits after it (a stack and a number) --
## lots popped and portions in the bin, packs sealed and packs on the shelf,
## sales and people in the queue.
func _draw_stage_numbers(ci: CanvasItem) -> void:
	var i := _hover if _hover >= 0 else selected
	if rules == null or i < 0:
		return
	var b := badge_rect(i)
	var rate := int(rules.per_min(["sales", "packs", "lots"][i]))
	var backlog: int = [(rules.get("queue") as Array).size(), (rules.get("shelf") as Array).size(), int(rules.bin_portions())][i]
	var font := ThemeDB.fallback_font
	var fs := int(clampf(b.size.y * 0.32, 14.0, 22.0))
	var p := Vector2(b.end.x + 6, b.position.y + b.size.y * 0.5 - fs * 0.75)
	var pill := Rect2(p, Vector2(fs * 5.2, fs * 1.5))
	PopMachineArt._round_rect(ci, pill, fs * 0.6, Color(1, 1, 1, 0.82))
	var c := p + Vector2(fs * 0.7, fs * 0.75)
	ci.draw_arc(c, fs * 0.38, 0, TAU, 16, Color(PopPalette.INK, 0.7), 2.0)
	ci.draw_line(c, c + Vector2(0, -fs * 0.26), Color(PopPalette.INK, 0.7), 2.0)
	ci.draw_string(font, c + Vector2(fs * 0.55, fs * 0.36), str(rate), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PopPalette.INK, 0.8))
	var s := p + Vector2(fs * 3.0, fs * 0.75)
	for k in 3:
		ci.draw_rect(Rect2(s + Vector2(-fs * 0.35, fs * 0.25 - k * fs * 0.22), Vector2(fs * 0.7, fs * 0.16)), Color(PopPalette.INK, 0.6))
	ci.draw_string(font, s + Vector2(fs * 0.5, fs * 0.36), str(backlog), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PopPalette.INK, 0.8))


## The shop's sign on the top floor (where its upgrade flourishes).
func _sign_rect() -> Rect2:
	var r := floor_rect(TOP)
	return Rect2(Vector2(r.position.x + r.size.x * 0.08, r.position.y + r.size.y * 0.3), Vector2(r.size.y * 0.42, r.size.y * 0.32))


# -- Step 26: machine places, machines, choosing and controlling them -----------

## A floor's k-th machine place: the kitchen's beside the ring (two columns), the
## packing floor's above the shelf, the shop's by the door.
func slot_rect(floor: String, k: int) -> Rect2:
	# Step 33: asked for every machine every frame (nodes, motion, input): kept for the frame.
	var ck := "%s%d" % [floor, k]
	if _slot_cache.has(ck):
		return _slot_cache[ck]
	var out := _slot_rect(floor, k)
	_slot_cache[ck] = out
	return out


var _slot_cache := {}


func _slot_rect(floor: String, k: int) -> Rect2:
	match floor:
		"kitchen":
			if dense("kitchen"):
				return _kitchen_cell(k)
			var r := floor_rect(LOW)
			var left := machine_centre().x + ring_radius() + machine_size() * 0.09
			var right := r.end.x - 12
			var rows := maxi(1, ceili(float(rules.slots("kitchen")) / 2.0)) if rules else 2
			var w := minf(((r.size.y - 28.0) / rows - 8.0) * 0.82, (right - left - 10) / 2.0)
			var h := w / 0.82
			return Rect2(Vector2(left + (k % 2) * (w + 10), r.position.y + 12 + (k / 2) * (h + 8)), Vector2(w, h))
		"packing":
			if dense("packing"):
				# Step 33: one row along the floor's bottom, a gap between lines.
				var st := _pack_strip()
				var groups := _line_groups("packing")
				var n := int(rules.slots("packing"))
				var gap := 4.0
				var w := minf((st.size.x - gap * (n - 1) - LINE_GAP * (groups.size() - 1)) / n, st.size.y * 0.82)
				var gi := 0
				var acc := 0
				while gi < groups.size() - 1 and k >= acc + int(groups[gi]):
					acc += int(groups[gi])
					gi += 1
				return Rect2(Vector2(st.position.x + k * (w + gap) + gi * LINE_GAP, st.end.y - w / 0.82), Vector2(w, w / 0.82))
			var r := floor_rect(MID)
			var x0 := r.position.x + r.size.x * 0.62
			var x1 := tube_rect().position.x - 16
			var w := (x1 - x0) / float(maxi(1, int(rules.slots("packing")) if rules else 3)) - 6.0
			return Rect2(Vector2(x0 + k * (w + 6.0), r.position.y + r.size.y * 0.06), Vector2(w, r.size.y * 0.28))
		"shop":
			# Step 31: four places in one row at the counter's right end -- below the
			# news button (top right), right of the lanes.
			var r := floor_rect(TOP)
			var hp := _head_px()
			var w := hp * 1.6
			var bottom := counter_rect().position.y
			var h := w * 1.2
			if dense("shop"):
				# Step 33: a line a row -- the second above the first, under the news button.
				var per := int((rules.economy.table("factory")["slots"] as Dictionary)["shop"])
				var top := news_rect().end.y + 4.0
				h = minf(h, (bottom - top - 4.0) / 2.0)
				w = h / 1.2
				var row := k / per
				var col := k % per
				return Rect2(Vector2(r.end.x - hp * 1.2 - (col + 1) * w * 1.08, bottom - h - row * (h + 4.0)), Vector2(w, h))
			var x := r.end.x - hp * 1.2 - (k + 1) * w * 1.08
			return Rect2(Vector2(x, bottom - h), Vector2(w, h))
	return Rect2()


func _machine_buttons() -> Dictionary:
	var m: Dictionary = rules.machine(sel_machine) if rules else {}
	if m.is_empty():
		return {"pause": Rect2(), "sell": Rect2()}
	var r := slot_rect(String(m["floor"]), int(m["slot"]))
	var s := clampf(r.size.x * 0.42, 28.0, 44.0)
	return {"pause": Rect2(Vector2(r.position.x - s * 0.2, r.end.y - s * 0.6), Vector2(s, s)),
		"sell": Rect2(Vector2(r.end.x - s * 0.8, r.end.y - s * 0.6), Vector2(s, s))}


func _clear_machine_selection() -> void:
	if sel_machine >= 0 or not sel_slot.is_empty():
		sel_machine = -1
		sel_slot = {}
		command.emit("select_machine", {"type": "select_machine", "id": -1})
		detail_layer.queue_redraw()


## A press on a machine place, a machine or its buttons; true when it was one.
func _machine_press(p: Vector2) -> bool:
	if rules == null:
		return false
	# Step 32: the upkeep overview -- its button, and pause / resume everything.
	if not (rules.get("machines") as Array).is_empty() and overview_button_rect().has_point(p):
		overview = not overview
		if overview:
			_clear_machine_selection()
			selected = -1
		detail_layer.queue_redraw()
		return true
	if overview:
		# Step 33: a floor's next line, a machine's diagnostics -- the card stays open.
		var L := _ov_layout(detail_rect())
		for f: String in OV_FLOORS:
			if (L["lines"][f] as Rect2).has_point(p) and int(rules.line_cost(f)) >= 0:
				command.emit("buy_line", {"type": "buy_line", "floor": f})
				_slot_cache.clear()
				detail_layer.queue_redraw()
				return true
		for id: int in L["machines"]:
			if (L["machines"][id] as Rect2).has_point(p):
				ov_machine = -1 if ov_machine == id else id
				detail_layer.queue_redraw()
				return true
		if _pause_all_rect().has_point(p):
			var any_on := (rules.get("machines") as Array).any(func(x: Dictionary) -> bool: return String(x["state"]) != "paused")
			command.emit("pause_all", {"type": "pause_all", "paused": any_on})
			detail_layer.queue_redraw()
			return true
		if not detail_rect().has_point(p):
			overview = false
			detail_layer.queue_redraw()
	if not sel_slot.is_empty():
		var rs := _picker_rects(detail_rect())
		for i in rs.size():
			if (rs[i] as Rect2).has_point(p):
				sel_slot["pick"] = i
				_redraw_once = true
				detail_layer.queue_redraw()
				floor_layer.queue_redraw()
				return true
	if sel_machine >= 0:
		var b := _machine_buttons()
		var m: Dictionary = rules.machine(sel_machine)
		if _group_rect(detail_rect()).has_point(p) and not m.is_empty():
			var f := String(m["floor"])
			var any_on := (rules.get("machines") as Array).any(func(x: Dictionary) -> bool: return String(x["floor"]) == f and String(x["state"]) != "paused")
			command.emit("pause_floor", {"type": "pause_floor", "floor": f, "paused": any_on})
			return true
		if (b["pause"] as Rect2).has_point(p):
			command.emit("pause_machine", {"type": "pause_machine", "id": sel_machine, "paused": String(m["state"]) != "paused"})
			return true
		var fr := _flavor_rects(detail_rect())
		for f: String in fr.keys():
			if (fr[f] as Rect2).has_point(p):   # Step 34: coat this flavor from now on (a locked one clunks)
				command.emit("set_flavor", {"type": "set_flavor", "id": sel_machine, "flavor": f})
				_sound("clink" if rules.flavor_open(f) else "thud", 1.3, -10.0)
				detail_layer.queue_redraw()
				return true
		if (b["sell"] as Rect2).has_point(p):
			command.emit("sell_machine", {"type": "sell_machine", "id": sel_machine})
			if rules.machine(sel_machine).is_empty():
				_clear_machine_selection()
			return true
	for f: String in FLOOR_NAME:
		for k in int(rules.slots(f)):
			if not slot_rect(f, k).has_point(p):
				continue
			var m: Dictionary = rules.machine_at(f, k)
			if m.is_empty() and not rules.station_open(String(MACHINE_OF[f])):
				return false   # a locked place is part of the floor
			selected = int(FLOOR_INDEX[f])
			if m.is_empty():
				sel_slot = {"floor": f, "k": k}
				sel_machine = -1
			else:
				sel_machine = int(m["id"])
				sel_slot = {}
			command.emit("select_machine", {"type": "select_machine", "id": sel_machine})
			_redraw_once = true
			detail_layer.queue_redraw()
			return true
	return false


func _per_min(type: String, tier: int) -> int:
	var t: Dictionary = rules._machine_tier_of(type, tier)
	if type == "M16":   # Step 29: the rotary popper makes portions itself
		return int(round(60000.0 / float(t.get("cycle_ms", 2500)) * float((rules.catalog("M16").get("contract", {}) as Dictionary).get("portions", 2))))
	if type in ["P05", "P06"]:   # Step 34: a coater's portions a minute, for its flavor at this tier
		var m: Dictionary = rules.machine(sel_machine) if sel_machine >= 0 else {}
		var fl := String(m.get("flavor", "")) if not m.is_empty() else String((rules.coater_flavors(type) + [""])[0])
		var batch := float(t.get("batch", 4))
		var ms := float(rules.flavor(fl).get("coat_ms_per_portion", 1000)) * batch * float(t.get("ms_factor", 1.0))
		return int(round(60000.0 * batch / maxf(1.0, ms)))
	if rules.forty().has(type) and not rules.catalog(type).has("cycle_ms") and type.begins_with("M"):
		return 0   # a device does not make goods itself; its effect is in the detail
	match type:
		"cooker":
			var a: Dictionary = rules.catalog("cooker")
			return int(round(60000.0 / float(t.get("cycle_ms", 6000)) * float(rules.auto_attempt()["portions"])))
		"bagger":
			return int(round(60000.0 / float(t.get("cycle_ms", 5000))))
		"kiosk":
			return int(round(60000.0 / float(t.get("service_ms", 2500))))
	return 0


func _draw_machines(ci: CanvasItem) -> void:
	if rules == null:
		return
	_draw_overview_button(ci)
	_draw_line_paths(ci)
	for f: String in FLOOR_NAME:
		var type := String(MACHINE_OF[f])
		var open: bool = rules.station_open(type)
		for k in int(rules.slots(f)):
			var r := slot_rect(f, k)
			var m: Dictionary = rules.machine_at(f, k)
			if m.is_empty():
				if not open and f != "kitchen":
					continue   # one choice at a time: a floor's places appear when its machine opens
				PopFactoryArt.dashed_slot(ci, r)
				if open:
					var ghost := _slot_type(f)
					if ghost != type and rules.forty().has(ghost):
						var ge: Dictionary = rules.forty()[ghost]
						PopFactoryArt.catalog_icon(ci, r.grow(-6), ge["parts"], String(ge["group"]), Color(1, 1, 1, 0.55))
					else:
						PopFactoryArt.machine_icon(ci, r.grow(-6), type, 0, Color(1, 1, 1, 0.55))
				else:
					var lk := r.get_center()
					PopMachineArt._round_rect(ci, Rect2(lk - Vector2(10, 4), Vector2(20, 16)), 3, Color(PopPalette.INK, 0.35))
					ci.draw_arc(lk + Vector2(0, -5), 7, PI, TAU, 10, Color(PopPalette.INK, 0.35), 3.0)
				if sel_slot.get("floor", "") == f and int(sel_slot.get("k", -1)) == k:
					var pts := PopMachineArt.round_rect_points(r.grow(3), PopTokens.R_MACHINE)
					pts.append(pts[0])
					ci.draw_polyline(pts, PopPalette.GOLD, 4.0, true)
				continue


## Step 33: each machine's node -- made when it is built, freed when it is sold,
## redrawn only when what it shows changes.
func _step_machine_nodes() -> void:
	if rules == null:
		return
	var alive := {}
	for m: Dictionary in rules.get("machines"):
		var id := int(m["id"])
		alive[id] = true
		if not _mnodes.has(id):
			# Its picture (a viewport texture: premultiplied alpha) and, above it, what
			# changes -- the state badge, the kernels, the selection -- drawn as vectors.
			var n := Node2D.new()
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
			n.material = mat
			n.draw.connect(func() -> void: _draw_machine_pic(n, id))
			var over := Node2D.new()
			over.name = "Over"
			over.draw.connect(func() -> void:
				redraws["machines"] = int(redraws["machines"]) + 1
				_draw_machine_node(over, id))
			n.add_child(over)
			machine_layer.add_child(n)
			_mnodes[id] = n
		var node: Node2D = _mnodes[id]
		var r := slot_rect(String(m["floor"]), int(m["slot"]))
		var key := "%s|%d|%d|%s|%s|%s|%s" % [m["state"], int(m["tier"]), int(m.get("kernels", 0)), id == sel_machine or id == ov_machine, r, _icon_texture(String(m["type"]), int(m["tier"]), r.grow(-4).size, String(m["floor"])) != null, m.get("flavor", "")]
		if String(node.get_meta("key", "")) != key:
			node.set_meta("key", key)
			node.queue_redraw()
			(node.get_node("Over") as Node2D).queue_redraw()
	for id: int in _mnodes.keys():
		if not alive.has(id):
			(_mnodes[id] as Node2D).queue_free()
			_mnodes.erase(id)


## Step 33: the lines' paths -- a belt under each kitchen line to the lift's tube (its
## lots ride it), a belt under each packing line's places.
func _draw_line_paths(ci: CanvasItem) -> void:
	if rules == null:
		return
	if dense("kitchen"):
		var groups := _line_groups("kitchen")
		var k := 0
		var tube_x := tube_rect().get_center().x
		for g: int in groups:
			var last := slot_rect("kitchen", k + g - 1)
			var first := slot_rect("kitchen", k)
			var y := last.end.y + 3.0
			var belt := Rect2(Vector2(first.position.x - 4, y), Vector2(tube_x - first.position.x + 4, 5))
			PopFactoryArt.steel(ci, belt, 2.5)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(tube_x - 10, y - 4), Vector2(tube_x - 2, y + 2.5), Vector2(tube_x - 10, y + 9)]), PopTokens.STEEL_DEEP)
			k += g
	if dense("packing"):
		var groups := _line_groups("packing")
		var k := 0
		for g: int in groups:
			var a := slot_rect("packing", k)
			var b := slot_rect("packing", k + g - 1)
			PopFactoryArt.steel(ci, Rect2(Vector2(a.position.x - 3, a.end.y - 2), Vector2(b.end.x - a.position.x + 6, 5)), 2.5)
			k += g


## The y of the belt under a kitchen place's line (dense kitchen), or -1.
func _kitchen_belt_y(slot: int) -> float:
	if not dense("kitchen"):
		return -1.0
	var k := 0
	for g: int in _line_groups("kitchen"):
		if slot < k + g:
			return slot_rect("kitchen", k + g - 1).end.y + 5.5
		k += g
	return -1.0


func _draw_machine_pic(ci: CanvasItem, id: int) -> void:
	var m: Dictionary = rules.machine(id) if rules else {}
	if m.is_empty():
		return
	var r := slot_rect(String(m["floor"]), int(m["slot"]))
	var tex := _icon_texture(String(m["type"]), int(m["tier"]), r.grow(-4).size, String(m["floor"]))
	if tex != null:
		ci.draw_texture_rect(tex, r, false)


## The cached picture of a machine (its plate, its icon, its tier dots) at this size, or
## null while it is being drawn (the first frames: the node draws it as vectors).
func _icon_texture(type: String, tier: int, inner: Vector2, floor: String) -> Texture2D:
	var k := clampf(snappedf(get_global_transform_with_canvas().get_scale().x * 1.5, 0.25), 1.0, 3.0)
	var size := inner + Vector2(8, 8)
	var px := Vector2i(ceili(size.x * k), ceili(size.y * k))
	if px.x <= 0 or px.y <= 0:
		return null
	var key := "%s|%d|%d|%d|%s" % [type, tier, px.x, px.y, floor]
	if not _icon_cache.has(key):
		var vp := SubViewport.new()
		vp.size = px
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var n := Node2D.new()
		n.scale = Vector2(k, k)
		n.draw.connect(func() -> void: _draw_icon_plate(n, type, tier, Rect2(Vector2.ZERO, size), floor))
		vp.add_child(n)
		_icon_root.add_child(vp)
		_icon_cache[key] = {"vp": vp, "frame": Engine.get_frames_drawn()}
		if _icon_cache.size() > 160:   # a resized window leaves old sizes behind
			var old: String = _icon_cache.keys()[0]
			(_icon_cache[old]["vp"] as Node).queue_free()
			_icon_cache.erase(old)
	var e: Dictionary = _icon_cache[key]
	if Engine.get_frames_drawn() - int(e["frame"]) < 3:
		return null
	return (e["vp"] as SubViewport).get_texture()


func _draw_icon_plate(ci: CanvasItem, mtype: String, tier: int, r: Rect2, floor: String) -> void:
	PopMachineArt._round_rect(ci, r, PopTokens.R_MACHINE, Color(1, 1, 1, 0.45))
	if mtype.begins_with("M") or mtype.begins_with("P") or mtype.begins_with("S") or mtype.begins_with("U"):
		var e: Dictionary = rules.forty().get(mtype, {})
		PopFactoryArt.catalog_icon(ci, r.grow(-4), e.get("parts", ["box"]), String(e.get("group", "manufacturing")))
		for q in tier:
			ci.draw_circle(Vector2(r.position.x + 8 + q * 11, r.position.y + 8), 4.0, PopPalette.GOLD)
	else:
		PopFactoryArt.machine_icon(ci, r.grow(-4), String(MACHINE_OF[floor]), tier)


## Step 33: one machine, on its own node (redrawn when its state, tier, kernels or
## selection change -- not when another machine's do).
func _draw_machine_node(ci: CanvasItem, id: int) -> void:
	var m: Dictionary = rules.machine(id)
	if m.is_empty():
		return
	var r := slot_rect(String(m["floor"]), int(m["slot"]))
	var type := String(MACHINE_OF[String(m["floor"])])
	var mtype := String(m["type"])
	var tex := _icon_texture(mtype, int(m["tier"]), r.grow(-4).size, String(m["floor"]))
	if tex != null:
		pass   # its plate and picture: the parent node's texture (_draw_machine_pic)
	elif mtype.begins_with("M") or mtype.begins_with("P") or mtype.begins_with("S") or mtype.begins_with("U"):
		PopMachineArt._round_rect(ci, r, PopTokens.R_MACHINE, Color(1, 1, 1, 0.45))
		var e: Dictionary = rules.forty().get(mtype, {})
		PopFactoryArt.catalog_icon(ci, r.grow(-4), e.get("parts", ["box"]), String(e.get("group", "manufacturing")))
		for q in int(m["tier"]):
			ci.draw_circle(Vector2(r.position.x + 8 + q * 11, r.position.y + 8), 4.0, PopPalette.GOLD)
	else:
		PopMachineArt._round_rect(ci, r, PopTokens.R_MACHINE, Color(1, 1, 1, 0.45))
		PopFactoryArt.machine_icon(ci, r.grow(-4), type, int(m["tier"]))
	if mtype in ["cooker", "M16"]:
		# Step 28: its kernels, a gauge along the bottom (empty = it starves).
		var buf := float(rules.catalog("cooker").get("kernel_buffer", 5))
		var g := Rect2(Vector2(r.position.x + 6, r.end.y - 9), Vector2(r.size.x - 12, 5))
		ci.draw_rect(g, Color(PopPalette.INK, 0.15))
		ci.draw_rect(Rect2(g.position, Vector2(g.size.x * clampf(float(m.get("kernels", 0)) / buf, 0.0, 1.0), g.size.y)), Color(0.85, 0.62, 0.25))
	if mtype in ["P05", "P06"]:
		# Step 34: what it coats -- a kernel of its flavor in a white dot, top left.
		var fc := Vector2(r.position.x + r.size.x * 0.2, r.position.y + r.size.y * 0.22)
		ci.draw_circle(fc, r.size.x * 0.13, Color.WHITE)
		PopFactoryArt.flavor_popcorn(ci, fc, r.size.x * 0.11, String(m.get("flavor", "plain")))
	PopFactoryArt.state_badge(ci, Vector2(r.end.x - 9, r.position.y + 9), 8.0, String(m["state"]))
	if int(m["id"]) == sel_machine:
		var pts := PopMachineArt.round_rect_points(r.grow(3), PopTokens.R_MACHINE)
		pts.append(pts[0])
		ci.draw_polyline(pts, PopPalette.GOLD, 4.0, true)
		var b := _machine_buttons()
		var pr: Rect2 = b["pause"]
		ci.draw_circle(pr.get_center(), pr.size.x * 0.5, Color.WHITE)
		ci.draw_arc(pr.get_center(), pr.size.x * 0.5, 0, TAU, 20, PopPalette.INK, 2.0)
		if String(m["state"]) == "paused":   # a play triangle resumes
			var c := pr.get_center()
			var q := pr.size.x * 0.22
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-q * 0.7, -q), c + Vector2(q, 0), c + Vector2(-q * 0.7, q)]), PopTokens.OK)
		else:
			PopFactoryArt.state_badge(ci, pr.get_center(), pr.size.x * 0.32, "paused")
		var sr: Rect2 = b["sell"]
		ci.draw_circle(sr.get_center(), sr.size.x * 0.5, Color.WHITE)
		ci.draw_arc(sr.get_center(), sr.size.x * 0.5, 0, TAU, 20, PopPalette.INK, 2.0)
		PopMachineArt.draw_coin(ci, sr.get_center() + Vector2(0, 2), sr.size.x * 0.22)
		ci.draw_line(sr.get_center() + Vector2(-sr.size.x * 0.22, -sr.size.x * 0.24), sr.get_center() + Vector2(0, -sr.size.x * 0.36), PopPalette.INK, 2.5)
		ci.draw_line(sr.get_center() + Vector2(sr.size.x * 0.22, -sr.size.x * 0.24), sr.get_center() + Vector2(0, -sr.size.x * 0.36), PopPalette.INK, 2.5)


## The machine's detail: what it makes a minute (now > next tier), what it costs
## a minute to run, and whether its floor is what holds the factory back now
## (a green tick: it will help; grey: it will mostly wait) -- the cost against
## the gain before buying. Plus the floor's group pause.
func _draw_machine_detail(ci: CanvasItem, d: Rect2) -> void:
	var type := ""
	var tier := 0
	var m: Dictionary = {}
	if sel_machine >= 0:
		m = rules.machine(sel_machine)
		if m.is_empty():
			return
		type = String(m["type"])
		tier = int(m["tier"])
	else:
		type = _slot_type(String(sel_slot["floor"]))
		if true:
			# The picker: every machine of this floor that can be built now, the chosen one ringed.
			var choices := _floor_choices(String(sel_slot["floor"]))
			var rs := _picker_rects(d)
			for i in rs.size():
				var pr: Rect2 = rs[i]
				PopMachineArt._round_rect(ci, pr, 6, Color(1, 1, 1, 0.9))
				var cid := String(choices[i])
				if rules.forty().has(cid):
					PopFactoryArt.catalog_icon(ci, pr.grow(-3), rules.forty()[cid]["parts"], String(rules.forty()[cid]["group"]))
				else:
					PopFactoryArt.machine_icon(ci, pr.grow(-3), cid, 0)
				if cid == type:
					var pts := PopMachineArt.round_rect_points(pr.grow(2), 6)
					pts.append(pts[0])
					ci.draw_polyline(pts, PopPalette.GOLD, 3.0, true)
	var font := ThemeDB.fallback_font
	var fs := int(clampf(d.size.x * 0.1, 16.0, 28.0))
	var y := d.position.y + fs * 1.3
	var now := _per_min(type, tier) if not m.is_empty() else 0
	var nxt := _per_min(type, tier + 1 if not m.is_empty() else 0)
	var x := d.position.x + fs * 2.0
	var head := Rect2(Vector2(d.position.x + 4, y - fs), Vector2(fs * 1.6, fs * 1.4))
	if rules.forty().has(type):
		PopFactoryArt.catalog_icon(ci, head, rules.forty()[type]["parts"], String(rules.forty()[type]["group"]))
	else:
		PopFactoryArt.machine_icon(ci, head, type, 0)
	ci.draw_string(font, Vector2(x, y), str(now), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopPalette.INK)
	if nxt != now:
		ci.draw_string(font, Vector2(x + fs * 2.0, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PopPalette.INK, 0.5))
		ci.draw_string(font, Vector2(x + fs * 2.9, y), str(nxt), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopTokens.OK)
	y += fs * 1.4
	PopMachineArt.draw_coin(ci, Vector2(d.position.x + fs * 0.9, y - fs * 0.35), fs * 0.38)
	ci.draw_string(font, Vector2(x, y), "-%d" % int(rules.catalog(type)["upkeep_per_min"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopTokens.WARN)
	y += fs * 1.4
	var helps: bool = String(rules.bottleneck()) == String({"cooker": "production", "bagger": "packaging", "kiosk": "service"}.get(type, "production"))
	var c := Vector2(d.position.x + fs * 0.9, y - fs * 0.35)
	ci.draw_circle(c, fs * 0.42, PopTokens.OK if helps else Color(0.75, 0.75, 0.78))
	ci.draw_polyline(PackedVector2Array([c + Vector2(-fs * 0.2, 0), c + Vector2(-fs * 0.04, fs * 0.16), c + Vector2(fs * 0.22, -fs * 0.16)]), Color.WHITE, 3.0)
	if not m.is_empty():
		PopFactoryArt.state_badge(ci, Vector2(x + fs * 0.5, y - fs * 0.35), fs * 0.4, String(m["state"]))
		# The floor's group control: pause (or resume) every machine on this floor.
		var g := _group_rect(d)
		ci.draw_circle(g.get_center(), g.size.x * 0.5, Color.WHITE)
		ci.draw_arc(g.get_center(), g.size.x * 0.5, 0, TAU, 20, PopPalette.INK, 2.0)
		PopFactoryArt.state_badge(ci, g.get_center() + Vector2(-3, -3), g.size.x * 0.24, "paused")
		PopFactoryArt.state_badge(ci, g.get_center() + Vector2(4, 4), g.size.x * 0.24, "paused")
		if type in ["P05", "P06"]:
			_draw_flavor_chips(ci, d)


## Step 34: a coater's flavors on its card, right of the numbers under the floor's pause:
## each its kernel and its bag (the chosen one ringed gold; a locked one grey with a padlock).
func _flavor_rects(d: Rect2) -> Dictionary:
	var out := {}
	if rules == null or sel_machine < 0:
		return out
	var m: Dictionary = rules.machine(sel_machine)
	if m.is_empty() or not String(m["type"]) in ["P05", "P06"]:
		return out
	var fl: Array = rules.coater_flavors(String(m["type"]))
	var g := _group_rect(d)
	var cs := clampf(d.size.y * 0.3, 40.0, 72.0)
	var y := g.end.y + 10.0
	for i in fl.size():
		out[String(fl[i])] = Rect2(Vector2(d.end.x - 8 - (fl.size() - i) * (cs + 8), y), Vector2(cs, cs))
	return out


func _draw_flavor_chips(ci: CanvasItem, d: Rect2) -> void:
	var m: Dictionary = rules.machine(sel_machine)
	var rs := _flavor_rects(d)
	for f: String in rs.keys():
		var r: Rect2 = rs[f]
		var open := bool(rules.flavor_open(f))
		PopMachineArt._round_rect(ci, r, 8, Color(1, 1, 1, 0.95) if open else Color(0.85, 0.83, 0.8, 0.9))
		PopFactoryArt.sku_bag(ci, r.position + Vector2(r.size.x * 0.66, r.size.y * 0.9), r.size.x * 0.36, f)
		PopFactoryArt.flavor_popcorn(ci, r.position + Vector2(r.size.x * 0.3, r.size.y * 0.42), r.size.x * 0.16, f)
		if not open:   # a padlock
			var c := r.get_center()
			ci.draw_rect(Rect2(c - Vector2(r.size.x * 0.16, -r.size.y * 0.02), Vector2(r.size.x * 0.32, r.size.y * 0.24)), PopPalette.INK)
			ci.draw_arc(c + Vector2(0, r.size.y * 0.02), r.size.x * 0.1, PI, TAU, 10, PopPalette.INK, 3.0)
		if String(m.get("flavor", "")) == f:
			var pts := PopMachineArt.round_rect_points(r.grow(3), 9)
			pts.append(pts[0])
			ci.draw_polyline(pts, PopPalette.GOLD, 4.0, true)


func _group_rect(d: Rect2) -> Rect2:
	var s := clampf(d.size.x * 0.22, 30.0, 46.0)
	return Rect2(Vector2(d.end.x - s - 8, d.position.y + 8), Vector2(s, s))


func _card_machine(ci: CanvasItem, foot: Vector2, h: float, _stage: int, sil: Color, type: String) -> void:
	var r := Rect2(foot - Vector2(h * 0.45, h * 0.9), Vector2(h * 0.9, h * 0.9))
	if rules and rules.forty().has(type):
		var e: Dictionary = rules.forty()[type]
		PopFactoryArt.catalog_icon(ci, r, e["parts"], String(e["group"]), sil)
	else:
		PopFactoryArt.machine_icon(ci, r, type, 0, sil)


## A machine's moment, seen where it stands: a cooker's lot puffs out of it, a
## tuned cooker sparkles gold, an upgrade or a sale rings, a pause clicks.
func _machine_event(e: Dictionary) -> void:
	var d: Dictionary = e["data"]
	var m: Dictionary = rules.machine(int(d.get("machine", -1))) if rules else {}
	var at := slot_rect(String(m["floor"]), int(m["slot"])).get_center() if not m.is_empty() else machine_top()
	var s := machine_size() / 1500.0
	match String(e["type"]):
		"auto_lot":
			if not reduced_motion:
				fx.burst(at, 3, s, rng, PopPalette.CREAM if String(d.get("grade", "")) != "perfect" else PopPalette.GOLD, 0.6, 0.7)
			_sound("pop_1", 1.3, -18.0)
		"overheat":   # Step 29: the kitchen too hot -- a hiss, steam from every kettle
			_sound("hiss", 0.8, -10.0)
			if not reduced_motion:
				for k: Dictionary in rules.get("machines"):
					if String(k["type"]) in ["cooker", "M16"]:
						fx.burst(slot_rect("kitchen", int(k["slot"])).get_center(), 4, s, rng, Color(0.95, 0.95, 0.97), 0.5, 0.9)
			floor_layer.queue_redraw()
		"machine_assisted":
			if not reduced_motion:
				fx.sparkle(at, s * 1.6, rng, 4, 80.0)
			_sound("ding", 1.5, -10.0)
		"machine_upgraded":
			_sound("upgrade", 1.25)
			if not reduced_motion:
				fx.sparkle(at, s * 1.6, rng, 5, 90.0)
		"machine_sold":
			_sound("coin", 0.9, -6.0)
		"machine_paused":
			_sound("clink", 0.8 if bool(d.get("paused", true)) else 1.2, -10.0)
		"kernels_loaded":
			# Step 28: kernels fly from the hopper (or the card, by hand) to the kettle they fill.
			var k: Dictionary = rules.machine(int(d.get("kettle", -1)))
			if not k.is_empty():
				var to := slot_rect(String(k["floor"]), int(k["slot"])).get_center()
				var from := at if not m.is_empty() else to + Vector2(0, -60)
				var puff := _new_actor(Actor.LOT, -1)
				puff.size_px = _bag_px() * 0.18
				puff.start(PackedVector2Array([from, (from + to) * 0.5 + Vector2(0, -20), to]), 0.45, reduced_motion)
				_kernel_flights.append(puff)
	_redraw_once = true


# -- Step 28: the kitchen's devices on screen ------------------------------------

## Which machine an empty place would get: the shop and packing floors have one
## kind; the kitchen's picker (in the detail) chooses among the open ones.
func _slot_type(floor: String) -> String:
	if not floor in ["kitchen", "packing", "shop"]:
		return String(MACHINE_OF[floor])
	var choices := _floor_choices(floor)
	if choices.is_empty():
		return String(MACHINE_OF[floor])
	return String(choices[clampi(int(sel_slot.get("pick", 0)), 0, choices.size() - 1)])


func _kitchen_choices() -> Array:
	return _floor_choices("kitchen")


## The machines a floor's empty place can take now (Step 28: the kitchen; Step 30: the
## packing floor) -- its own machine first, then the open catalog devices that run.
func _floor_choices(floor: String) -> Array:
	var out: Array = []
	if rules == null:
		return out
	var own := String(MACHINE_OF[floor])
	if rules.station_open(own):
		out.append(own)
	var devices: Array = (rules.KITCHEN_DEVICES if floor == "kitchen" else (rules.PACKING_DEVICES if floor == "packing" else rules.SHOP_DEVICES)).duplicate()
	for u: String in rules.UTILITY_DEVICES:   # Step 32: support machines stand on any floor (the lift and the inspector on packing)
		if String(rules.FLOOR_OF[u]) in ["any", floor]:
			devices.append(u)
	for id: String in devices:
		if id == "U08" and not rules.parallel_lines():
			continue   # Step 33: the route balancer needs two packing lines
		if rules.station_open(id) and rules.catalog_buildable(id):
			out.append(id)
	return out


func _picker_rects(d: Rect2) -> Array:
	# Step 29: up to fifteen kitchen machines -- a grid in the panel's free part (right of
	# the numbers on a wide panel, below them on a tall one), as big as fits (<= 52 px).
	var out: Array = []
	var choices := _floor_choices(String(sel_slot.get("floor", "kitchen")))
	var n := choices.size()
	if n == 0:
		return out
	var fs := clampf(d.size.x * 0.1, 16.0, 28.0)
	var area := Rect2(Vector2(d.position.x + d.size.x * 0.36, d.position.y + 8), Vector2(d.size.x * 0.64 - 8, d.size.y - 16))
	if d.size.x < d.size.y * 1.5:
		area = Rect2(Vector2(d.position.x + 8, d.position.y + fs * 5.0), Vector2(d.size.x - 16, d.size.y - fs * 5.0 - 8))
	var best := 0.0
	var cols := n
	for rows in range(1, 6):
		var c := ceili(float(n) / rows)
		var sz := minf(52.0, minf(area.size.x / c, area.size.y / rows))
		if sz > best:
			best = sz
			cols = c
	for i in n:
		var col := i % cols
		var row := i / cols
		out.append(Rect2(area.position + Vector2(col * best, row * best), Vector2(best - 4, best - 4)))
	return out


## The moving part of each machine: a fan's blades and a motor's gear turn, oil
## drops and kernels fall, an eye blinks, an arm and a gauge's needle swing, a
## kettle's lid bobs -- only while it works (state run); still otherwise.
func _step_machine_motion(delta: float) -> void:
	if rules == null:
		return
	var alive := {}
	for m: Dictionary in rules.get("machines"):
		var id := int(m["id"])
		alive[id] = true
		var r := slot_rect(String(m["floor"]), int(m["slot"]))
		if not _motion.has(id):
			var n := Node2D.new()
			n.set_meta("type", String(m["type"]))
			n.set_meta("size", r.size.x)
			n.draw.connect(func() -> void: _draw_motion_part(n))
			actor_layer.add_child(n)
			_motion[id] = n
		var node: Node2D = _motion[id]
		if not is_equal_approx(float(node.get_meta("size")), r.size.x):
			node.set_meta("size", r.size.x)
			node.queue_redraw()
		var run := String(m["state"]) == "run" and not reduced_motion
		var t := _clock + id * 0.37
		var c := r.get_center()
		match String(m["type"]):
			"M08", "M04":
				node.position = c + Vector2(0, r.size.y * 0.12)
				if run:
					node.rotation += delta * (9.0 if String(m["type"]) == "M08" else 3.0)
			"M01", "M02":
				# Step 28: kernels trickle out of the hopper's spout; the oil drips from the
				# doser's nozzle into its cup (the silhouettes in PopFactoryArt.catalog_icon).
				var top := 0.76 if String(m["type"]) == "M01" else 0.66
				var fall := top + 0.12 * fmod(t * 1.6, 1.0) if run else top
				node.position = Vector2(c.x, r.position.y + r.size.y * fall)
			"M03":
				node.position = c + Vector2(0, r.size.y * 0.1)
				node.rotation = sin(t * 7.0) * 0.25 if run else 0.0
			"M05":
				node.position = c + Vector2(0, r.size.y * 0.1)
				node.scale = Vector2(1, 0.15 if run and fmod(t, 1.4) < 0.12 else 1.0)
			"M06":
				node.position = Vector2(r.position.x + r.size.x * 0.3, r.position.y + r.size.y * 0.4)
				node.rotation = -0.45 + 0.45 * sin(t * 3.0) if run else -0.45
			"cooker":
				node.position = Vector2(c.x, r.position.y + r.size.y * 0.2 - (absf(sin(t * 6.0)) * 3.0 if run else 0.0))
			# Step 29: the advanced kitchen moves only while it works, like the rest.
			"M09":   # the tray shakes; kernels hop on it
				node.position = Vector2(c.x + (sin(t * 38.0) * r.size.x * 0.025 if run else 0.0), r.position.y + r.size.y * 0.47)
			"M10":   # kernels run down the branches to one pot, then the other
				var k := fmod(t * 0.9, 1.0) if run else 0.0
				var side := -1.0 if fmod(floor(t * 0.9), 2.0) < 1.0 else 1.0
				node.position = Vector2(c.x + side * r.size.x * 0.3 * k, r.position.y + r.size.y * (0.3 + 0.32 * k))
				node.visible = run
			"M11":   # the beam sweeps the belt
				node.position = Vector2(c.x, r.position.y + r.size.y * 0.48)
				node.rotation = sin(t * 3.0) * 0.35 if run else 0.0
			"M13":   # the louvres breathe
				node.position = Vector2(c.x, r.position.y + r.size.y * 0.56)
				node.scale = Vector2(1, 0.55 + 0.45 * absf(sin(t * 2.2)) if run else 1.0)
			"M14":   # the coil glows
				node.position = Vector2(c.x, r.position.y + r.size.y * 0.64)
				node.modulate.a = 0.35 + 0.65 * absf(sin(t * 2.5)) if run else 0.25
			"M15":   # an arrow runs across the screen
				node.position = Vector2(r.position.x + r.size.x * (0.32 + 0.36 * fmod(t * 0.8, 1.0) if run else 0.5), r.position.y + r.size.y * 0.57)
			"M16":   # the drum turns
				node.position = Vector2(c.x, r.position.y + r.size.y * 0.55)
				if run:
					node.rotation += delta * 4.0
			# Step 30: the packing floor, moving only while it packs.
			"bagger":   # the nozzle presses into the bag
				node.position = Vector2(c.x, r.position.y + r.size.y * (0.3 + (0.08 * absf(sin(t * 2.4)) if run else 0.0)))
			"P01":   # a cup slides under the tube and on
				node.position = Vector2(r.position.x + r.size.x * (0.3 + 0.4 * fmod(t * 0.7, 1.0) if run else 0.5), r.position.y + r.size.y * 0.62)
				node.visible = run
			"P02":   # an open bag drops onto the chute
				node.position = Vector2(c.x, r.position.y + r.size.y * (0.62 + 0.22 * fmod(t * 0.9, 1.0) if run else 0.66))
				node.visible = run
			"P04":   # the pan dips and settles
				node.position = Vector2(c.x, r.position.y + r.size.y * (0.36 + (0.04 * absf(sin(t * 5.0)) if run else 0.0)))
			"P05":   # Step 34: the seasoning falls in a mist of its flavor's colour
				node.position = Vector2(c.x, r.position.y + r.size.y * (0.5 + 0.12 * fmod(t * 1.8, 1.0) if run else 0.5))
				node.visible = run
				_motion_flavor(node, m)
			"P06":   # Step 34: the drum turns under its ribbon (caramel) or swirl (cocoa)
				node.position = Vector2(c.x, r.position.y + r.size.y * 0.62)
				node.visible = run or not (m["held"] as Dictionary).is_empty()
				if run:
					node.rotation += delta * 2.2
				_motion_flavor(node, m)
			"P07":   # the jaws crimp
				node.position = Vector2(c.x, r.position.y + r.size.y * (0.4 + (0.24 * maxf(0.0, sin(t * 3.0)) if run else 0.0)))
			# Step 31: the storefront, moving only while it serves.
			"S01":   # a bag rides the belt up to the counter
				node.position = Vector2(r.position.x + r.size.x * (0.18 + 0.66 * fmod(t * 0.8, 1.0) if run else 0.5), r.position.y + r.size.y * (0.66 - 0.2 * (fmod(t * 0.8, 1.0) if run else 0.5)))
				node.visible = run
			"S02":   # a ticket curls out
				node.position = Vector2(c.x, r.position.y + r.size.y * (0.48 + (0.1 * fmod(t * 0.9, 1.0) if run else 0.0)))
			"S03":   # a coin drops into the drawer
				node.position = Vector2(r.position.x + r.size.x * 0.7, r.position.y + r.size.y * (0.3 + 0.3 * fmod(t * 1.3, 1.0) if run else 0.62))
				node.visible = run
			"S04":   # the lamp points left and right
				node.position = Vector2(c.x, r.position.y + r.size.y * 0.3)
				node.rotation = sin(t * 2.5) * 0.7 if run else 0.0
			"S05":   # the bell rings (bobs)
				node.position = Vector2(r.position.x + r.size.x * 0.8, r.position.y + r.size.y * (0.16 + (0.03 * absf(sin(t * 9.0)) if run else 0.0)))
			"S06":   # the lit line scrolls
				node.position = Vector2(r.position.x + r.size.x * (0.25 + 0.3 * fmod(t * 0.5, 1.0) if run else 0.4), r.position.y + r.size.y * 0.32)
			"S08":   # the robot slides along its rail
				node.position = Vector2(c.x + (sin(t * 1.6) * r.size.x * 0.2 if run else 0.0), r.position.y + r.size.y * 0.6)
			# Step 32: the support machines, moving only while they work.
			"U01":   # the robot rolls from side to side
				node.position = Vector2(c.x + (sin(t * 1.4) * r.size.x * 0.2 if run else 0.0), r.position.y + r.size.y * 0.9)
			"U02":   # a drop falls from the spout
				node.position = Vector2(r.position.x + r.size.x * 0.9, r.position.y + r.size.y * (0.62 + 0.25 * fmod(t * 1.2, 1.0) if run else 0.62))
				node.visible = run
			"U03":   # the leaf glows
				node.position = Vector2(c.x, r.position.y + r.size.y * 0.16)
				node.modulate.a = 0.3 + 0.7 * absf(sin(t * 2.0)) if run else 0.25
			"U04":   # a crate rides the lift
				node.position = Vector2(r.position.x + r.size.x * 0.3, r.position.y + r.size.y * (0.75 - 0.5 * absf(sin(t * 0.9)) if run else 0.75))
			"U05":   # the lamp sweeps the desk
				node.position = Vector2(r.position.x + r.size.x * (0.4 + 0.3 * absf(sin(t * 1.6)) if run else 0.5), r.position.y + r.size.y * 0.6)
			"U08":   # Step 33: a lot slides across from one line's arrow to the other's
				node.position = Vector2(r.position.x + r.size.x * (0.25 + 0.5 * fmod(t * 0.9, 1.0)), r.position.y + r.size.y * 0.55)
				node.visible = run
			"P08":   # the gate swings each pack to its lane
				node.position = Vector2(c.x, r.position.y + r.size.y * 0.5)
				node.rotation = (0.45 if fmod(floor(t * 0.8), 2.0) < 1.0 else -0.45) if run else 0.0
			_:
				node.position = c
	_step_heat_gauge()
	for id in _motion.keys():
		if not alive.has(id):
			(_motion[id] as Node2D).queue_free()
			_motion.erase(id)
	var still: Array = []
	for p: Node2D in _kernel_flights:
		p.step(delta)
		if p.done:
			p.queue_free()
		else:
			still.append(p)
	_kernel_flights = still


## Step 29: the kitchen's heat, a slim thermometer left of its places -- shown once two
## kettles cook (one cannot overheat a room); blue to red, flashing red while the
## kettles stop to cool. Redrawn only when the reading moves.
func _step_heat_gauge() -> void:
	var kettles: int = (rules.get("machines") as Array).filter(func(m: Dictionary) -> bool: return String(m["type"]) in ["cooker", "M16"]).size()
	if _heat_node == null:
		_heat_node = Node2D.new()
		_heat_node.draw.connect(_draw_heat_gauge)
		actor_layer.add_child(_heat_node)
	_heat_node.visible = kettles >= 2
	if not _heat_node.visible:
		return
	var lim := float((rules.economy.table("factory").get("heat", {}) as Dictionary).get("limit", 100))
	var v := clampf(float(rules.get("kitchen_heat")) / lim, 0.0, 1.0)
	var hot := int(rules.get("overheat_left")) > 0
	var key: float = v + (2.0 + floor(_clock * 4.0) if hot else 0.0)
	if absf(key - _heat_shown) > 0.01:
		_heat_shown = key
		_heat_node.queue_redraw()


func _draw_heat_gauge() -> void:
	var a := slot_rect("kitchen", 0)
	var b := slot_rect("kitchen", maxi(0, int(rules.slots("kitchen")) - 1))
	var bar := Rect2(Vector2(a.position.x - 13, a.position.y + 6), Vector2(7, b.end.y - a.position.y - 22))
	var lim := float((rules.economy.table("factory").get("heat", {}) as Dictionary).get("limit", 100))
	var v := clampf(float(rules.get("kitchen_heat")) / lim, 0.0, 1.0)
	var hot := int(rules.get("overheat_left")) > 0
	var col := PopTokens.SKY.lerp(PopTokens.WARN, v)
	if hot and fmod(_clock * 4.0, 2.0) < 1.0:
		col = Color.WHITE
	PopMachineArt._round_rect(_heat_node, bar, 3, Color(PopPalette.INK, 0.15))
	var fill := bar.size.y * v
	PopMachineArt._round_rect(_heat_node, Rect2(Vector2(bar.position.x, bar.end.y - fill), Vector2(bar.size.x, fill)), 3, col)
	_heat_node.draw_circle(Vector2(bar.get_center().x, bar.end.y + 6), 7.0, col if v > 0.05 else PopTokens.SKY)


## Step 32: the overview's button -- a coin with a clock hand, bottom-left of the kitchen.
func overview_button_rect() -> Rect2:
	var low := floor_rect(LOW)
	var s := clampf(_head_px() * 1.6, 34.0, 52.0)
	return Rect2(Vector2(low.position.x + 12, low.end.y - s - 12), Vector2(s, s))


func _pause_all_rect() -> Rect2:
	var d := detail_rect()
	var s := clampf(d.size.x * 0.16, 40.0, 60.0)
	return Rect2(Vector2(d.end.x - s - 12, d.end.y - s - 12), Vector2(s, s))


## The overview (Step 32's upkeep, Step 33's whole factory on one card, no words):
##   the three rates -- lots, packs and sales a minute -- the bottleneck's ringed in red;
##   coins burned, taken and the net a minute;
##   each floor, a group of small machines per line (coloured by what they are doing,
##   an empty place dashed) and its next line's button with the price (dim until the
##   floor is full and the coins are there); a machine picked here shows its
##   diagnostics in a strip below (and is ringed on its floor), without leaving the card;
##   one button pauses or resumes everything.
const OV_FLOORS := ["shop", "packing", "kitchen"]
const STATE_COLOUR := {"run": Color(0.36, 0.72, 0.42), "idle": Color(0.72, 0.72, 0.7), "blocked": Color(0.93, 0.62, 0.25),
	"starved": Color(0.55, 0.75, 0.92), "paused": Color(0.3, 0.27, 0.25), "unpaid": Color(0.88, 0.3, 0.25),
	"saving": Color(0.95, 0.78, 0.3), "waiting": Color(0.55, 0.75, 0.92), "overheat": Color(0.88, 0.3, 0.25)}


func _ov_fs(d: Rect2) -> float:
	return clampf(minf(d.size.x * 0.05, d.size.y * 0.055), 13.0, 24.0)


## Where everything on the card is (drawing and pressing ask the same layout).
func _ov_layout(d: Rect2) -> Dictionary:
	var fs := _ov_fs(d)
	var pad := fs * 0.6
	var out := {"fs": fs, "rates": [], "money": [], "floors": {}, "lines": {}, "machines": {}, "empty": []}
	var cw := (d.size.x - pad * 2.0) / 3.0
	for i in 3:
		out["rates"].append(Rect2(Vector2(d.position.x + pad + cw * i, d.position.y + pad), Vector2(cw - 4, fs * 1.6)))
		out["money"].append(Rect2(Vector2(d.position.x + pad + cw * i, d.position.y + pad + fs * 1.9), Vector2(cw - 4, fs * 1.4)))
	var y := d.position.y + pad + fs * 3.6
	var diag_h := fs * 2.4
	var pause := _pause_all_rect()
	var bottom := minf(d.end.y - pad - diag_h, pause.position.y - 4)
	var row_h := minf(fs * 3.4, (bottom - y) / 3.0)
	var btn_w := fs * 4.6
	for f: String in OV_FLOORS:
		var row := Rect2(Vector2(d.position.x + pad, y), Vector2(d.size.x - pad * 2.0, row_h - 4))
		out["floors"][f] = row
		out["lines"][f] = Rect2(Vector2(row.end.x - btn_w, row.position.y + 2), Vector2(btn_w, row.size.y - 4))
		# the places, a group per line, between the floor's chip and its button
		var groups := _line_groups(f) if rules else [1]
		var n := int(rules.slots(f)) if rules else 1
		var x0 := row.position.x + row.size.y * 1.1
		var room := row.size.x - row.size.y * 1.1 - btn_w - 8
		# one or two rows of small machines a line, whichever draws them larger
		var sub := 1
		var sq := 0.0
		for rows_n in [1, 2]:
			var colsn := 0
			for g: int in groups:
				colsn += ceili(float(g) / rows_n)
			var q := minf((row.size.y - 4) / rows_n - 2, (room - LINE_GAP * 0.6 * (groups.size() - 1)) / maxf(1.0, colsn) - 2)
			if q > sq:
				sq = q
				sub = rows_n
		sq = maxf(6.0, sq)
		var k := 0
		var x := x0
		var y0 := row.get_center().y - (sq * sub + 2 * (sub - 1)) * 0.5
		for gi in groups.size():
			var gcols := ceili(float(groups[gi]) / sub)
			for j in int(groups[gi]):
				var r := Rect2(Vector2(x + (j % gcols) * (sq + 2), y0 + (j / gcols) * (sq + 2)), Vector2(sq, sq))
				var m: Dictionary = rules.machine_at(f, k) if rules else {}
				if m.is_empty():
					out["empty"].append(r)
				else:
					out["machines"][int(m["id"])] = r
				k += 1
			x += gcols * (sq + 2) + LINE_GAP * 0.6
		y += row_h
	out["diag"] = Rect2(Vector2(d.position.x + pad, y + 2), Vector2(pause.position.x - d.position.x - pad * 2.0, diag_h))
	return out


func _draw_overview(ci: CanvasItem, d: Rect2) -> void:
	PopFactoryArt.shadow(ci, d, PopTokens.R_BUTTON)
	PopMachineArt._round_rect(ci, d, PopTokens.R_BUTTON, Color(1, 1, 1, 0.97))
	var pts := PopMachineArt.round_rect_points(d, PopTokens.R_BUTTON)
	pts.append(pts[0])
	var o: Dictionary = rules.upkeep_overview()
	ci.draw_polyline(pts, PopTokens.WARN if bool(o["low_wallet"]) else PopPalette.GOLD, 5.0, true)
	var L := _ov_layout(d)
	var fs := float(L["fs"])
	var font := ThemeDB.fallback_font
	var st: Dictionary = rules.state()
	var pm: Dictionary = st["per_min"]
	# 1. the three rates; the stage holding the factory back is ringed in red.
	var bn := String(st["bottleneck"])
	var stage_of := {"production": 0, "packaging": 1, "service": 2, "demand": 2}
	var vals := [int(pm["lots"]), int(pm["packs"]), int(pm["sales"])]
	for i in 3:
		var r: Rect2 = L["rates"][i]
		var ic := Vector2(r.position.x + fs * 0.8, r.get_center().y)
		match i:
			0:   # a lot of popcorn
				for q in 3:
					PopFactoryArt.popcorn(ci, ic + Vector2((q - 1) * fs * 0.32, -absf(q - 1) * fs * -0.1), fs * 0.28)
			1:   # a sealed bag
				PopFactoryArt.bag(ci, ic + Vector2(0, fs * 0.45), fs * 0.5)
			2:   # a coin in a hand-over (a sale)
				PopMachineArt.draw_coin(ci, ic, fs * 0.4)
		var txt := "%d" % vals[i]
		ci.draw_string(font, Vector2(r.position.x + fs * 1.6, r.get_center().y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), PopPalette.INK)
		# a little clock right after the number: a minute
		var cc := Vector2(r.position.x + fs * 1.6 + font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x + fs * 0.45, r.get_center().y)
		ci.draw_arc(cc, fs * 0.28, 0, TAU, 12, Color(PopPalette.INK, 0.5), 1.5)
		ci.draw_line(cc, cc + Vector2(0, -fs * 0.2), Color(PopPalette.INK, 0.5), 1.5)
		if stage_of.has(bn) and int(stage_of[bn]) == i:
			var rp := PopMachineArt.round_rect_points(r.grow(2), 8)
			rp.append(rp[0])
			ci.draw_polyline(rp, PopTokens.WARN, 3.0, true)
		if i < 2:   # the flow goes up: lots -> packs -> sales
			var ax := r.end.x + 2
			ci.draw_colored_polygon(PackedVector2Array([Vector2(ax - 4, r.get_center().y - 5), Vector2(ax + 2, r.get_center().y), Vector2(ax - 4, r.get_center().y + 5)]), Color(PopPalette.INK, 0.45))
	# 2. burn, take, net.
	var rows := [["burn", "-%s" % str(o["burn_per_min"]), PopTokens.WARN], ["take", "+%d" % int(o["revenue_last_min"]), PopTokens.OK],
		["net", ("%+.0f" % float(o["net_per_min"])), PopTokens.OK if float(o["net_per_min"]) >= 0.0 else PopTokens.WARN]]
	for i in 3:
		var r: Rect2 = L["money"][i]
		var ic := Vector2(r.position.x + fs * 0.8, r.get_center().y)
		match String(rows[i][0]):
			"burn":   # a coin with a flame
				PopMachineArt.draw_coin(ci, ic, fs * 0.38)
				ci.draw_colored_polygon(PackedVector2Array([ic + Vector2(fs * 0.3, -fs * 0.1), ic + Vector2(fs * 0.5, -fs * 0.55), ic + Vector2(fs * 0.62, -fs * 0.05)]), PopTokens.WARN)
			"take":   # a coin with a bag
				PopMachineArt.draw_coin(ci, ic, fs * 0.38)
				PopFactoryArt.bag(ci, ic + Vector2(fs * 0.55, fs * 0.35), fs * 0.32)
			"net":   # a clock hand: a minute
				ci.draw_arc(ic, fs * 0.38, 0, TAU, 16, PopPalette.INK, 2.5)
				ci.draw_line(ic, ic + Vector2(0, -fs * 0.3), PopPalette.INK, 2.5)
				ci.draw_line(ic, ic + Vector2(fs * 0.22, 0), PopPalette.INK, 2.5)
		ci.draw_string(font, Vector2(r.position.x + fs * 1.6, r.get_center().y + fs * 0.35), String(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), rows[i][2])
	# 3. the floors: a chip in the floor's colour, the machines by line, the next line.
	var cols := {"shop": PopTokens.FLOOR_TOP, "packing": PopTokens.FLOOR_MID, "kitchen": PopTokens.FLOOR_LOW}
	for f: String in OV_FLOORS:
		var row: Rect2 = L["floors"][f]
		var chip := Rect2(row.position, Vector2(row.size.y, row.size.y))
		PopMachineArt._round_rect(ci, chip.grow(-2), 6, (cols[f] as Array)[1])
		PopFactoryArt.machine_icon(ci, chip.grow(-6), String(MACHINE_OF[f]), 0)
		var lc := int(rules.line_cost(f))
		var b: Rect2 = L["lines"][f]
		if lc >= 0:
			var ready: bool = rules.floor_full(f) and rules.money >= lc
			PopMachineArt._round_rect(ci, b, 8, PopPalette.GOLD if ready else Color(PopPalette.INK, 0.12))
			# a plus over a small row of places: one more line
			var pc := Vector2(b.position.x + b.size.y * 0.5, b.get_center().y)
			ci.draw_rect(Rect2(pc - Vector2(b.size.y * 0.28, 2), Vector2(b.size.y * 0.56, 4)), PopPalette.INK if ready else Color(PopPalette.INK, 0.4))
			ci.draw_rect(Rect2(pc - Vector2(2, b.size.y * 0.28), Vector2(4, b.size.y * 0.56)), PopPalette.INK if ready else Color(PopPalette.INK, 0.4))
			var cx := b.position.x + b.size.y * 0.95
			PopMachineArt.draw_coin(ci, Vector2(cx + fs * 0.3, b.get_center().y), fs * 0.3)
			ci.draw_string(font, Vector2(cx + fs * 0.7, b.get_center().y + fs * 0.3), _short(lc), HORIZONTAL_ALIGNMENT_LEFT, b.end.x - cx - fs * 0.75, int(fs * 0.8), PopPalette.INK if ready else Color(PopPalette.INK, 0.45))
		for r: Rect2 in L["empty"]:
			if row.has_point(r.get_center()):
				PopMachineArt._round_rect(ci, r, 3, Color(PopPalette.INK, 0.06))
	for id: int in L["machines"]:
		var r: Rect2 = L["machines"][id]
		var m: Dictionary = rules.machine(id)
		var col: Color = STATE_COLOUR.get(String(m["state"]), Color(0.7, 0.7, 0.7))
		PopMachineArt._round_rect(ci, r, 3, col)
		if r.size.x >= 20.0:
			var e: Dictionary = rules.forty().get(String(m["type"]), {})
			if e.is_empty():
				PopFactoryArt.machine_icon(ci, r.grow(-2), String(m["type"]), int(m["tier"]))
			else:
				PopFactoryArt.catalog_icon(ci, r.grow(-2), e.get("parts", ["box"]), String(e.get("group", "manufacturing")))
		if id == ov_machine:
			var rp := PopMachineArt.round_rect_points(r.grow(2), 4)
			rp.append(rp[0])
			ci.draw_polyline(rp, PopPalette.GOLD, 3.0, true)
	# 4. the picked machine's diagnostics.
	if ov_machine >= 0 and not rules.machine(ov_machine).is_empty():
		var m: Dictionary = rules.machine(ov_machine)
		var dr: Rect2 = L["diag"]
		PopMachineArt._round_rect(ci, dr, 8, Color(PopPalette.GOLD, 0.18))
		var ir := Rect2(dr.position + Vector2(4, 2), Vector2(dr.size.y - 4, dr.size.y - 4))
		var e: Dictionary = rules.forty().get(String(m["type"]), {})
		if e.is_empty():
			PopFactoryArt.machine_icon(ci, ir, String(m["type"]), int(m["tier"]))
		else:
			PopFactoryArt.catalog_icon(ci, ir, e.get("parts", ["box"]), String(e.get("group", "manufacturing")))
		PopFactoryArt.state_badge(ci, Vector2(ir.end.x + fs * 0.6, dr.get_center().y), fs * 0.4, String(m["state"]))
		var row_o: Dictionary = {}
		for x: Dictionary in o["machines"]:
			if int(x["id"]) == ov_machine:
				row_o = x
		var x0 := ir.end.x + fs * 1.4
		# its line: one dot per line, its own filled
		var lines_n := int((rules.get("floor_lines") as Dictionary).get(String(m["floor"]), 1))
		var my := int(rules.line_of(String(m["floor"]), int(m["slot"])))
		for q in lines_n:
			var dc := Vector2(x0 + q * fs * 0.55, dr.get_center().y)
			if q == my:
				ci.draw_circle(dc, fs * 0.2, PopPalette.INK)
			else:
				ci.draw_arc(dc, fs * 0.2, 0, TAU, 10, PopPalette.INK, 1.5)
		x0 += lines_n * fs * 0.55 + fs * 0.4
		# what it has done (lots, packs, customers, moves), and what it costs: a minute and all told
		ci.draw_string(font, Vector2(x0, dr.get_center().y + fs * 0.35), "x%d" % int(m.get("done", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.9), PopPalette.INK)
		x0 += fs * 3.4
		PopMachineArt.draw_coin(ci, Vector2(x0, dr.get_center().y), fs * 0.32)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + fs * 0.25, dr.get_center().y - fs * 0.1), Vector2(x0 + fs * 0.42, dr.get_center().y - fs * 0.5), Vector2(x0 + fs * 0.55, dr.get_center().y - fs * 0.05)]), PopTokens.WARN)
		ci.draw_string(font, Vector2(x0 + fs * 0.75, dr.get_center().y + fs * 0.35), "-%s  (%d)" % [str(row_o.get("per_min", 0)), int(row_o.get("paid", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.9), PopTokens.WARN)
	# Pause / resume everything.
	var pb := _pause_all_rect()
	ci.draw_circle(pb.get_center(), pb.size.x * 0.5, Color.WHITE)
	ci.draw_arc(pb.get_center(), pb.size.x * 0.5, 0, TAU, 24, PopPalette.INK, 2.5)
	var any_on := (rules.get("machines") as Array).any(func(m: Dictionary) -> bool: return String(m["state"]) != "paused")
	if any_on:
		PopFactoryArt.state_badge(ci, pb.get_center(), pb.size.x * 0.3, "paused")
	else:
		var c := pb.get_center()
		var q := pb.size.x * 0.22
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-q * 0.7, -q), c + Vector2(q, 0), c + Vector2(-q * 0.7, q)]), PopTokens.OK)
	if int(o["paused"]) > 0:
		ci.draw_string(font, Vector2(pb.position.x - fs * 1.6, pb.get_center().y + fs * 0.35), "%d" % int(o["paused"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), PopPalette.INK)


static func _short(n: int) -> String:
	if n >= 1000:
		return ("%dk" % (n / 1000)) if n % 1000 == 0 else ("%.1fk" % (n / 1000.0))
	return str(n)


func _draw_overview_button(ci: CanvasItem) -> void:
	if rules == null or (rules.get("machines") as Array).is_empty():
		return
	var r := overview_button_rect()
	var c := r.get_center()
	var low: bool = bool(rules.upkeep_overview()["low_wallet"])
	ci.draw_circle(c, r.size.x * 0.5, PopTokens.WARN if low else Color(1, 1, 1, 0.92))
	ci.draw_arc(c, r.size.x * 0.5, 0, TAU, 24, PopPalette.INK, 2.5)
	PopMachineArt.draw_coin(ci, c + Vector2(-r.size.x * 0.08, r.size.x * 0.06), r.size.x * 0.24)
	ci.draw_arc(c + Vector2(r.size.x * 0.18, -r.size.x * 0.16), r.size.x * 0.16, 0, TAU, 12, PopPalette.INK, 2.0)
	ci.draw_line(c + Vector2(r.size.x * 0.18, -r.size.x * 0.16), c + Vector2(r.size.x * 0.18, -r.size.x * 0.27), PopPalette.INK, 2.0)


## Step 34: a coater's motion node draws the flavor it is coating (or set to): redrawn when it changes.
func _motion_flavor(node: Node2D, m: Dictionary) -> void:
	var fl := String((m["held"] as Dictionary).get("recipe", m.get("flavor", "plain")))
	if String(node.get_meta("flavor", "")) != fl:
		node.set_meta("flavor", fl)
		node.queue_redraw()


func _draw_motion_part(n: Node2D) -> void:
	var w := float(n.get_meta("size"))
	match String(n.get_meta("type")):
		"P05":   # a cone of dust under the nozzle
			var k := PopFactoryArt.flavor_look(String(n.get_meta("flavor", "cheese")))
			for q in 7:
				var x := (float(q % 4) - 1.5) * w * 0.07 * (1.0 + float(q / 4))
				n.draw_circle(Vector2(x, float(q / 4) * w * 0.07), w * 0.025, k["mark"] if q % 2 == 0 else k["fill"])
			if String(n.get_meta("flavor", "")) == "spicy":
				n.draw_circle(Vector2(w * 0.12, -w * 0.04), w * 0.02, Color(1.0, 0.9, 0.35))
		"P06":   # a ribbon over the drum: caramel runs, cocoa swirls
			var fl := String(n.get_meta("flavor", "caramel"))
			var k := PopFactoryArt.flavor_look(fl)
			if fl == "cocoa":
				n.draw_arc(Vector2.ZERO, w * 0.2, 0, PI * 1.5, 14, k["stripe"], maxf(3.0, w * 0.06))
				n.draw_arc(Vector2.ZERO, w * 0.11, PI, PI * 2.6, 10, k["mark"], maxf(2.0, w * 0.04))
			else:
				n.draw_arc(Vector2.ZERO, w * 0.24, PI * 1.05, PI * 1.95, 14, k["band"], maxf(4.0, w * 0.08))
				for q in 3:
					var a := PI * (1.2 + 0.3 * q)
					n.draw_circle(Vector2(cos(a), sin(a)) * w * 0.24 + Vector2(0, w * 0.05), w * 0.03, k["stripe"])
		"M08":
			for q in 3:
				var a := TAU * q / 3.0
				n.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * w * 0.2, Vector2(cos(a + 0.7), sin(a + 0.7)) * w * 0.2]), Color.WHITE)
			n.draw_circle(Vector2.ZERO, w * 0.04, PopTokens.STEEL_DEEP)
		"M04":
			for q in 6:
				var a := TAU * q / 6.0
				n.draw_circle(Vector2(cos(a), sin(a)) * w * 0.13, w * 0.04, PopTokens.STEEL_DEEP)
		"M01":
			for q in 3:
				n.draw_circle(Vector2((q - 1) * w * 0.06, q * w * 0.03), w * 0.035, Color(0.85, 0.62, 0.25))
		"M02":
			n.draw_circle(Vector2.ZERO, w * 0.05, PopPalette.GOLD)
		"M03":
			n.draw_line(Vector2.ZERO, Vector2(0, -w * 0.12), PopTokens.WARN, 2.5)
		"M05":
			n.draw_circle(Vector2.ZERO, w * 0.05, PopPalette.INK)
		"M06":
			n.draw_line(Vector2.ZERO, Vector2(w * 0.4, 0), PopTokens.STEEL_DEEP, 3.0)
		"cooker":
			n.draw_rect(Rect2(Vector2(-w * 0.3, -2), Vector2(w * 0.6, 4)), PopTokens.MACHINE_LINE)
		"M09":
			for q in 4:
				n.draw_circle(Vector2((q - 1.5) * w * 0.12, (q % 2) * w * 0.03 - w * 0.02), w * 0.03, Color(0.85, 0.62, 0.25))
		"M10":
			n.draw_circle(Vector2.ZERO, w * 0.035, Color(0.85, 0.62, 0.25))
		"M11":
			n.draw_line(Vector2.ZERO, Vector2(0, w * 0.32), Color(1.0, 0.85, 0.3, 0.9), 3.0)
			n.draw_circle(Vector2.ZERO, w * 0.045, PopPalette.GOLD)
		"M13":
			for q in 3:
				n.draw_rect(Rect2(Vector2(-w * 0.16, (q - 1) * w * 0.12 - w * 0.025), Vector2(w * 0.32, w * 0.05)), Color(1, 1, 1, 0.85))
		"M14":
			for q in 4:
				n.draw_arc(Vector2((q - 1.5) * w * 0.13, 0), w * 0.07, PI, TAU, 8, Color(1.0, 0.55, 0.2), 3.0)
		"M15":
			n.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.05, -w * 0.05), Vector2(w * 0.06, 0), Vector2(-w * 0.05, w * 0.05)]), PopTokens.OK)
		"bagger":
			n.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.08, -w * 0.1), Vector2(w * 0.08, -w * 0.1), Vector2(w * 0.03, w * 0.06), Vector2(-w * 0.03, w * 0.06)]), PopTokens.STEEL_DEEP)
		"P01":
			PopFactoryArt.cup(n, Vector2.ZERO, w * 0.18)
		"P02":
			PopFactoryArt.bag(n, Vector2.ZERO, w * 0.16, PopTokens.MACHINE, true)
		"P04":
			n.draw_line(Vector2(-w * 0.2, 0), Vector2(w * 0.2, 0), PopTokens.STEEL_DEEP, 4.0)
			n.draw_arc(Vector2(0, -w * 0.02), w * 0.18, 0.15, PI - 0.15, 10, PopTokens.STEEL_DEEP, 2.0)
		"P07":
			n.draw_rect(Rect2(Vector2(-w * 0.28, -w * 0.05), Vector2(w * 0.56, w * 0.06)), PopTokens.WARN)
			n.draw_rect(Rect2(Vector2(-w * 0.28, w * 0.01), Vector2(w * 0.56, w * 0.03)), Color(1, 1, 1, 0.8))
		"S01":
			PopFactoryArt.bag(n, Vector2.ZERO, w * 0.14)
		"S02":
			n.draw_rect(Rect2(Vector2(-w * 0.08, 0), Vector2(w * 0.16, w * 0.14)), Color.WHITE)
			n.draw_line(Vector2(-w * 0.05, w * 0.05), Vector2(w * 0.05, w * 0.05), PopPalette.INK, 1.5)
		"S03":
			PopMachineArt.draw_coin(n, Vector2.ZERO, w * 0.07)
		"S04":
			n.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.3, -w * 0.08), Vector2(w * 0.3, w * 0.08)]), Color(1.0, 0.9, 0.4, 0.75))
		"S05":
			n.draw_circle(Vector2.ZERO, w * 0.06, PopPalette.GOLD)
		"S06":
			n.draw_line(Vector2.ZERO, Vector2(w * 0.25, 0), PopPalette.GOLD, 2.5)
		"S08":
			n.draw_circle(Vector2(-w * 0.32, -w * 0.12), w * 0.05, PopTokens.STEEL)
			n.draw_circle(Vector2(w * 0.32, -w * 0.12), w * 0.05, PopTokens.STEEL)
		"U01":
			n.draw_circle(Vector2.ZERO, w * 0.03, PopPalette.GOLD)
		"U02":
			n.draw_circle(Vector2.ZERO, w * 0.04, PopPalette.GOLD)
		"U03":
			n.draw_circle(Vector2.ZERO, w * 0.09, Color(0.5, 0.95, 0.6, 0.8))
		"U04":
			n.draw_rect(Rect2(Vector2(-w * 0.1, -w * 0.08), Vector2(w * 0.2, w * 0.16)), Color(0.75, 0.55, 0.3))
		"U05":
			n.draw_circle(Vector2.ZERO, w * 0.08, Color(1.0, 0.9, 0.4, 0.45))
		"U08":
			PopFactoryArt.popcorn(n, Vector2.ZERO, w * 0.09)
		"P08":
			n.draw_line(Vector2.ZERO, Vector2(0, w * 0.3), PopTokens.STEEL_DEEP, 4.0)
			n.draw_circle(Vector2.ZERO, w * 0.05, PopPalette.GOLD)
		"M16":
			for q in 4:
				var a := TAU * q / 4.0
				n.draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * w * 0.22, Color(1, 1, 1, 0.85), 2.5)
			n.draw_circle(Vector2.ZERO, w * 0.05, PopTokens.STEEL_DEEP)
