extends LabExperiment

## Experiment E -- Production Tycoon. One small production line on the
## island: raw items drop from a hopper onto a belt, ride into a machine,
## come out as goods and fall into a crate at the end -- each delivery paying
## coins (TycoonLine, item by item). The one button, Improve Production Line,
## makes the line livelier in a way you can see: a bigger hopper, a second arm
## on the machine, a better machine and product, Momo helpers, a faster belt,
## a second and a third lane (TycoonLevels). No placing, no recipes, no
## management: the hypothesis is the joy of watching production grow.
## Effects are paced, not multiplied: the coins delivered are shown together
## every POP_SECONDS, and a coin sound at most every SOUND_SECONDS.

const MAX_ZOOM := 1.2
const MIN_ZOOM := 0.5
const POP_SECONDS := 0.8
const SOUND_SECONDS := 1.2
const RATE_WINDOW := 10.0
const LANE_GAP := 0.6
const X0 := 0.2

var coins := 0
var earned := 0
var level := 0
var line := TycoonLine.new()

var world: Node2D
var island: LabIsland
var ocean: LabOcean
var stuff: Node2D
var belts: _Belts
var arms: _Arms
var machine: Sprite2D
var hopper: Sprite2D
var crate: Sprite2D
var helpers: Array[LabMomo] = []
var chip: PanelContainer
var chip_label: Label
var _pop := 0.0
var _pop_coins := 0
var _sound := 0.0
var _recent: Array = []
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ocean = LabOcean.new()
	add_child(ocean)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	island = LabIsland.new()
	var cells: Array[Vector2i] = []
	for x in range(-1, 8):
		for y in range(0, 4):
			cells.append(Vector2i(x, y))
	island.set_cells(cells)
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
	arms = _Arms.new()
	arms.owner_exp = self
	arms.z_index = 3
	island.add_child(arms)
	_build_chip()
	_apply(false)
	resized.connect(_frame)
	_frame()
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


## Where line position `x` of lane `lane` is on the island.
func at(x: float, lane: int) -> Vector2:
	return island.iso.to_screen(Vector2(X0 + x, lane_y(lane)))


func lane_y(lane: int) -> float:
	return 0.9 + LANE_GAP * float(lane)


# --- running the line ----------------------------------------------------------------

func tick(dt: float) -> void:
	line.advance(dt)
	_time += dt
	var got := line.just_delivered.size() * line.value
	if got > 0:
		coins += got
		earned += got
		_pop_coins += got
		for i in line.just_delivered.size():
			_recent.append(_time)
	while not _recent.is_empty() and float(_recent[0]) < _time - RATE_WINDOW:
		_recent.pop_front()
	_pop += dt
	_sound += dt
	if _pop >= POP_SECONDS and _pop_coins > 0:
		_pop = 0.0
		_show_delivery(_pop_coins)
		_pop_coins = 0
	belts.queue_redraw()
	arms.queue_redraw()
	session.metric("level", level)
	session.metric("coins", coins)
	session.metric("earned", earned)
	session.metric("units_made", line.spawned)
	session.metric("delivered", line.delivered)
	session.metric("deliveries_per_min", deliveries_per_min())
	if got > 0:
		action_changed.emit()


## Deliveries a minute over the last RATE_WINDOW seconds of play.
func deliveries_per_min() -> float:
	return snappedf(_recent.size() * 60.0 / RATE_WINDOW, 0.1) if _time >= RATE_WINDOW else snappedf(_recent.size() * 60.0 / maxf(_time, 1.0), 0.1)


func hud() -> Dictionary:
	return {"value": coins, "rate": snappedf(deliveries_per_min() * line.value / 60.0, 0.1), "icon": "icon_coin"}


func action_info() -> Dictionary:
	var c := TycoonLevels.cost(level + 1)
	var nxt := TycoonLevels.row(level + 1)
	var icon := "smelter"
	match String(nxt["show"]):
		"hopper":
			icon = "prop_crate"
		"arm", "belt", "lane", "sparkle":
			icon = String(nxt["machine"])
		"machine":
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
	coins -= c
	level += 1
	var r := TycoonLevels.row(level)
	session.upgrade(level, c, {"name": String(r["name"]), "show": String(r["show"])})
	_apply(true)
	if fx != null:
		var where := to_fx(island.get_global_transform() * at(TycoonLine.MACHINE_AT, line.lanes - 1)) + Vector2(0, -90)
		fx.float_text(where, String(r["name"]) + "!", Color.WHITE, 40)
		fx.ring(where + Vector2(0, 60), Color(1, 0.95, 0.6), 200.0)
	if audio != null:
		audio.play("built", 1.0, -2.0)
	action_changed.emit()


func _apply(animate: bool) -> void:
	var r := TycoonLevels.row(level)
	line.configure(r)
	_dress(machine, String(r["machine"]), 1.45)
	var mid := lane_y(0) + LANE_GAP * float(line.lanes - 1) * 0.5
	machine.position = island.iso.to_screen(Vector2(X0 + TycoonLine.MACHINE_AT + 0.15, lane_y(0) - 0.45))
	_dress(hopper, "prop_crate", 1.6 + 0.4 * float(level >= 1))
	hopper.position = island.iso.to_screen(Vector2(X0 - 0.75, mid))
	_dress(crate, "prop_barrel", 1.8)
	crate.position = island.iso.to_screen(Vector2(X0 + TycoonLine.LENGTH + 0.55, mid))
	while helpers.size() < int(r["helpers"]):
		var m := LabMomo.new()
		m.reduced_motion = reduced_motion
		m.work_anim = "work_stoke" if helpers.is_empty() else "work_hammer"
		var spot := Vector2(X0 - 0.6, mid + 1.0) if helpers.is_empty() else Vector2(X0 + TycoonLine.LENGTH + 0.4, mid + 1.0)
		m.position = island.iso.to_screen(spot)
		stuff.add_child(m)
		helpers.append(m)
		if animate and not reduced_motion:
			m.scale = Vector2.ZERO
			m.create_tween().tween_property(m, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if animate and not reduced_motion:
		var target := machine.scale
		machine.scale = target * 0.6
		machine.create_tween().tween_property(machine, "scale", target, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_chip()
	belts.queue_redraw()


func _process(delta: float) -> void:
	# The helpers work on their own loops (presentation only).
	if reduced_motion:
		return
	for m: LabMomo in helpers:
		m.work_t += delta


func _show_delivery(amount: int) -> void:
	if fx == null:
		return
	var at_crate := to_fx(crate.get_global_transform() * Vector2(0, -30))
	fx.float_text(at_crate + Vector2(0, -30), "+%d" % amount, Color("#ffe27a"), 32)
	if not reduced_motion:
		fx.coins(at_crate, 1)
	if audio != null and _sound >= SOUND_SECONDS:
		_sound = 0.0
		audio.play("coin", 1.1, -12.0)


func _frame() -> void:
	if size.x <= 0.0:
		return
	var b := island.screen_bounds().grow(24.0)
	b = b.expand(b.position - Vector2(0, 90))
	var area := Rect2(0, LabHost.TOP_UI + 64.0, size.x, size.y - LabHost.TOP_UI - 64.0 - LabHost.BOTTOM_UI)
	var k := clampf(minf(area.size.x / b.size.x, area.size.y / b.size.y), MIN_ZOOM, MAX_ZOOM)
	world.scale = Vector2(k, k)
	world.position = area.get_center() - b.get_center() * k


func _build_chip() -> void:
	chip = PanelContainer.new()
	chip.name = "LineChip"
	chip.add_theme_stylebox_override("panel", LabStyle.box(Color(1, 1, 1, 0.85), 22, Color(0, 0, 0, 0), 0, 3))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_label = LabStyle.label("", 26, LabStyle.INK)
	chip.add_child(chip_label)
	add_child(chip)


func _update_chip() -> void:
	var r := TycoonLevels.row(level)
	chip_label.text = "Line %d · %s · %d lane%s" % [level, r["name"], line.lanes, "" if line.lanes == 1 else "s"]
	chip.reset_size()
	chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and chip != null:
		chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


## The belts and the items on them, drawn from the line.
class _Belts extends Node2D:
	var owner_exp: Node

	func _draw() -> void:
		var e = owner_exp
		var line: TycoonLine = e.line
		var r := TycoonLevels.row(int(e.level))
		var raw := LabAtlas.texture(String(r["raw"]))
		var made := LabAtlas.texture(String(r["product"]))
		for lane in line.lanes:
			var y: float = e.lane_y(lane)
			var a: Vector2 = e.island.iso.to_screen(Vector2(X0 - 0.2, y - 0.24))
			var b: Vector2 = e.island.iso.to_screen(Vector2(X0 + TycoonLine.LENGTH + 0.2, y - 0.24))
			var c: Vector2 = e.island.iso.to_screen(Vector2(X0 + TycoonLine.LENGTH + 0.2, y + 0.24))
			var d: Vector2 = e.island.iso.to_screen(Vector2(X0 - 0.2, y + 0.24))
			draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color("#4d5560"))
			draw_polyline(PackedVector2Array([a, b]), Color("#7d8794"), 3.0, true)
			draw_polyline(PackedVector2Array([d, c]), Color("#2f353c"), 3.0, true)
			# Chevrons riding the belt.
			var step := 0.5
			var off := fmod(line.belt_phase * 1.0, step)
			var x := -0.2 + off
			while x < TycoonLine.LENGTH + 0.2:
				var p: Vector2 = e.island.iso.to_screen(Vector2(X0 + x, y))
				var q: Vector2 = e.island.iso.to_screen(Vector2(X0 + x - 0.12, y - 0.1))
				var w: Vector2 = e.island.iso.to_screen(Vector2(X0 + x - 0.12, y + 0.1))
				draw_polyline(PackedVector2Array([q, p, w]), Color("#9aa4ae"), 3.0, true)
				x += step
		# The items: raw before the machine, goods after it, hidden inside.
		for it: Dictionary in line.items:
			if bool(it["in"]):
				continue
			var tex: AtlasTexture = made if bool(it["done"]) else raw
			var p: Vector2 = e.at(float(it["x"]), int(it["lane"]))
			var sz := tex.region.size * 0.36
			draw_texture_rect(tex, Rect2(p - Vector2(sz.x * 0.5, sz.y * 0.85), sz), false)


## The machine's arms, in front of it: one per arm, pressing down while the
## machine works an item (the second arm is the Second Arm upgrade you see).
class _Arms extends Node2D:
	var owner_exp: Node

	func _draw() -> void:
		var e = owner_exp
		var line: TycoonLine = e.line
		var m: Sprite2D = e.machine
		var busy := line.items.filter(func(it: Dictionary) -> bool: return bool(it["in"])).size()
		for k in line.arms:
			var base: Vector2 = m.position + Vector2(-34.0 + 30.0 * k, -48.0)
			var down := (0.5 + 0.5 * sin(float(e._time) * 8.0 + k * 1.3)) if k < busy else 0.0
			var tip := base + Vector2(8, 30 + 18 * down)
			draw_line(base, tip, Color("#4b3324"), 9.0, true)
			draw_line(base, tip, Color("#f2c230"), 6.0, true)
			draw_circle(base, 7.0, Color("#d9a520"))
			draw_circle(tip, 8.0, Color("#4b3324"))
			draw_circle(tip, 6.5, Color("#9aa4ae"))


# --- tests and the page ---------------------------------------------------------------------

func state() -> Dictionary:
	return {"coins": coins, "earned": earned, "level": level, "name": TycoonLevels.row(level)["name"], "lanes": line.lanes,
		"arms": line.arms, "helpers": helpers.size(), "machine": String(TycoonLevels.row(level)["machine"]),
		"spawned": line.spawned, "delivered": line.delivered, "on_belt": line.items.size(), "value": line.value,
		"unique_deliveries": _unique(line.delivered_ids), "deliveries_per_min": deliveries_per_min(),
		"next_cost": TycoonLevels.cost(level + 1), "belt_speed": line.speed}


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
