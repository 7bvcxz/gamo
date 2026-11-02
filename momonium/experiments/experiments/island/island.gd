extends LabExperiment

## Experiment A -- Island Growth. The one growing object is the whole island:
## Momo earn coins by themselves, the one button upgrades the island, and
## every upgrade changes what is on screen -- coast rising out of the sea,
## a tree, a field, a house, another Momo, a town, a monument (IslandLevels).
## What the next upgrade adds stands on the island as a ghost before it is
## bought; from the Town on, the Monument's ghost waits in its corner.
## No tapping is needed: passive growth is the variable under test. (Until
## Step 93 the music joined at the Village; every experiment now plays the same
## soft music from the start, so sound does not tip the comparison.)

const POP_SECONDS := 1.4
const MAX_ZOOM := 1.15
const MIN_ZOOM := 0.55
const LEVEL_PIPS := 10

var coins := 0.0
var earned := 0.0
var level := 0

var world: Node2D
var island: LabIsland
var ocean: LabOcean
var things: Node2D
var ghosts: Node2D
var momos: Array[LabMomo] = []
var props: Dictionary = {}
var field_sprites: Array[Sprite2D] = []
var chip: PanelContainer
var chip_label: Label
var pips: Control

var _pop := 0.0
var _pops := 0
var _rng := RandomNumberGenerator.new()
var _zoom_tween: Tween
var _ghost_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 87
	ocean = LabOcean.new()
	add_child(ocean)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	island = LabIsland.new()
	island.reduced_motion = reduced_motion
	world.add_child(island)
	island.set_cells(IslandLevels.cells(0))
	ocean.follow(island)
	ghosts = Node2D.new()
	ghosts.name = "Ghosts"
	ghosts.y_sort_enabled = true
	island.add_child(ghosts)
	things = Node2D.new()
	things.name = "Things"
	things.y_sort_enabled = true
	island.add_child(things)
	for c: Vector2i in IslandLevels.FIELD_CELLS:
		var s := Sprite2D.new()
		s.centered = false
		s.visible = false
		s.position = island.iso.cell_center(c) + Vector2(0, 14)
		things.add_child(s)
		field_sprites.append(s)
	_build_chip()
	_apply(0, false)
	resized.connect(func() -> void: _frame(false))
	_frame(false)
	if audio != null:
		# The same soft music in every experiment (Step 93: a fair comparison).
		audio.start_ambience(true)


# --- the economy ----------------------------------------------------------------------

func tick(dt: float) -> void:
	var r := IslandLevels.rate(level)
	coins += r * dt
	earned += r * dt
	_pop += dt
	if _pop >= POP_SECONDS:
		_pop -= POP_SECONDS
		_show_income(r * POP_SECONDS)
	_ghost_time += dt
	_pulse_ghosts()
	session.metric("level", level)
	session.metric("coins", int(coins))
	session.metric("earned", int(earned))
	session.metric("rate", IslandLevels.rate(level))
	session.metric("stage", IslandLevels.stage(level))


func hud() -> Dictionary:
	return {"value": coins, "rate": IslandLevels.rate(level), "icon": "icon_coin"}


func next_cost() -> int:
	return IslandLevels.cost(level + 1)


func action_info() -> Dictionary:
	return {"label": "Upgrade Island", "cost": next_cost(), "affordable": coins >= next_cost(),
		"icon": String(IslandLevels.row(level + 1)["icon"])}


func do_action() -> void:
	var c := next_cost()
	if coins < c:
		return
	coins -= c
	var before := IslandLevels.stage(level)
	level += 1
	var stage := IslandLevels.stage(level)
	session.upgrade(level, c, {"stage": stage})
	_apply(level, true)
	if stage != before:
		session.milestone(stage, {"level": level})
		_celebrate(stage)
	elif audio != null:
		audio.play("built")
	for m: LabMomo in momos:
		m.cheer()
	action_changed.emit()


# --- what is on the island --------------------------------------------------------------

## Puts level `n`'s island on screen: its coast, props, path, field and Momo.
func _apply(n: int, animate: bool) -> void:
	island.add_cells(IslandLevels.cells(n), animate)
	island.paths.clear()
	for p: Vector2i in IslandLevels.paths(n):
		island.paths[p] = true
	island.queue_redraw()
	for p: Array in IslandLevels.props(n):
		var key := "%s@%d,%d" % [p[0], (p[1] as Vector2i).x, (p[1] as Vector2i).y]
		if props.has(key):
			continue
		var s := _sprite(String(p[0]), p[1])
		things.add_child(s)
		props[key] = s
		if animate and not reduced_motion:
			_pop_in(s, island.cells.has(p[1]))
	var crop := IslandLevels.field(n)
	for s: Sprite2D in field_sprites:
		s.visible = crop != ""
		if crop != "":
			_dress(s, crop, 0.85)
	var want := IslandLevels.momos(n)
	while momos.size() < want.size():
		var m := LabMomo.new()
		m.reduced_motion = reduced_motion
		m.position = island.iso.cell_center(want[momos.size()])
		m.arrived.connect(_wander.bind(m))
		things.add_child(m)
		momos.append(m)
		if not reduced_motion:
			_wander.call_deferred(m)
		if animate and not reduced_motion:
			_pop_in(m, true)
	_show_ghosts()
	_update_chip()
	if animate:
		_frame(true)


## The milestone stands taller than a house.
const BIG := {"momo_monument": 1.5}


func _sprite(name: String, cell: Vector2i) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.position = island.iso.cell_center(cell)
	_dress(s, name, float(BIG.get(name, 1.0)))
	s.set_meta("sprite", name)
	return s


func _dress(s: Sprite2D, name: String, k: float) -> void:
	s.texture = LabAtlas.texture(name)
	var sc := LabAtlas.world_scale(name) * k
	s.scale = Vector2(sc, sc)
	s.offset = -LabAtlas.pivot(name)


## A new thing grows out of the ground (or out of the coast rising under it).
func _pop_in(n: Node2D, delay: bool) -> void:
	var to := n.scale
	n.scale = to * 0.01
	var tw := n.create_tween()
	if delay:
		tw.tween_interval(LabIsland.RISE_SECONDS * 0.6)
	tw.tween_property(n, "scale", to, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A Momo strolls to a free cell nearby, rests, and goes on.
func _wander(m: LabMomo) -> void:
	if reduced_motion or not is_instance_valid(m) or not m.is_inside_tree():
		return
	var free := _free_cells()
	if free.is_empty():
		return
	var here := island.iso.to_logical(m.position)
	free.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (Vector2(a) + Vector2(0.5, 0.5)).distance_to(here) < (Vector2(b) + Vector2(0.5, 0.5)).distance_to(here))
	var pick := free[_rng.randi_range(0, mini(5, free.size() - 1))]
	var to := island.iso.cell_center(pick) + Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-8, 8))
	var tw := m.create_tween()
	tw.tween_interval(_rng.randf_range(1.5, 4.0))
	tw.tween_callback(m.walk_to.bind(to))


func _free_cells() -> Array[Vector2i]:
	var taken := {}
	for p: Array in IslandLevels.props(level):
		taken[p[1]] = true
	for c: Vector2i in IslandLevels.FIELD_CELLS:
		taken[c] = true
	var out: Array[Vector2i] = []
	for c: Vector2i in island.cells:
		if not taken.has(c):
			out.append(c)
	return out


# --- the teaser: what the next upgrade adds, as ghosts ------------------------------------

func _show_ghosts() -> void:
	for g: Node in ghosts.get_children():
		g.queue_free()
	island.ghost_cells.clear()
	var nxt := level + 1
	for c: Vector2i in IslandLevels.coast_of(nxt):
		if not island.cells.has(c):
			island.ghost_cells[c] = true
	var have := IslandLevels.props(level).map(func(p: Array) -> String: return "%s@%s" % [p[0], p[1]])
	for p: Array in IslandLevels.props(nxt):
		if not have.has("%s@%s" % [p[0], p[1]]):
			ghosts.add_child(_ghost(String(p[0]), p[1], 1.0))
	var now_momos := IslandLevels.momos(level).size()
	var next_momos := IslandLevels.momos(nxt)
	for i in range(now_momos, next_momos.size()):
		var m := LabMomo.new()
		m.position = island.iso.cell_center(next_momos[i])
		m.reduced_motion = true
		m.modulate = Color(1, 1, 1, 0.4)
		m.set_meta("ghost", true)
		ghosts.add_child(m)
	# The bigger milestone, seen from the Town on.
	if level >= 6 and nxt != IslandLevels.MONUMENT_LEVEL and level < IslandLevels.MONUMENT_LEVEL:
		for p: Array in IslandLevels.props(IslandLevels.MONUMENT_LEVEL):
			if String(p[0]) == "momo_monument":
				var g := _ghost("momo_monument", p[1], 0.55)
				g.set_meta("milestone", true)
				ghosts.add_child(g)
	island.queue_redraw()


func _ghost(name: String, cell: Vector2i, strength: float) -> Sprite2D:
	var s := _sprite(name, cell)
	s.modulate = Color(1.7, 1.7, 1.9, 0.5 * strength)
	s.set_meta("ghost", true)
	s.set_meta("strength", strength)
	return s


## The next upgrade's ghosts breathe when it is affordable.
func _pulse_ghosts() -> void:
	var ready := coins >= next_cost()
	var k := 0.5
	if ready:
		k = 0.75 if reduced_motion else 0.6 + 0.2 * sin(_ghost_time * TAU * 0.8)
	for g: Node in ghosts.get_children():
		var it := g as CanvasItem
		var strength := float(g.get_meta("strength", 1.0))
		it.modulate.a = (0.32 if g.has_meta("milestone") else k) * strength if g is Sprite2D else k
	island.ghost_alpha = k


# --- flourishes ------------------------------------------------------------------------------

## Passive income made visible: a coin and its amount rise from something on
## the island now and then (nothing with reduced motion -- the counter still
## climbs).
func _show_income(amount: float) -> void:
	if fx == null or reduced_motion:
		return
	var sources: Array[Node2D] = []
	for m: LabMomo in momos:
		sources.append(m)
	for s: Sprite2D in props.values():
		if String(s.get_meta("sprite")) in ["villa", "apartment", "clock_tower", "wind_turbine", "momo_monument", "park"]:
			sources.append(s)
	var src: Node2D = sources[_pops % sources.size()]
	_pops += 1
	var at := to_fx(src.get_global_transform() * Vector2(0, -50))
	fx.float_text(at, "+%d" % int(round(amount)), Color("#ffe27a"), 30)
	fx.coins(at, 1)
	if audio != null and _pops % 3 == 0:
		audio.play("coin", 1.1, -14.0)


func _celebrate(stage: String) -> void:
	if audio != null:
		audio.play("promote")
	if fx == null:
		return
	var centre := to_fx(island.get_global_transform() * island.screen_bounds().get_center())
	fx.float_text(centre + Vector2(0, -120), String(stage).capitalize() + "!", Color.WHITE, 64)
	fx.ring(centre, Color(1, 0.92, 0.55), 300.0)
	fx.coins(centre, 12, "icon_star")


# --- framing ------------------------------------------------------------------------------------

## Frames the island (with its ghosts and the tallest things on it) between
## the frame's top and its button. A tile keeps its size (MAX_ZOOM) while the
## island fits, so each upgrade makes the island bigger on screen; only when it
## would not fit does the view draw back, never below MIN_ZOOM.
func _frame(animate: bool) -> void:
	if size.x <= 0.0:
		return
	var b := island.screen_bounds()
	for c: Vector2i in island.ghost_cells:
		for p: Vector2 in island.iso.cell_corners(c):
			b = b.expand(p)
	for n: Node in things.get_children() + ghosts.get_children():
		var s := n as Sprite2D
		if s != null and s.visible and s.texture != null:
			b = b.expand(s.position + (s.offset * s.scale))
	b = b.grow(24.0)
	var area := Rect2(0, LabHost.TOP_UI + 64.0, size.x, size.y - LabHost.TOP_UI - 64.0 - LabHost.BOTTOM_UI)
	var k := clampf(minf(area.size.x / b.size.x, area.size.y / b.size.y), MIN_ZOOM, MAX_ZOOM)
	var pos := area.get_center() - b.get_center() * k
	if _zoom_tween != null:
		_zoom_tween.kill()
	if animate and not reduced_motion:
		_zoom_tween = create_tween().set_parallel(true)
		_zoom_tween.tween_property(world, "scale", Vector2(k, k), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_zoom_tween.tween_property(world, "position", pos, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		world.scale = Vector2(k, k)
		world.position = pos


func _build_chip() -> void:
	chip = PanelContainer.new()
	chip.name = "LevelChip"
	chip.add_theme_stylebox_override("panel", LabStyle.box(Color(1, 1, 1, 0.85), 22, Color(0, 0, 0, 0), 0, 3))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_label = LabStyle.label("", 26, LabStyle.INK)
	pips = _Pips.new()
	pips.custom_minimum_size = Vector2(LEVEL_PIPS * 20 + 26, 26)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip_label)
	row.add_child(pips)
	chip.add_child(row)
	add_child(chip)


func _update_chip() -> void:
	chip_label.text = "Lv %d · %s" % [level, IslandLevels.stage(level).capitalize()]
	(pips as _Pips).level = level
	pips.queue_redraw()
	chip.reset_size()
	chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and chip != null:
		chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


## Ten pips to the Monument: filled as the levels go, the last one a star.
class _Pips extends Control:
	var level := 0

	func _draw() -> void:
		var cy := size.y * 0.5
		for i in range(1, 11):
			var x := 10.0 + (i - 1) * 20.0
			var on := level >= i
			if i == 10:
				var pts := PackedVector2Array()
				for k in 10:
					var a := -PI / 2.0 + k * PI / 5.0
					var r := 12.0 if k % 2 == 0 else 5.0
					pts.append(Vector2(x + 6.0, cy) + Vector2(cos(a), sin(a)) * r)
				draw_colored_polygon(pts, LabStyle.GOLD if on else Color(0.6, 0.65, 0.7, 0.6))
			else:
				draw_circle(Vector2(x, cy), 6.0, LabStyle.LEAF if on else Color(0.6, 0.65, 0.7, 0.5))


# --- tests and the page ---------------------------------------------------------------------------

func state() -> Dictionary:
	var gb := island.get_global_transform() * island.screen_bounds()
	return {"coins": coins, "earned": earned, "level": level, "stage": IslandLevels.stage(level),
		"rate": IslandLevels.rate(level), "next_cost": next_cost(), "cells": island.cells.size(),
		"props": props.size(), "momos": momos.size(), "ghost_cells": island.ghost_cells.size(),
		"ghosts": ghosts.get_child_count(),
		"monument_ghost": ghosts.get_children().any(func(g: Node) -> bool: return String(g.get_meta("sprite", "")) == "momo_monument"),
		"island_rect": [gb.position.x, gb.position.y, gb.size.x, gb.size.y], "zoom": world.scale.x}


func dev(name: String, arg: Variant) -> Variant:
	match name:
		"coins":
			coins += float(arg)
			return {"ok": true, "coins": coins}
		"level":
			# Jumps to a level as if every upgrade had been bought (pictures, tests).
			var to := int(arg)
			while level < to:
				coins += next_cost()
				do_action()
			return {"ok": true, "level": level}
	return null
