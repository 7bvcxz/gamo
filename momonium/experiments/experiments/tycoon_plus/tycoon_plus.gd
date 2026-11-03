extends LabExperiment

## E+ -- the improved track of Production Tycoon (Step 94). The same line,
## item by item and coin by coin (TycoonLine, TycoonLevels: the same
## deliveries at the same times as E -- tests/integration/test_tycoon_plus.gd
## runs both), drawn to be followed on a phone (Step 97):
##   - the line takes the play area's shape: on a phone straight down (the
##     area is taller than wide), on a nearly square one an L -- raw goods
##     come down from the hopper to the machine at the corner, the products
##     go right to the crate -- and on a wide screen straight left to right.
##     Measured (tools/e_frame.gd) a product is drawn about twice as big as in
##     E on a 16:9 phone, three times on a taller one, five on a desktop. The
##     belts run along the iso diagonals that are straight down and straight
##     right on screen, so they are upright rectangles. In the L each lane is
##     its own L, its corner one lane up and right of the one before, so none
##     crosses;
##   - the camera frames the line itself -- hopper, belts, machine, crate,
##     helpers -- not the island, between the coin counter and the button,
##     and widens smoothly when a lane is added;
##   - every step reads: a raw item drops out of the hopper, rides the belt,
##     waits at the machine, is worked under a pressing arm with a progress
##     ring, pops out as goods, rides on and drops into the crate -- which
##     bumps and says "+3" at that delivery (several close together are
##     summed), with a coin to the counter;
##   - an upgrade shows on what it changed (the hopper, an arm, the machine,
##     a helper, the belt, a lane, the goods), and ten seconds later the line
##     says what it really did: deliveries a minute before -> after.
## Coins are only ever deliveries: nothing is paid that the crate did not
## receive. Effects and sounds are paced (one coin sound at most every
## SOUND_GAP), the belt's lines are drawn unantialiased in one call each
## (an antialiased line is a render object per segment: Steps 93 and 95).
## The baseline E (experiments/tycoon/) is never changed for any of this.

const MAX_ZOOM := 2.2
const MIN_ZOOM := 0.45
const RATE_WINDOW := 10.0
const SOUND_GAP := 0.35
## Deliveries within this many seconds are shown as one "+n".
const POP_GAP := 0.3
## How long after an upgrade the line says what changed (deliveries a minute).
const MEASURE_AFTER := 10.0
const LENGTH := TycoonLine.LENGTH
const MACHINE_AT := TycoonLine.MACHINE_AT
## Line units in logical tiles along the belt, and between lanes.
const ALONG := 1.0
const ACROSS := 0.62
const BELT_HALF := 0.3
## An item is drawn this many times the gap the line keeps between items
## (TycoonLine.SPACING): a whole line of six tiles has to stand in a phone's
## height, and items no bigger than their gap were dots again; a queue at the
## machine overlaps a little, the nearer item on top.
const ITEM_FILL := 1.3
const MAX_LANES := 5

var coins := 0
var earned := 0
var level := 0
var line := TycoonLine.new()

var world: Node2D
var island: LabIsland
var ocean: LabOcean
var stuff: Node2D
var belts: _Belts
var items: _Items
var arms: _Arms
var machine: Sprite2D
var hopper: Sprite2D
var crate: Sprite2D
var helpers: Array[LabMomo] = []
var chip: PanelContainer
var chip_label: Label
## "down" (a tall phone), "turn" (an L, a squarer phone) or "right" (wide).
var orientation := ""
## Logical tiles: straight down and straight right on screen, one tile long.
const DOWN := Vector2(0.70710678, 0.70710678)
const RIGHT := Vector2(0.70710678, -0.70710678)
var _along := Vector2.ZERO
## The machine's size when settled (it pops in from 0.6 at an upgrade; the
## camera frames the settled machine, not the popping one).
var _machine_scale := Vector2.ONE
var _across := Vector2.ZERO
var _sound := 99.0
var _pop_t := 99.0
var _pop_coins := 0
var _recent: Array = []
var _time := 0.0
var _bump := 0.0
var _zoom_from := Vector2.ZERO
var _zoom_to := Vector2.ZERO
var _zoom_t := 1.0
var _measure: Dictionary = {}
var deliveries_shown := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ocean = LabOcean.new()
	add_child(ocean)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	island = LabIsland.new()
	world.add_child(island)
	ocean.follow(island)
	stuff = Node2D.new()
	stuff.y_sort_enabled = true
	island.add_child(stuff)
	hopper = _sprite("prop_crate")
	crate = _sprite("prop_barrel")
	machine = _sprite("smelter")
	belts = _Belts.new()
	belts.owner_exp = self
	island.add_child(belts)
	island.move_child(belts, stuff.get_index())
	items = _Items.new()
	items.owner_exp = self
	items.z_index = 4
	island.add_child(items)
	arms = _Arms.new()
	arms.owner_exp = self
	arms.z_index = 5
	island.add_child(arms)
	_build_chip()
	resized.connect(_layout)
	_layout()
	_apply(false)
	if audio != null:
		audio.start_ambience(true)


func _sprite(pic: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	stuff.add_child(s)
	_dress(s, pic, 1.0)
	return s


func _dress(s: Sprite2D, pic: String, k: float) -> void:
	s.texture = LabAtlas.texture(pic)
	var sc := LabAtlas.world_scale(pic) * k
	s.scale = Vector2(sc, sc)
	s.offset = -LabAtlas.pivot(pic)


# --- where things are -----------------------------------------------------------------------

## The island point (logical tiles) of line position `x` on lane `lane`:
## straight on a wide screen; on a phone down to the lane's corner at the
## machine, then right.
func logical(x: float, lane: float) -> Vector2:
	if orientation != "turn":
		return _along * x + _across * lane
	var corner := (RIGHT - DOWN) * ACROSS * lane
	if x <= MACHINE_AT:
		return corner + DOWN * ALONG * (x - MACHINE_AT)
	return corner + RIGHT * ALONG * (x - MACHINE_AT)


## Where line position `x` of lane `lane` is, in the island's pixels.
func at(x: float, lane: float) -> Vector2:
	return island.iso.to_screen(logical(x, lane))


## The line stands the way the screen does. Turning it rebuilds the island
## under it and moves the hopper, machine, crate and helpers; the items are
## drawn from the line each frame, so they follow.
func _orient(o: String) -> void:
	if o == orientation:
		return
	orientation = o
	_along = DOWN * ALONG if o == "down" else RIGHT * ALONG
	_across = RIGHT * ACROSS if o == "down" else DOWN * ACROSS
	island.set_cells(_ground(line.lanes))
	_place_things()


## The island under the line for `lanes` lanes, with a margin for the
## hopper, the machine, the crate and the helpers -- no more: every cell is
## drawn (E+ at Lv10 drew 1,464 render objects with ground for five lanes,
## E 1,107). A new lane's ground rises out of the sea (_apply).
func _ground(lanes: int) -> Array[Vector2i]:
	var cells := {}
	var x := -1.9
	while x <= LENGTH + 1.7:
		var lane := -1.7
		while lane <= float(lanes - 1) + 0.6:
			var p := logical(x, lane)
			cells[Vector2i(floori(p.x), floori(p.y))] = true
			lane += 0.25
		x += 0.25
	var list: Array[Vector2i] = []
	for c: Vector2i in cells:
		list.append(c)
	return list


func _place_things() -> void:
	var mid := float(line.lanes - 1) * 0.5
	# The machine stands beside the belts where they are worked (outside the
	# corner on a phone), its arms reaching over them.
	machine.position = at(MACHINE_AT + 0.25, -1.35) if orientation == "right" else at(MACHINE_AT, -1.2)
	hopper.position = at(-0.95, mid)
	crate.position = at(LENGTH + 0.75, mid)
	for i in helpers.size():
		helpers[i].position = _helper_spot(i)


func _helper_spot(i: int) -> Vector2:
	# The loader beside the hopper, the packer beside the crate, then along.
	match i:
		0:
			return at(-0.7, -1.2)
		1:
			return at(LENGTH + 0.55, -1.2)
	return at(1.3 + 1.2 * float(i - 2), -1.3)


## How big an item is drawn (island pixels): the gap the line keeps between
## items, on screen along the belt.
func item_gap() -> float:
	return (at(TycoonLine.SPACING, 0.0) - at(0.0, 0.0)).length() * ITEM_FILL


## The line's own rectangle in the island's pixels: hopper, belts of the
## lanes in use, machine, crate, helpers (what the camera frames).
func line_bounds() -> Rect2:
	var r := Rect2(at(-1.4, -0.5), Vector2.ZERO)
	for lane in line.lanes:
		for x: float in [-1.4, 0.0, MACHINE_AT, LENGTH, LENGTH + 1.05]:
			r = r.expand(at(x, float(lane) + 0.45)).expand(at(x, float(lane) - 0.45))
	for s: Sprite2D in [machine, hopper, crate]:
		r = r.merge(_sprite_rect(s, _machine_scale if s == machine else s.scale))
	for m: LabMomo in helpers:
		r = r.expand(m.position + Vector2(-50, -110)).expand(m.position + Vector2(50, 10))
	return r


func _sprite_rect(s: Sprite2D, k: Vector2) -> Rect2:
	if s.texture == null:
		return Rect2(s.position, Vector2.ZERO)
	return Rect2(s.position + s.offset * k, s.texture.get_size() * k)


# --- running the line ------------------------------------------------------------------------

func tick(dt: float) -> void:
	var spawned_before := line.spawned
	line.advance(dt)
	_time += dt
	var got := line.just_delivered.size() * line.value
	if got > 0:
		coins += got
		earned += got
		for it: Dictionary in line.just_delivered:
			_recent.append(_time)
			items.delivered(it)
		_pop_coins += got
		_bump = 1.0
		if helpers.size() >= 2:
			helpers[1].cheer(0.3)
	if line.spawned > spawned_before and not helpers.is_empty():
		helpers[0].cheer(0.25)
	while not _recent.is_empty() and float(_recent[0]) < _time - RATE_WINDOW:
		_recent.pop_front()
	_pop_t += dt
	_sound += dt
	if _pop_coins > 0 and _pop_t >= POP_GAP:
		_pop_t = 0.0
		_show_delivery(_pop_coins)
		_pop_coins = 0
	if not _measure.is_empty() and _time >= float(_measure["at"]):
		_tell_change()
	session.metric("level", level)
	session.metric("coins", coins)
	session.metric("earned", earned)
	session.metric("units_made", line.spawned)
	session.metric("delivered", line.delivered)
	session.metric("deliveries_per_min", deliveries_per_min())
	belts.queue_redraw()
	items.queue_redraw()
	arms.queue_redraw()
	if got > 0:
		action_changed.emit()


## Deliveries a minute over the last RATE_WINDOW seconds of play.
func deliveries_per_min() -> float:
	return snappedf(_recent.size() * 60.0 / RATE_WINDOW, 0.1) if _time >= RATE_WINDOW else snappedf(_recent.size() * 60.0 / maxf(_time, 1.0), 0.1)


func _process(delta: float) -> void:
	# Presentation only: the helpers' work loops, the crate's bump and the
	# camera easing to a new frame. The frame pauses the experiment, so these
	# stop with the line.
	if not reduced_motion:
		for m: LabMomo in helpers:
			m.work_t += delta
	if _bump > 0.0:
		_bump = maxf(0.0, _bump - delta * 6.0)
		var base := LabAtlas.world_scale("prop_barrel") * 1.8
		crate.scale = Vector2.ONE * base * (1.0 + 0.12 * sin(_bump * PI) * float(not reduced_motion))
	if _zoom_t < 1.0:
		_zoom_t = minf(1.0, _zoom_t + delta / 0.5)
		var e := 1.0 - pow(1.0 - _zoom_t, 3.0)
		world.scale = Vector2.ONE * lerpf(_zoom_from.x, _zoom_to.x, e)
		world.position = _zoom_from_pos.lerp(_zoom_to_pos, e)


var _zoom_from_pos := Vector2.ZERO
var _zoom_to_pos := Vector2.ZERO


func hud() -> Dictionary:
	return {"value": coins, "rate": snappedf(deliveries_per_min() * line.value / 60.0, 0.1), "icon": "icon_coin"}


func action_info() -> Dictionary:
	var c := TycoonLevels.cost(level + 1)
	var nxt := TycoonLevels.row(level + 1)
	var icon := "smelter"
	match String(nxt["show"]):
		"hopper":
			icon = "prop_crate"
		"arm", "belt", "lane", "sparkle", "machine":
			icon = String(nxt["machine"])
		"helper":
			icon = "momo_front"
		"product":
			icon = String(nxt["product"])
	return {"label": "Improve Line", "cost": c, "affordable": coins >= c, "icon": icon}


func do_action() -> void:
	var c := TycoonLevels.cost(level + 1)
	if coins < c:
		return
	var before := deliveries_per_min()
	coins -= c
	level += 1
	var r := TycoonLevels.row(level)
	session.upgrade(level, c, {"name": String(r["name"]), "show": String(r["show"])})
	_apply(true)
	_point_at_change(String(r["show"]), String(r["name"]))
	# What it really does to the line, measured, in MEASURE_AFTER seconds.
	_measure = {"at": _time + MEASURE_AFTER, "before": before, "from": line.delivered, "name": String(r["name"])}
	if audio != null:
		audio.play("built", 1.0, -2.0)
	action_changed.emit()


## The upgrade said where it happened: a ring and its name on the part
## that changed.
func _point_at_change(show: String, name: String) -> void:
	if fx == null:
		return
	var where := machine.position
	match show:
		"hopper":
			where = hopper.position
		"helper":
			where = helpers.back().position if not helpers.is_empty() else hopper.position
		"lane":
			where = at(LENGTH * 0.5, float(line.lanes - 1))
		"belt":
			where = at(LENGTH * 0.5, float(line.lanes - 1) * 0.5)
		"product":
			where = crate.position
	var p := to_fx(island.get_global_transform() * where)
	fx.ring(p, Color(1, 0.95, 0.6), 150.0)
	fx.float_text(p + Vector2(0, -80), name + "!", Color.WHITE, 40)


## Ten seconds after an upgrade: deliveries a minute before -> after, from
## what the crate really received in those ten seconds.
func _tell_change() -> void:
	var after := (line.delivered - int(_measure["from"])) * 60.0 / MEASURE_AFTER
	session.milestone("output", {"upgrade": _measure["name"], "before_per_min": _measure["before"], "after_per_min": snappedf(after, 0.1)})
	if fx != null:
		var p := to_fx(island.get_global_transform() * crate.position) + Vector2(0, -150)
		fx.float_text(p, "%d → %d a min" % [int(round(float(_measure["before"]))), int(round(after))], Color("#c8f7a8"), 34)
	_measure = {}


func _apply(animate: bool) -> void:
	var r := TycoonLevels.row(level)
	var lanes_before := line.lanes
	line.configure(r)
	if line.lanes != lanes_before and orientation != "":
		island.add_cells(_ground(line.lanes), animate)
	_dress(machine, String(r["machine"]), 1.45)
	_machine_scale = machine.scale
	_dress(hopper, "prop_crate", 1.6 + 0.4 * float(level >= 1))
	_dress(crate, "prop_barrel", 1.8)
	while helpers.size() < int(r["helpers"]):
		var m := LabMomo.new()
		m.reduced_motion = reduced_motion
		m.work_anim = "work_stoke" if helpers.is_empty() else "work_hammer"
		stuff.add_child(m)
		helpers.append(m)
		if animate and not reduced_motion:
			m.scale = Vector2.ZERO
			m.create_tween().tween_property(m, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_place_things()
	if animate and not reduced_motion:
		var target := machine.scale
		machine.scale = target * 0.6
		machine.create_tween().tween_property(machine, "scale", target, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_chip()
	_frame(animate)
	belts.queue_redraw()


func _show_delivery(amount: int) -> void:
	deliveries_shown += 1
	if fx == null:
		return
	var at_crate := to_fx(crate.get_global_transform() * Vector2(0, -40))
	fx.float_text(at_crate + Vector2(0, -20), "+%d" % amount, Color("#ffe27a"), 30)
	if not reduced_motion:
		fx.coins(at_crate, 1)
	if audio != null and _sound >= SOUND_GAP:
		_sound = 0.0
		audio.play("coin", 1.15, -13.0, 0.06)


# --- framing --------------------------------------------------------------------------------------

func _layout() -> void:
	if size.x <= 0.0:
		return
	var area := play_area()
	if size.x > size.y * 1.05:
		_orient("right")
	elif area.size.y > area.size.x * 1.1:
		_orient("down")
	else:
		_orient("turn")
	_frame(false)
	_update_chip()


## The play area: under the counter and the line's chip, above the button.
func play_area() -> Rect2:
	return Rect2(24.0, LabHost.TOP_UI + 64.0, size.x - 48.0, size.y - LabHost.TOP_UI - 64.0 - LabHost.BOTTOM_UI - 12.0)


## Fits the line (not the island) into the play area; eases there when asked.
func _frame(animate: bool) -> void:
	if size.x <= 0.0:
		return
	var b := line_bounds().grow(20.0)
	var area := play_area()
	var k := clampf(minf(area.size.x / b.size.x, area.size.y / b.size.y), MIN_ZOOM, MAX_ZOOM)
	var pos := area.get_center() - (island.position + b.get_center()) * k
	if animate and not reduced_motion and world.scale.x > 0.0:
		_zoom_from = world.scale
		_zoom_to = Vector2(k, k)
		_zoom_from_pos = world.position
		_zoom_to_pos = pos
		_zoom_t = 0.0
	else:
		_zoom_t = 1.0
		world.scale = Vector2(k, k)
		world.position = pos


func _build_chip() -> void:
	chip = PanelContainer.new()
	chip.name = "LineChip"
	chip.add_theme_stylebox_override("panel", LabStyle.box(Color(1, 1, 1, 0.85), 22, Color(0, 0, 0, 0), 0, 3))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_label = LabStyle.label("", 26, LabStyle.INK)
	chip.add_child(chip_label)
	add_child(chip)


func _update_chip() -> void:
	if chip_label == null:
		return
	var r := TycoonLevels.row(level)
	chip_label.text = "Line %d · %s · %d lane%s" % [level, r["name"], line.lanes, "" if line.lanes == 1 else "s"]
	chip.reset_size()
	chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


# --- the pieces --------------------------------------------------------------------------------

## The belts: dark bands with rails and rollers, chevrons riding them at the
## belt's speed (faster belts, faster chevrons), each kind of line in one
## unantialiased call.
class _Belts extends Node2D:
	var owner_exp: Node

	func _draw() -> void:
		var e = owner_exp
		var line: TycoonLine = e.line
		var rails := PackedVector2Array()
		var chevrons := PackedVector2Array()
		var w := BELT_HALF * ACROSS
		for lane in line.lanes:
			var l := float(lane)
			# Straight: one band. Turned: down to the corner, then right; each
			# band runs half a belt past the corner, so the turn is filled.
			# [from, to, across] in logical tiles.
			var bands: Array = []
			if String(e.orientation) == "turn":
				var corner: Vector2 = (RIGHT - DOWN) * ACROSS * l
				bands.append([e.logical(-0.35, l), corner + DOWN * w, RIGHT])
				bands.append([corner - RIGHT * w, e.logical(LENGTH + 0.35, l), DOWN])
			else:
				bands.append([e.logical(-0.35, l), e.logical(LENGTH + 0.35, l), (e._across as Vector2).normalized()])
			var iso: LabIso = e.island.iso
			for band: Array in bands:
				var p0: Vector2 = band[0]
				var p1: Vector2 = band[1]
				var across: Vector2 = band[2]
				var a: Vector2 = iso.to_screen(p0 + across * w)
				var b: Vector2 = iso.to_screen(p1 + across * w)
				var c: Vector2 = iso.to_screen(p1 - across * w)
				var d: Vector2 = iso.to_screen(p0 - across * w)
				draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color("#4d5560"))
				rails.append_array([a, b, d, c])
			for x: float in [-0.35, LENGTH + 0.35]:
				draw_circle(e.at(x, l), 9.0, Color("#2f353c"))
			var step := 0.5
			var off := fmod(line.belt_phase, step)
			var x := -0.3 + off
			while x < LENGTH + 0.3:
				var p: Vector2 = e.at(x, l)
				var d2: Vector2 = (e.at(x + 0.02, l) - p).normalized()
				var n2 := d2.orthogonal()
				chevrons.append_array([p - d2 * 9.0 + n2 * 9.0, p, p, p - d2 * 9.0 - n2 * 9.0])
				x += step
		if not rails.is_empty():
			draw_multiline(rails, Color("#8d97a3"), 4.0)
			draw_multiline(chevrons, Color("#a9b3bd"), 3.0)


## The items, above the hopper, machine and crate (never hidden by them):
## raw ones drop out of the hopper as they appear, goods pop out of the
## machine, and each delivered one drops into the crate (presentation of a
## delivery already counted -- nothing here pays). Hidden while worked.
class _Items extends Node2D:
	var owner_exp: Node
	## Delivered items falling into the crate: {from, t}.
	var falling: Array[Dictionary] = []

	func delivered(it: Dictionary) -> void:
		var e = owner_exp
		falling.append({"from": e.at(LENGTH, float(it["lane"])), "t": 0.0})
		while falling.size() > 12:
			falling.pop_front()

	func _process(delta: float) -> void:
		if falling.is_empty():
			return
		for f: Dictionary in falling:
			f["t"] = float(f["t"]) + delta
		falling = falling.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 0.25)
		queue_redraw()

	func _draw() -> void:
		var e = owner_exp
		var line: TycoonLine = e.line
		var r := TycoonLevels.row(int(e.level))
		var raw := LabAtlas.texture(String(r["raw"]))
		var made := LabAtlas.texture(String(r["product"]))
		var still := bool(e.reduced_motion)
		var gap: float = e.item_gap()
		var shown := line.items.filter(func(it: Dictionary) -> bool: return not bool(it["in"]))
		shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["x"]) < float(b["x"]))
		for it: Dictionary in shown:
			var x := float(it["x"])
			var done := bool(it["done"])
			var tex: AtlasTexture = made if done else raw
			var p: Vector2 = e.at(x, float(it["lane"]))
			var k := gap / maxf(tex.region.size.x, tex.region.size.y)
			var lift := 0.0
			if not still:
				if not done and x < 0.35:
					# Dropping out of the hopper onto the belt.
					lift = (0.35 - x) / 0.35 * 46.0
				elif done and x < MACHINE_AT + 0.6:
					# Just out of the machine: a little pop.
					k *= 1.0 + 0.25 * sin(clampf((x - MACHINE_AT) / 0.6, 0.0, 1.0) * PI)
			var sz := tex.region.size * k
			draw_texture_rect(tex, Rect2(p - Vector2(sz.x * 0.5, sz.y * 0.85 + lift), sz), false)
		var crate_at: Vector2 = (e.crate as Sprite2D).position + Vector2(0, -30)
		for f: Dictionary in falling:
			var u := float(f["t"]) / 0.25
			var p := (f["from"] as Vector2).lerp(crate_at, u) + Vector2(0, -40.0 * sin(u * PI))
			var sz := made.region.size * (gap / maxf(made.region.size.x, made.region.size.y)) * (1.0 - 0.5 * u)
			draw_texture_rect(made, Rect2(p - sz * 0.5, sz), false, Color(1, 1, 1, 1.0 - u * 0.6))


## The machine's arms, one per arm: pressing while it works an item, with a
## ring that fills as that item's work goes (the second arm is the Second
## Arm upgrade you see).
class _Arms extends Node2D:
	var owner_exp: Node

	func _draw() -> void:
		var e = owner_exp
		var line: TycoonLine = e.line
		var working := line.items.filter(func(it: Dictionary) -> bool: return bool(it["in"]))
		for k in line.arms:
			# Over the belts where the machine works, side by side.
			var base: Vector2 = e.at(MACHINE_AT, float(line.lanes - 1) * 0.5) + Vector2(-60.0 + 34.0 * float(k), -64.0)
			var busy := k < working.size()
			var down := (0.5 + 0.5 * sin(float(e._time) * 8.0 + k * 1.3)) if busy and not bool(e.reduced_motion) else (0.5 if busy else 0.0)
			var tip := base + Vector2(8, 30 + 18 * down)
			draw_line(base, tip, Color("#4b3324"), 9.0)
			draw_line(base, tip, Color("#f2c230"), 6.0)
			draw_circle(base, 7.0, Color("#d9a520"))
			draw_circle(tip, 8.0, Color("#4b3324"))
			draw_circle(tip, 6.5, Color("#9aa4ae"))
			if busy:
				var left := float(working[k]["wait"]) / maxf(line.process, 0.01)
				var c := base + Vector2(0, -26)
				draw_circle(c, 13.0, Color(0.1, 0.14, 0.2, 0.7))
				draw_arc(c, 10.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - left), 20, Color("#7ed957"), 4.0)


# --- tests and the page ---------------------------------------------------------------------

## The line's rectangle in canvas pixels (what the camera frames).
func line_rect() -> Rect2:
	var b := line_bounds()
	var xf := island.get_global_transform()
	return Rect2(xf * b.position, b.size * world.scale)


func state() -> Dictionary:
	var lr := line_rect()
	var pa := play_area()
	var item_px := item_gap() * world.scale.y
	return {"coins": coins, "earned": earned, "level": level, "name": TycoonLevels.row(level)["name"], "lanes": line.lanes,
		"arms": line.arms, "helpers": helpers.size(), "machine": String(TycoonLevels.row(level)["machine"]),
		"spawned": line.spawned, "delivered": line.delivered, "on_belt": line.items.size(), "value": line.value,
		"unique_deliveries": _unique(line.delivered_ids), "deliveries_per_min": deliveries_per_min(),
		"next_cost": TycoonLevels.cost(level + 1), "belt_speed": line.speed, "orientation": orientation,
		"zoom": snappedf(world.scale.x, 0.01), "line_rect": [lr.position.x, lr.position.y, lr.size.x, lr.size.y],
		"play_rect": [pa.position.x, pa.position.y, pa.size.x, pa.size.y],
		"occupancy": snappedf((lr.size.x * lr.size.y) / maxf(pa.size.x * pa.size.y, 1.0), 0.01), "item_px": snappedf(item_px, 0.1),
		"deliveries_shown": deliveries_shown, "measuring": not _measure.is_empty()}


static func _unique(ids: Array[int]) -> bool:
	var seen := {}
	for i: int in ids:
		if seen.has(i):
			return false
		seen[i] = true
	return true


func dev(name: String, arg: Variant) -> Variant:
	match name:
		"coins":
			coins += int(arg)
			action_changed.emit()
			return {"ok": true, "coins": coins}
		"level":
			var to := int(arg)
			while level < to:
				coins += TycoonLevels.cost(level + 1)
				do_action()
			return {"ok": true, "level": level}
	return null
