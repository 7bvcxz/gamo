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
##     a helper, the belt, a lane, the goods), and once the first goods made
##     after it reach the crate the line says what it really did: deliveries
##     a minute before -> after (Step 98: measured from the arrivals' spacing
##     once the change has come down the line; Step 97 counted the ten
##     seconds straight after, which were goods already on the belt, and
##     could say "24 -> 18" for a faster hopper).
## Step 98 gave it thirty minutes (TycoonPlusLevels): after E's ten levels,
## twenty more you can see -- twin presses and robot arms, more lanes (up to
## six), a paint arch that colours the goods as they pass, gift wrap, the
## line branching into two crates, Momo at work along it, buildings rising
## beside it (wind, sun, a clock tower, a water wheel, a head office) -- with
## the next change shown as a faint shape where it will be (a building's
## silhouette, a dashed lane, the arch's outline) and a short celebration as
## each era opens. `?alt=grand` (dev): the button buys up to the end of the
## next bundle at once -- fewer, bigger transformations.
## Coins are only ever deliveries: nothing is paid that the crate did not
## receive. Effects and sounds are paced (one coin sound at most every
## SOUND_GAP), the belt's lines are drawn unantialiased in one call each
## (an antialiased line is a render object per segment: Steps 93 and 95).
## The baseline E (experiments/tycoon/) is never changed for any of this.

const MAX_ZOOM := 2.2
const MIN_ZOOM := 0.45
const RATE_WINDOW := 20.0
const SOUND_GAP := 0.35
## Deliveries within this many seconds are shown as one "+n".
const POP_GAP := 0.3
## How long the line is watched, from the first goods made after an
## upgrade reaching the crate, before it says what changed.
const MEASURE_FOR := 15.0
## A measurement whose first new goods have not arrived by then is dropped.
const MEASURE_GIVE_UP := 90.0
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
const MAX_LANES := 6
## Where the paint arch stands over the belts (line position).
const ARCH_AT := MACHINE_AT + 1.15
## Where each building rises beside the line (line position), in the order
## they come (TycoonPlusLevels.DECOR_ORDER).
const DECOR_AT: Array[float] = [0.6, 2.1, 3.6, 5.1, 6.4]

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
## The second crate (Second Crate: the line branches at its end).
var crate2: Sprite2D
## The factory's lit windows (Night Shift), drawn over the machine.
var machine_lit: Sprite2D
## The buildings standing beside the line: sprite name -> Sprite2D.
var decor: Dictionary = {}
var ghost: _Ghost
var eras: Array[String] = []
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
	crate2 = _sprite("prop_barrel")
	crate2.visible = false
	machine = _sprite("smelter")
	machine_lit = _overlay(machine, "car_factory_lit")
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
	ghost = _Ghost.new()
	ghost.owner_exp = self
	ghost.z_index = 6
	island.add_child(ghost)
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


## The lit windows of a building (the atlas's `<name>_lit`: only the
## windows, with their own pivot at the same ground point), over `base`.
func _overlay(base: Sprite2D, pic: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = LabAtlas.texture(pic)
	s.offset = -LabAtlas.pivot(pic)
	s.visible = false
	base.add_child(s)
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
	crate2.position = _crate2_spot()
	for i in helpers.size():
		helpers[i].position = _helper_spot(i)
	for name: String in decor:
		(decor[name] as Sprite2D).position = _decor_spot(name)


## The second crate: past the end, beside the first.
func _crate2_spot() -> Vector2:
	return at(LENGTH + 0.75, float(line.lanes) + 0.15)


## Where building `name` rises: beside the lanes, on the side away from the
## machine, in its turn along the line.
func _decor_spot(name: String) -> Vector2:
	var i := maxi(0, TycoonPlusLevels.DECOR_ORDER.find(name))
	return at(DECOR_AT[i], float(line.lanes - 1) + 1.65)


func _helper_spot(i: int) -> Vector2:
	# The loader beside the hopper, the packer beside the crate, then along
	# the line on the machine's side (clear of the machine).
	match i:
		0:
			return at(-0.7, -1.2)
		1:
			return at(LENGTH + 0.55, -1.2)
	var along: Array[float] = [1.0, 1.9, 5.0, 5.9]
	return at(along[mini(i - 2, along.size() - 1)], -1.25)


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
	if crate2.visible:
		r = r.merge(_sprite_rect(crate2, crate2.scale))
	for name: String in decor:
		var d: Sprite2D = decor[name]
		r = r.merge(_sprite_rect(d, d.get_meta("full_scale", d.scale)))
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
			if not _measure.is_empty():
				if float(_measure["start"]) < 0.0 and int(it["id"]) >= int(_measure["first_id"]):
					# The change has come down the line: watch from here.
					_measure["start"] = _time
				if float(_measure["start"]) >= 0.0:
					(_measure["times"] as Array).append(_time)
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
	if not _measure.is_empty():
		if float(_measure["start"]) >= 0.0 and _time >= float(_measure["start"]) + MEASURE_FOR:
			_tell_change()
		elif float(_measure["start"]) < 0.0 and _time >= float(_measure["since"]) + MEASURE_GIVE_UP:
			_measure = {}
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
	var r := per_min_from(_recent)
	if r >= 0.0:
		return r
	return snappedf(_recent.size() * 60.0 / clampf(_time, 1.0, RATE_WINDOW), 0.1)


## Deliveries a minute from arrival times, by their spacing: the arrivals
## after the first, over the time from the first to the last. Counting a
## fixed window instead is off by a whole delivery each way (18 or 24 for
## a steady 20 a minute), and lanes that arrive together count right this
## way. -1 when there is no spacing to read yet.
static func per_min_from(times: Array) -> float:
	if times.size() < 2:
		return -1.0
	var first := float(times[0])
	var span := float(times.back()) - first
	if span <= 0.0:
		return -1.0
	var after := 0
	for t: float in times:
		if t > first:
			after += 1
	return snappedf(after * 60.0 / span, 0.1)


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


## The level the button buys up to (the next one; with `?alt=grand` the end
## of the next bundle).
func target() -> int:
	return TycoonPlusLevels.next_target(level, variant == "grand")


func action_info() -> Dictionary:
	var to := target()
	var c := TycoonPlusLevels.price_to(level, to)
	var nxt := TycoonPlusLevels.row(to)
	var icon := "smelter"
	match String(nxt["show"]):
		"hopper":
			icon = "prop_crate"
		"arm", "belt", "lane", "sparkle", "machine", "paint", "wrap", "branch":
			icon = String(nxt["machine"])
		"helper":
			icon = "momo_front"
		"product":
			icon = String(nxt["product"])
		"decor":
			var list: Array = nxt["decor"]
			icon = String(list.back())
	return {"label": "Improve Line", "cost": c, "affordable": coins >= c, "icon": icon}


func do_action() -> void:
	var to := target()
	var c := TycoonPlusLevels.price_to(level, to)
	if coins < c:
		return
	var before := deliveries_per_min()
	var from := level
	coins -= c
	level = to
	var r := TycoonPlusLevels.row(level)
	session.upgrade(level, c, {"name": String(r["name"]), "show": String(r["show"]), "levels": level - from})
	_apply(true)
	_point_at_change(String(r["show"]), String(r["name"]))
	for n in range(from + 1, level + 1):
		if TycoonPlusLevels.era(n) != "":
			_celebrate(TycoonPlusLevels.era(n))
	# What it really does to the line, measured once the first goods made
	# after it (ids count up from 1 as items are made; TycoonLine is E's and
	# stays as it is) reach the crate -- only when it changes how many the line can
	# make (paint, a building, a better price: those show themselves).
	_measure = {}
	if TycoonPlusLevels.capacity(level) != TycoonPlusLevels.capacity(from):
		_measure = {"since": _time, "start": -1.0, "first_id": line.spawned + 1, "times": [], "before": before, "name": String(r["name"])}
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
		"paint", "wrap":
			where = at(ARCH_AT, float(line.lanes - 1) * 0.5)
		"branch":
			where = crate2.position
		"decor":
			var list: Array = TycoonPlusLevels.row(level)["decor"]
			if not list.is_empty() and decor.has(String(list.back())):
				where = (decor[String(list.back())] as Sprite2D).position
	var p := to_fx(island.get_global_transform() * where)
	fx.ring(p, Color(1, 0.95, 0.6), 150.0)
	_say(p + Vector2(0, -80), name + "!", Color.WHITE, 40)


## A floating word kept inside the screen: a building beside the line stands
## near its edge, and "Wind Power!" was cut to "Wind Pow" there.
func _say(at: Vector2, text: String, color: Color, size: int) -> void:
	var l := fx.float_text(at, text, color, size)
	var w := fx.get_viewport_rect().size.x
	l.position.x = clampf(l.position.x, 12.0, maxf(12.0, w - l.size.x - 12.0))


## A new era opens: a big ring over the line, its name, every Momo cheering.
func _celebrate(name: String) -> void:
	eras.append(name)
	session.milestone("era", {"name": name, "level": level})
	for m: LabMomo in helpers:
		m.cheer(1.2)
	if audio != null:
		audio.play("promote", 1.0, -3.0)
	if fx == null:
		return
	var centre := to_fx(island.get_global_transform() * at(LENGTH * 0.5, float(line.lanes - 1) * 0.5))
	fx.ring(centre, Color(1, 0.9, 0.5), 420.0)
	_say(centre + Vector2(0, -40), name + "!", Color("#ffe27a"), 54)


## MEASURE_FOR seconds after the change reached the crate: deliveries a
## minute before -> after, from what the crate really received.
func _tell_change() -> void:
	var after := maxf(0.0, per_min_from(_measure["times"]))
	session.milestone("output", {"upgrade": _measure["name"], "before_per_min": _measure["before"], "after_per_min": snappedf(after, 0.1)})
	if fx != null:
		var p := to_fx(island.get_global_transform() * crate.position) + Vector2(0, -150)
		_say(p, "%d → %d a min" % [int(round(float(_measure["before"]))), int(round(after))], Color("#c8f7a8"), 34)
	_measure = {}


func _apply(animate: bool) -> void:
	var r := TycoonPlusLevels.row(level)
	var lanes_before := line.lanes
	line.configure(r)
	if line.lanes != lanes_before and orientation != "":
		island.add_cells(_ground(line.lanes), animate)
	crate2.visible = bool(r["branch"])
	_dress(crate2, "prop_barrel", 1.8)
	for name: String in r["decor"]:
		if decor.has(name):
			continue
		var d := Sprite2D.new()
		d.centered = false
		stuff.add_child(d)
		_dress(d, name, 0.8)
		d.set_meta("full_scale", d.scale)
		if LabAtlas.has(name + "_lit"):
			_overlay(d, name + "_lit").visible = true
		decor[name] = d
		if animate and not reduced_motion:
			var full := d.scale
			d.scale = Vector2(full.x, 0.0)
			d.create_tween().tween_property(d, "scale", full, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dress(machine, String(r["machine"]), 1.45)
	machine_lit.visible = bool(r["lit"]) and LabAtlas.has(String(r["machine"]) + "_lit")
	if machine_lit.visible:
		machine_lit.texture = LabAtlas.texture(String(r["machine"]) + "_lit")
		machine_lit.offset = -LabAtlas.pivot(String(r["machine"]) + "_lit")
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
	ghost.queue_redraw()


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
	var r := TycoonPlusLevels.row(level)
	chip_label.text = "Line %d · %s · %d lane%s%s" % [level, r["name"], line.lanes, "" if line.lanes == 1 else "s", " · grand test" if variant == "grand" else ""]
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
		# Every band, rail, chevron and end cap in one triangle array: drawn as
		# separate commands, six lanes cost about 400 render objects (Step 98).
		var tris := _Tris.new()
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
				tris.quad(a, b, c, d, Color("#4d5560"))
				rails.append_array([a, b, d, c])
			for x: float in [-0.35, LENGTH + 0.35]:
				tris.disc(e.at(x, l), 9.0, Color("#2f353c"))
			var step := 0.5
			var off := fmod(line.belt_phase, step)
			var x := -0.3 + off
			while x < LENGTH + 0.3:
				var p: Vector2 = e.at(x, l)
				var d2: Vector2 = (e.at(x + 0.02, l) - p).normalized()
				var n2 := d2.orthogonal()
				chevrons.append_array([p - d2 * 9.0 + n2 * 9.0, p, p, p - d2 * 9.0 - n2 * 9.0])
				x += step
		tris.lines(rails, 4.0, Color("#8d97a3"))
		tris.lines(chevrons, 3.0, Color("#a9b3bd"))
		tris.draw(self)
		var r := TycoonPlusLevels.row(int(e.level))
		var paint: Color = r["paint"]
		if paint.a > 0.0 or bool(r["wrap"]):
			_arch(self, e, paint if paint.a > 0.0 else Color("#e8384f"), 1.0)
		if (e.crate2 as Sprite2D).visible:
			# The branch: a short chute from the line's end to the second crate.
			var end: Vector2 = e.at(LENGTH + 0.35, float(line.lanes - 1))
			var to: Vector2 = (e.crate2 as Sprite2D).position
			var n2 := (to - end).orthogonal().normalized() * 12.0
			draw_colored_polygon(PackedVector2Array([end + n2, to + n2, to - n2, end - n2]), Color("#4d5560"))

	## The paint arch over every lane at ARCH_AT, drawn on `ci`: two posts, a
	## beam in its colour, drips under it (`alpha` < 1: a ghost of it).
	static func _arch(ci: CanvasItem, e: Node, col: Color, alpha: float) -> void:
		var lanes: int = (e.get("line") as TycoonLine).lanes
		var left: Vector2 = e.call("at", ARCH_AT, -0.55)
		var right: Vector2 = e.call("at", ARCH_AT, float(lanes - 1) + 0.55)
		var up := Vector2(0, -78.0)
		var post := Color(Color("#5a4636"), alpha)
		ci.draw_line(left, left + up, post, 9.0)
		ci.draw_line(right, right + up, post, 9.0)
		ci.draw_line(left + up, right + up, Color(col, alpha), 14.0)
		ci.draw_line(left + up + Vector2(0, 7), right + up + Vector2(0, 7), Color(col.darkened(0.3), alpha), 3.0)
		var drips := PackedVector2Array()
		for k in 6:
			var p := (left + up).lerp(right + up, (float(k) + 0.5) / 6.0)
			drips.append_array([p + Vector2(0, 8), p + Vector2(0, 22)])
		ci.draw_multiline(drips, Color(col, 0.8 * alpha), 4.0)


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
		# With two crates, every other item goes to the second (presentation:
		# each was counted once, on delivery).
		var two: bool = (e.crate2 as Sprite2D).visible
		var to: Vector2 = ((e.crate2 if two and int(it["id"]) % 2 == 1 else e.crate) as Sprite2D).position + Vector2(0, -30)
		falling.append({"from": e.at(LENGTH, float(it["lane"])), "to": to, "t": 0.0})
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
		var r := TycoonPlusLevels.row(int(e.level))
		var paint: Color = r["paint"]
		var wrap := bool(r["wrap"])
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
			var rect := Rect2(p - Vector2(sz.x * 0.5, sz.y * 0.85 + lift), sz)
			# Past the arch the goods take its colour (and a ribbon).
			var past_arch := done and x >= ARCH_AT and paint.a > 0.0
			draw_texture_rect(tex, rect, false, Color.WHITE.lerp(paint, 0.7) if past_arch else Color.WHITE)
			if done and x >= ARCH_AT and wrap:
				draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.44, rect.size.y * 0.1), Vector2(rect.size.x * 0.12, rect.size.y * 0.8)), Color("#e8384f"))
				draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.1, rect.size.y * 0.44), Vector2(rect.size.x * 0.8, rect.size.y * 0.12)), Color("#e8384f"))
		for f: Dictionary in falling:
			var u := float(f["t"]) / 0.25
			var p := (f["from"] as Vector2).lerp(f["to"], u) + Vector2(0, -40.0 * sin(u * PI))
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
		var tris := _Tris.new()
		for k in line.arms:
			# Over the belts where the machine works, side by side.
			var base: Vector2 = e.at(MACHINE_AT, float(line.lanes - 1) * 0.5) + Vector2(-60.0 + 34.0 * float(k), -64.0)
			var busy := k < working.size()
			var down := (0.5 + 0.5 * sin(float(e._time) * 8.0 + k * 1.3)) if busy and not bool(e.reduced_motion) else (0.5 if busy else 0.0)
			var tip := base + Vector2(8, 30 + 18 * down)
			tris.line(base, tip, 9.0, Color("#4b3324"))
			tris.line(base, tip, 6.0, Color("#f2c230"))
			tris.disc(base, 7.0, Color("#d9a520"))
			tris.disc(tip, 8.0, Color("#4b3324"))
			tris.disc(tip, 6.5, Color("#9aa4ae"))
			if busy:
				var left := float(working[k]["wait"]) / maxf(line.process, 0.01)
				var c := base + Vector2(0, -26)
				tris.disc(c, 13.0, Color(0.1, 0.14, 0.2, 0.7), 14)
				var arc := PackedVector2Array()
				var a0 := -PI * 0.5
				var n := maxi(1, int(20.0 * (1.0 - left)))
				for j in n + 1:
					var t := a0 + TAU * (1.0 - left) * float(j) / float(n)
					arc.append(c + Vector2(cos(t), sin(t)) * 10.0)
				var segs := PackedVector2Array()
				for j in n:
					segs.append_array([arc[j], arc[j + 1]])
				tris.lines(segs, 4.0, Color("#7ed957"))
		tris.draw(self)


## Triangles from many small shapes, drawn in one command (one render
## object; each draw_line, draw_circle or multiline segment is one or more).
class _Tris extends RefCounted:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
		var base := pts.size()
		pts.append_array([a, b, c, d])
		for k in 4:
			cols.append(col)
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	## A straight stroke `width` wide, square-ended.
	func line(a: Vector2, b: Vector2, width: float, col: Color) -> void:
		var n := (b - a).orthogonal().normalized() * width * 0.5
		if n == Vector2.ZERO:
			return
		quad(a + n, b + n, b - n, a - n, col)

	## Segments as pairs of points (draw_multiline's layout).
	func lines(pairs: PackedVector2Array, width: float, col: Color) -> void:
		for k in range(0, pairs.size() - 1, 2):
			line(pairs[k], pairs[k + 1], width, col)

	func disc(c: Vector2, r: float, col: Color, n: int = 10) -> void:
		var base := pts.size()
		pts.append(c)
		cols.append(col)
		for k in n:
			var a := TAU * k / n
			pts.append(c + Vector2(cos(a), sin(a)) * r)
			cols.append(col)
		for k in n:
			idx.append_array([base, base + 1 + k, base + 1 + (k + 1) % n])

	func draw(ci: CanvasItem) -> void:
		if not idx.is_empty():
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## The next change, shown faintly where it will be: a building's
## silhouette on its spot, the next lane as a dashed band, the arch's outline,
## the second crate's silhouette, a Momo's shadow where it will work. Nothing
## for changes with no place of their own (a faster belt, a new machine:
## the button's picture shows those).
class _Ghost extends Node2D:
	var owner_exp: Node

	## What the ghost shows now ("" for nothing).
	func kind() -> String:
		var e = owner_exp
		var to: int = e.target()
		var level: int = e.level
		var r := TycoonPlusLevels.row(to)
		var now := TycoonPlusLevels.row(level)
		if (r["decor"] as Array).size() > (now["decor"] as Array).size():
			return "decor"
		if int(r["lanes"]) > int(now["lanes"]):
			return "lane"
		if bool(r["branch"]) and not bool(now["branch"]):
			return "branch"
		if ((r["paint"] as Color).a > 0.0 and r["paint"] != now["paint"]) or (bool(r["wrap"]) and not bool(now["wrap"])):
			return "arch"
		if int(r["helpers"]) > int(now["helpers"]):
			return "helper"
		return ""

	func _draw() -> void:
		var e = owner_exp
		var shade := Color(0.05, 0.1, 0.15, 0.3)
		var to: int = e.target()
		var r := TycoonPlusLevels.row(to)
		match kind():
			"decor":
				var have: Array = TycoonPlusLevels.row(int(e.level))["decor"]
				for name: String in r["decor"]:
					if have.has(name):
						continue
					var tex := LabAtlas.texture(name)
					var k := LabAtlas.world_scale(name) * 0.8
					var at: Vector2 = e.call("_decor_spot", name)
					draw_texture_rect(tex, Rect2(at - LabAtlas.pivot(name) * k, tex.get_size() * k), false, shade)
			"lane":
				var line: TycoonLine = e.line
				var dashes := PackedVector2Array()
				for lane in range(line.lanes, int(r["lanes"])):
					var x := -0.3
					while x < LENGTH + 0.3:
						dashes.append_array([e.at(x, float(lane) - BELT_HALF), e.at(minf(x + 0.25, LENGTH + 0.35), float(lane) - BELT_HALF)])
						dashes.append_array([e.at(x, float(lane) + BELT_HALF), e.at(minf(x + 0.25, LENGTH + 0.35), float(lane) + BELT_HALF)])
						x += 0.5
				if not dashes.is_empty():
					draw_multiline(dashes, Color(1, 1, 1, 0.55), 3.0)
			"branch":
				var tex := LabAtlas.texture("prop_barrel")
				var k := LabAtlas.world_scale("prop_barrel") * 1.8
				var at: Vector2 = e.call("_crate2_spot")
				draw_texture_rect(tex, Rect2(at - LabAtlas.pivot("prop_barrel") * k, tex.get_size() * k), false, shade)
			"arch":
				var now := TycoonPlusLevels.row(int(e.level))
				var paint: Color = r["paint"]
				var next := paint if paint.a > 0.0 and paint != now["paint"] else Color("#e8384f")
				if (now["paint"] as Color).a <= 0.0 and not bool(now["wrap"]):
					_Belts._arch(self, e, next, 0.45)
				else:
					# The arch stands: its next colour (or the ribbon's red) as a
					# dashed stripe over its beam. A faint second arch on top of
					# it blended the two colours into grey.
					var lanes: int = (e.line as TycoonLine).lanes
					var a0: Vector2 = e.at(ARCH_AT, -0.55) + Vector2(0, -96)
					var a1: Vector2 = e.at(ARCH_AT, float(lanes - 1) + 0.55) + Vector2(0, -96)
					var dashes := PackedVector2Array()
					for k in 8:
						dashes.append_array([a0.lerp(a1, float(k) / 8.0), a0.lerp(a1, (float(k) + 0.6) / 8.0)])
					draw_multiline(dashes, Color(next, 0.9), 7.0)
			"helper":
				var helpers: Array = e.helpers
				var at: Vector2 = e.call("_helper_spot", helpers.size())
				draw_circle(at + Vector2(0, -34), 20.0, shade)
				draw_set_transform(at + Vector2(0, -2), 0.0, Vector2(1.0, 0.35))
				draw_circle(Vector2.ZERO, 26.0, shade)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	var r := TycoonPlusLevels.row(level)
	return {"coins": coins, "earned": earned, "level": level, "name": r["name"], "lanes": line.lanes,
		"arms": line.arms, "helpers": helpers.size(), "machine": String(r["machine"]), "decor": decor.keys(), "branch": crate2.visible,
		"painted": (r["paint"] as Color).a > 0.0, "wrapped": bool(r["wrap"]), "eras": eras, "target": target(),
		"next_show": String(TycoonPlusLevels.row(target())["show"]), "ghost": ghost.kind(), "variant": variant,
		"spawned": line.spawned, "delivered": line.delivered, "on_belt": line.items.size(), "value": line.value,
		"unique_deliveries": _unique(line.delivered_ids), "deliveries_per_min": deliveries_per_min(),
		"next_cost": TycoonPlusLevels.price_to(level, target()), "belt_speed": line.speed, "orientation": orientation,
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
				coins += TycoonPlusLevels.price_to(level, target())
				do_action()
			return {"ok": true, "level": level}
	return null
