class_name WatchEditor
extends Control

## Editing what a Momo looks after, by hand.
##
## A selected Momo shows its tiles (WatchOverlay) and a small pencil above
## its head. The pencil starts editing: then a tap on a tile adds it or takes
## it away, and a stroke across tiles does to every tile it crosses what was
## done to the first one (first tile watched: the stroke removes; otherwise it
## adds) -- never flipping a tile back within one stroke. While editing, one
## finger paints instead of panning; two fingers still pan and zoom (and a
## stroke they interrupt is undone); the right mouse button pans. The pencil,
## now a check, ends editing, as does a tap on the sea or Esc. Tiles that cannot
## be taken (sea, a building with no Momo work, too many) flash red; the count
## beside the button says how many of how many.
##
## An InputRouter drag handler, registered before the Momo drag, so while
## editing the stroke wins over picking a Momo up.

signal editing_changed(on: bool)

const BUTTON := Vector2(52, 52)

var sim: Simulation
var momos: MomoSystem
var cameras: CameraController
var projection: IsoProjection
var momo_views: MomoViews
var overlay: WatchOverlay
var momo := 0
var active := false
var pencil: Button
## Where the pencil waits: the selected Momo's card on screen (Rect2() when none).
var anchor: Callable
var count_label: Label
var count_pill: PanelContainer
var last_result: Dictionary = {}
var _op := ""
var _touched: Dictionary = {}
var _changed: Array[Vector2i] = []
var _last_world := Vector2.ZERO
var _stroking := false


func setup(p_sim: Simulation, p_cameras: CameraController, p_projection: IsoProjection, p_momo_views: MomoViews, p_overlay: WatchOverlay) -> void:
	sim = p_sim
	momos = sim.system(&"momo")
	cameras = p_cameras
	projection = p_projection
	momo_views = p_momo_views
	overlay = p_overlay
	name = "WatchEditor"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pencil = Button.new()
	pencil.name = "Pencil"
	pencil.custom_minimum_size = BUTTON
	pencil.size = BUTTON
	pencil.focus_mode = Control.FOCUS_NONE
	pencil.draw.connect(_draw_icon)
	pencil.pressed.connect(func() -> void:
		if active:
			end_edit()
		else:
			begin_edit())
	add_child(pencil)
	count_pill = PanelContainer.new()
	count_pill.name = "CountPill"
	count_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.16, 0.26, 0.82)
	box.set_corner_radius_all(14)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	count_pill.add_theme_stylebox_override("panel", box)
	count_label = PanelViews.label("", 18)
	count_label.name = "Count"
	count_label.add_theme_color_override("font_color", Color("#9ff5ec"))
	count_pill.add_child(count_label)
	add_child(count_pill)
	visible = false
	sim.bus.emitted.connect(func(type: StringName, p: Dictionary) -> void:
		if type == &"momo_watch_changed" and int(p.get("id", 0)) == momo:
			_refresh_count())


func show_for(id: int) -> void:
	if momo != id:
		end_edit()
	momo = id
	visible = true
	overlay.show_for(id)
	_refresh_count()
	_place()


func hide_editor() -> void:
	end_edit()
	momo = 0
	visible = false
	overlay.clear()


func begin_edit() -> void:
	if momo == 0 or active:
		return
	active = true
	overlay.editing = true
	pencil.queue_redraw()
	_refresh_count()
	editing_changed.emit(true)


func end_edit() -> void:
	if not active:
		return
	active = false
	_stroking = false
	overlay.editing = false
	overlay.queue_redraw()
	pencil.queue_redraw()
	_refresh_count()
	editing_changed.emit(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		end_edit()
		get_viewport().set_input_as_handled()


# --- strokes -------------------------------------------------------------------------

## A tap while editing: one tile, by the first-tile rule. The sea ends editing.
func on_tap(world: Vector2) -> void:
	var cell := projection.cell_at(world)
	if not (sim.system(&"world") as WorldSystem).is_owned(cell):
		end_edit()
		return
	_begin_stroke(world)
	_stroking = false


func try_begin_drag(_screen: Vector2, world: Vector2) -> bool:
	if not active:
		return false
	_begin_stroke(world)
	return true


func drag_to(_screen: Vector2, world: Vector2) -> void:
	if not _stroking:
		return
	# Every tile the finger crossed since the last sample, not just where it is
	# now: a quick stroke must not skip one.
	var steps := maxi(int(ceil(_last_world.distance_to(world) / (projection.tile_width * 0.2))), 1)
	for i in range(1, steps + 1):
		_touch(projection.cell_at(_last_world.lerp(world, float(i) / steps)))
	_last_world = world


func end_drag(_screen: Vector2, world: Vector2) -> void:
	drag_to(_screen, world)
	_stroking = false


## A second finger: the stroke was a mistake on the way to a pinch -- undone.
func cancel_drag() -> void:
	if not _stroking:
		return
	_stroking = false
	if not _changed.is_empty():
		var back: Array = []
		for c: Vector2i in _changed:
			back.append([c.x, c.y])
		sim.execute({"type": "momo.watch", "momo": momo, "cells": back, "op": "remove" if _op == "add" else "add"})
	_changed.clear()


func _begin_stroke(world: Vector2) -> void:
	var cell := projection.cell_at(world)
	_touched.clear()
	_changed.clear()
	_op = "remove" if momos.is_watching(momo, cell) else "add"
	_stroking = true
	_last_world = world
	_touch(cell)


func _touch(cell: Vector2i) -> void:
	if _touched.has(cell):
		return
	_touched[cell] = true
	last_result = sim.execute({"type": "momo.watch", "momo": momo, "cells": [[cell.x, cell.y]], "op": _op})
	if not last_result["ok"]:
		return
	if not (last_result["changed"] as Array).is_empty():
		_changed.append(cell)
	elif _op == "add" and not (last_result["refused"] as Dictionary).is_empty():
		# The sea is just where the stroke went past; say no only on land.
		if (sim.system(&"world") as WorldSystem).is_owned(cell) or _touched.size() == 1:
			overlay.flash(cell)


# --- look ---------------------------------------------------------------------------------

func _refresh_count() -> void:
	if momo == 0:
		return
	pencil.tooltip_text = tr("watch.done") if active else tr("watch.edit")
	count_label.text = tr("watch.count") % [momos.watched(momo).size(), momos.watch_capacity(momo)]
	count_label.visible = active
	count_pill.visible = active
	count_pill.reset_size()


func _process(_delta: float) -> void:
	if visible:
		_place()


## Just above the selected Momo's card (`anchor`), where it holds still --
## above a walking Momo's head it walked away from the finger (the blind
## playtest missed it again and again, Step 45). Above the head only when
## there is no card. Kept on screen.
func _place() -> void:
	var a := momo_views.actor(momo) if momo_views != null else null
	if a == null:
		return
	var screen := get_viewport_rect().size
	var card: Rect2 = anchor.call() if anchor.is_valid() else Rect2()
	var p := Vector2.ZERO
	if card.size != Vector2.ZERO:
		p = Vector2(card.position.x + 8.0, card.position.y - BUTTON.y - 8.0)
	else:
		var head := cameras.world_to_screen(a.global_position - Vector2(0, a.depth_lift)) - Vector2(0, a.hit_rect().size.y * cameras.camera.zoom.y + 12.0)
		p = Vector2(head.x - BUTTON.x * 0.5, head.y - BUTTON.y)
	p.x = clampf(p.x, 8.0, screen.x - BUTTON.x - 8.0)
	p.y = clampf(p.y, 80.0, screen.y - BUTTON.y - 8.0)
	pencil.position = p
	count_pill.position = Vector2(p.x + BUTTON.x + 6.0, p.y + (BUTTON.y - count_pill.size.y) * 0.5)
	if count_pill.position.x + count_pill.size.x > screen.x - 8.0:
		count_pill.position.x = p.x - count_pill.size.x - 6.0


func _draw_icon() -> void:
	var c := pencil.size * 0.5
	var col := Color(1, 1, 1, 0.95)
	if active:
		pencil.draw_polyline(PackedVector2Array([c + Vector2(-11, 0), c + Vector2(-3, 8), c + Vector2(12, -9)]), Color("#7ff0e6"), 4.0, true)
		return
	# A pencil, tip down-left.
	var d := Vector2(1, -1).normalized()
	var n := Vector2(d.y, -d.x)
	var tip := c + Vector2(-11, 11)
	var a := tip + d * 6.0
	var b := tip + d * 24.0
	pencil.draw_colored_polygon(PackedVector2Array([a + n * 4.5, b + n * 4.5, b - n * 4.5, a - n * 4.5]), Color("#7ff0e6"))
	pencil.draw_colored_polygon(PackedVector2Array([tip, a + n * 4.5, a - n * 4.5]), col)
	pencil.draw_line(b + n * 4.5, b - n * 4.5, col, 2.0, true)
