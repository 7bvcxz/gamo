extends LabExperiment

## Experiment D -- Harvest Burst. One field on the island fills by itself:
## seeds, sprouts, leaves, then ripe crops all at once (GROW_SECONDS of play).
## Ripe, it waits -- nothing harvests itself -- and the one button turns into
## Harvest All: a wave runs across the field, every crop pops into the air
## and becomes coins, a big number, and the field starts again from seeds.
## Between harvests the same button offers Bigger Field when it can be paid
## (more cells, more plants, and golden crops that pay more), or shows how far
## the field has grown. The hypothesis is the anticipation of one burst.

const MAX_ZOOM := 1.2
const MIN_ZOOM := 0.5
const WAVE_STEP := 0.035
## After a harvest the button rests this long (play seconds) before it can
## buy anything: a quick second tap must not spend the payout by accident.
const AFTER_HARVEST := 0.6

var coins := 0
var earned := 0
var level := 0
var progress := 0.0
var ripe := false
var harvests := 0
var last_payout := 0
var ready_wait_ms := 0.0
var _this_wait_ms := 0.0
var _rest := 0.0

var world: Node2D
var island: LabIsland
var ocean: LabOcean
var crops: Node2D
var momo: LabMomo
var chip: PanelContainer
var chip_label: Label
var plants: Array[Sprite2D] = []
var _stage := -1
var _time := 0.0
var _zoom_tween: Tween
var _harvest_anim := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ocean = LabOcean.new()
	add_child(ocean)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	island = LabIsland.new()
	island.reduced_motion = reduced_motion
	world.add_child(island)
	island.set_cells(_island_cells(0))
	ocean.follow(island)
	crops = Node2D.new()
	crops.name = "Crops"
	crops.y_sort_enabled = true
	island.add_child(crops)
	momo = LabMomo.new()
	momo.reduced_motion = reduced_motion
	crops.add_child(momo)
	_build_chip()
	_apply(false)
	resized.connect(func() -> void: _frame(false))
	_frame(false)
	if audio != null:
		audio.start_ambience(true)


func _island_cells(n: int) -> Array[Vector2i]:
	var f: Array = HarvestLevels.row(n)["field"]
	var out: Array[Vector2i] = []
	for x in range(-1, int(f[0]) + 1):
		for y in range(-1, int(f[1]) + 1):
			out.append(Vector2i(x, y))
	return out


# --- growing and waiting --------------------------------------------------------------

func tick(dt: float) -> void:
	if _rest > 0.0:
		_rest = maxf(0.0, _rest - dt)
		if _rest == 0.0:
			action_changed.emit()
	if not ripe:
		progress = minf(1.0, progress + dt / HarvestLevels.GROW_SECONDS)
		if progress >= 1.0:
			ripe = true
			_this_wait_ms = 0.0
			if fx != null:
				fx.float_text(to_fx(_field_centre()) + Vector2(0, -80), "Ready!", Color("#ffe27a"), 44)
			if audio != null:
				audio.play("soft", 1.2, -4.0)
			action_changed.emit()
	else:
		ready_wait_ms += dt * 1000.0
		_this_wait_ms += dt * 1000.0
	_time += dt
	_show_growth()
	session.metric("level", level)
	session.metric("coins", coins)
	session.metric("earned", earned)
	session.metric("harvests", harvests)
	session.metric("last_payout", last_payout)
	session.metric("plants", HarvestLevels.plants(level))
	session.metric("ready_wait_s", snappedf(ready_wait_ms / 1000.0, 0.1))
	session.metric("early_presses", int(session.counts.get("button_refused", 0)))


func hud() -> Dictionary:
	return {"value": coins, "rate": 0.0, "icon": "icon_coin"}


func action_info() -> Dictionary:
	if ripe:
		return {"label": "Harvest All", "cost": -1, "affordable": true, "icon": "crop_ripe", "kind": "harvest"}
	if _rest > 0.0:
		return {"label": "+%d!" % last_payout, "cost": -1, "affordable": true, "icon": "icon_coin", "kind": "rest"}
	var c := HarvestLevels.cost(level + 1)
	if coins >= c:
		return {"label": "Bigger Field", "cost": c, "affordable": true, "icon": "ui_land", "kind": "upgrade"}
	return {"label": "Growing %d%%" % int(floor(progress * 100.0)), "cost": -1, "affordable": false, "icon": "crop_sprout", "kind": "growing"}


func do_action() -> void:
	if _rest > 0.0:
		session.action("tap_after_harvest")
		return
	if ripe:
		_harvest()
	elif coins >= HarvestLevels.cost(level + 1):
		_upgrade()


## The burst: everything ripe, at once, exactly once.
func _harvest() -> void:
	ripe = false
	progress = 0.0
	_rest = AFTER_HARVEST
	var pay := HarvestLevels.payout(level)
	coins += pay
	earned += pay
	harvests += 1
	last_payout = pay
	session.milestone("harvest", {"n": harvests, "coins": pay, "plants": HarvestLevels.plants(level), "waited_s": snappedf(_this_wait_ms / 1000.0, 0.1)})
	_stage = -1
	if not reduced_motion:
		_wave()
	_show_growth()
	if fx != null:
		var centre := to_fx(_field_centre())
		fx.float_text(centre + Vector2(0, -60), "+%d" % pay, Color("#ffe27a"), 72)
		fx.coins(centre, clampi(plants.size(), 6, 18))
		fx.ring(centre, Color(1, 0.95, 0.6), 260.0)
	momo.cheer(1.4)
	_harvest_anim = 0.0
	if audio != null:
		audio.play("harvest", 1.0, 0.0)
		audio.play("coin", 1.05, -3.0)
	action_changed.emit()


func _upgrade() -> void:
	var c := HarvestLevels.cost(level + 1)
	coins -= c
	level += 1
	session.upgrade(level, c, {"plants": HarvestLevels.plants(level), "yield": int(HarvestLevels.row(level)["yield"]), "payout": HarvestLevels.payout(level)})
	_apply(true)
	if fx != null:
		fx.float_text(to_fx(_field_centre()) + Vector2(0, -40), "x%d a harvest" % HarvestLevels.payout(level), Color.WHITE, 40)
	if audio != null:
		audio.play("land", 1.0, -2.0)
	action_changed.emit()


# --- the field ------------------------------------------------------------------------------

func _apply(animate: bool) -> void:
	island.add_cells(_island_cells(level), animate)
	var cells := HarvestLevels.cells(level)
	island.soil.clear()
	for c: Vector2i in cells:
		island.soil[c] = true
	island.queue_redraw()
	var want := cells.size() * HarvestLevels.PLANTS_PER_CELL
	while plants.size() < want:
		var s := Sprite2D.new()
		s.centered = false
		crops.add_child(s)
		plants.append(s)
		if animate and not reduced_motion:
			s.scale = Vector2.ZERO
	var i := 0
	for c: Vector2i in cells:
		for k in HarvestLevels.PLANTS_PER_CELL:
			var off := Vector2(-0.22, 0.2) if k == 0 else Vector2(0.24, -0.12)
			plants[i].position = island.iso.to_screen(Vector2(c) + Vector2(0.5, 0.5) + off)
			plants[i].set_meta("order", c.x + c.y)
			i += 1
	var f: Array = HarvestLevels.row(level)["field"]
	momo.position = island.iso.cell_center(Vector2i(-1, int(f[1]))) + Vector2(10, -6)
	_stage = -1
	_show_growth()
	_update_chip()
	_frame(animate)


func _stage_of(p: float) -> int:
	if p >= 1.0:
		return 3
	if p >= 0.55:
		return 2
	if p >= 0.25:
		return 1
	return 0


const STAGE_SPRITES: Array[String] = ["crop_seeds", "crop_sprout", "crop_leafy", "crop_ripe"]


func _show_growth() -> void:
	var st := _stage_of(progress)
	if st != _stage:
		_stage = st
		var golden := bool(HarvestLevels.row(level).get("golden", false)) or level >= 3
		for s: Sprite2D in plants:
			if s.has_meta("popping"):
				continue
			var pic := STAGE_SPRITES[st]
			s.texture = LabAtlas.texture(pic)
			var k := LabAtlas.world_scale(pic) * (1.0 if st == 3 else 0.9)
			s.scale = Vector2(k, k)
			s.offset = -LabAtlas.pivot(pic)
			s.modulate = Color(1.25, 1.1, 0.55) if st == 3 and golden else Color.WHITE
			s.set_meta("base_scale", k)


func _process(delta: float) -> void:
	# Anticipation: the crops sway more as they near ripeness, and bob when ripe.
	if reduced_motion or plants.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0
	var near := clampf((progress - 0.75) / 0.25, 0.0, 1.0)
	for i in plants.size():
		var s := plants[i]
		if s.has_meta("popping") or not s.has_meta("base_scale"):
			continue
		var phase := t * (2.5 + near * 3.0) + float(i) * 0.7
		s.rotation = sin(phase) * (0.03 + near * 0.1) if not ripe else sin(phase) * 0.06
		var k := float(s.get_meta("base_scale"))
		var bob := (1.0 + 0.06 * absf(sin(phase))) if ripe else 1.0
		s.scale = Vector2(k, k * bob)
	if _harvest_anim >= 0.0:
		_harvest_anim += delta
		momo.work_anim = "work_harvest"
		momo.work_t = _harvest_anim
		if _harvest_anim > LabMomo.loop_seconds("work_harvest"):
			_harvest_anim = -1.0
			momo.work_anim = ""


## Each crop pops in turn, corner to corner, and flies up as the field
## behind it starts over from seeds.
func _wave() -> void:
	var pic := "crop_ripe"
	for s: Sprite2D in plants:
		var ghost := Sprite2D.new()
		ghost.centered = false
		ghost.texture = LabAtlas.texture(pic)
		var k := LabAtlas.world_scale(pic) * 1.0
		ghost.scale = Vector2(k, k)
		ghost.offset = -LabAtlas.pivot(pic)
		ghost.position = s.position
		ghost.modulate = s.modulate if s.modulate != Color.WHITE else Color.WHITE
		crops.add_child(ghost)
		var delay := WAVE_STEP * float(int(s.get_meta("order", 0)))
		var tw := ghost.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(ghost, "scale", Vector2(k, k) * 1.35, 0.08)
		tw.parallel().tween_property(ghost, "position:y", s.position.y - 60.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
		tw.tween_callback(ghost.queue_free)


func _field_centre() -> Vector2:
	var f: Array = HarvestLevels.row(level)["field"]
	return island.get_global_transform() * island.iso.to_screen(Vector2(float(f[0]), float(f[1])) * 0.5)


func _frame(animate: bool) -> void:
	if size.x <= 0.0:
		return
	var b := island.screen_bounds().grow(30.0)
	b = b.expand(b.position - Vector2(0, 60))
	var area := Rect2(0, LabHost.TOP_UI + 64.0, size.x, size.y - LabHost.TOP_UI - 64.0 - LabHost.BOTTOM_UI)
	var k := clampf(minf(area.size.x / b.size.x, area.size.y / b.size.y), MIN_ZOOM, MAX_ZOOM)
	var pos := area.get_center() - b.get_center() * k
	if _zoom_tween != null:
		_zoom_tween.kill()
	if animate and not reduced_motion:
		_zoom_tween = create_tween().set_parallel(true)
		_zoom_tween.tween_property(world, "scale", Vector2(k, k), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_zoom_tween.tween_property(world, "position", pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		world.scale = Vector2(k, k)
		world.position = pos


func _build_chip() -> void:
	chip = PanelContainer.new()
	chip.name = "FieldChip"
	chip.add_theme_stylebox_override("panel", LabStyle.box(Color(1, 1, 1, 0.85), 22, Color(0, 0, 0, 0), 0, 3))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_label = LabStyle.label("", 26, LabStyle.INK)
	chip.add_child(chip_label)
	add_child(chip)


func _update_chip() -> void:
	chip_label.text = "Field %d · %d plants · %d a harvest" % [level, HarvestLevels.plants(level), HarvestLevels.payout(level)]
	chip.reset_size()
	chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and chip != null:
		chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


# --- tests and the page ---------------------------------------------------------------------------

func state() -> Dictionary:
	var gb := island.get_global_transform() * island.screen_bounds()
	return {"coins": coins, "earned": earned, "level": level, "progress": progress, "ripe": ripe, "harvests": harvests,
		"last_payout": last_payout, "payout": HarvestLevels.payout(level), "plants": plants.size(), "stage": _stage,
		"next_cost": HarvestLevels.cost(level + 1), "ready_wait_s": ready_wait_ms / 1000.0, "button": String(action_info().get("kind", "")),
		"island_rect": [gb.position.x, gb.position.y, gb.size.x, gb.size.y], "cells": island.cells.size()}


func dev(name: String, arg: Variant) -> Variant:
	match name:
		"coins":
			coins += int(arg)
			action_changed.emit()
			return {"ok": true, "coins": coins}
		"level":
			var to := int(arg)
			while level < to:
				coins += HarvestLevels.cost(level + 1)
				_upgrade()
			return {"ok": true, "level": level}
		"ripen":
			progress = 1.0
			ripe = true
			action_changed.emit()
			return {"ok": true}
	return null
