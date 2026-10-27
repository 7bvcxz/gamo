class_name WatchEditor
extends Control

## A Momo's schedule, planned by hand (Step 60).
##
## A selected Momo shows its tiles (WatchOverlay) and one small Schedule
## button just under its feet -- nothing else: the Momo card with Assign,
## Release and the pencil is gone. Schedule turns Schedule mode on: the tiles
## the Momo works are filled, the island's other tiles it could take are
## outlined, and a count beside the button says how many of how many. Then a
## tap on a tile adds it or takes it away, and a stroke across tiles does to
## every tile it crosses what was done to the first one (first tile watched:
## the stroke removes; otherwise it adds) -- never flipping a tile back within
## one stroke. In Schedule mode one finger paints instead of panning or
## carrying a Momo; two fingers still pan and zoom (and a stroke they
## interrupt is undone); the right mouse button pans. Schedule again, a tap on
## the sea or on another Momo, or Esc ends it. Tiles that cannot be taken
## (sea, a building with no Momo work, too many) flash red with a cross. The
## tiles are the Momo's real work: it heads for the nearest ready building
## among them at once (JobSystem), and they are saved with the island.
##
## An InputRouter drag handler, registered before the Momo drag, so in
## Schedule mode the stroke wins over picking a Momo up.

signal editing_changed(on: bool)

const BUTTON := Vector2(50, 50)
## Screen units between the Momo's feet (or head) and the button.
const GAP := 6.0
## How much clear room under the feet brings the button back there.
const RETURN_ROOM := 24.0

var sim: Simulation
var momos: MomoSystem
var cameras: CameraController
var projection: IsoProjection
var momo_views: MomoViews
var overlay: WatchOverlay
var momo := 0
var active := false
## The Schedule button: a small planner, filled with a check while on.
var schedule: Button
## HUD rectangles the button must not sit on (Array[Rect2], screen units).
var avoid: Callable
## The screen less the device's cut-outs (Rect2), as the HUD keeps it.
var safe_area: Callable
## Where it stands relative to the Momo: "below" its feet, else "above" its
## head, else beside it -- kept while it still fits, so it does not flap.
var side := "below"
var count_label: Label
var count_pill: PanelContainer
var last_result: Dictionary = {}
var _op := ""
var _touched: Dictionary = {}
var _changed: Array[Vector2i] = []
## The schedule as it was when the stroke began, in order (an undone stroke
## puts it back exactly, Step 61).
var _before: Array = []
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
	schedule = Button.new()
	schedule.name = "Schedule"
	schedule.custom_minimum_size = BUTTON
	schedule.size = BUTTON
	schedule.focus_mode = Control.FOCUS_NONE
	# A toggle, so a screen reader hears whether Schedule mode is on.
	schedule.toggle_mode = true
	schedule.draw.connect(_draw_icon)
	schedule.toggled.connect(func(on: bool) -> void:
		if on:
			begin_edit()
		else:
			end_edit())
	add_child(schedule)
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
		side = "below"
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
	schedule.set_pressed_no_signal(true)
	schedule.queue_redraw()
	_refresh_count()
	editing_changed.emit(true)


func end_edit() -> void:
	if not active:
		return
	active = false
	_stroking = false
	overlay.editing = false
	overlay.queue_redraw()
	schedule.set_pressed_no_signal(false)
	schedule.queue_redraw()
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
		sim.execute({"type": "momo.watch", "momo": momo, "cells": _before, "op": "set", "schedule": true})
	_changed.clear()


func _begin_stroke(world: Vector2) -> void:
	var cell := projection.cell_at(world)
	_touched.clear()
	_changed.clear()
	_before = momos.watched(momo).map(func(c: Vector2i) -> Array: return [c.x, c.y])
	_op = "remove" if momos.is_watching(momo, cell) else "add"
	_stroking = true
	_last_world = world
	_touch(cell)


func _touch(cell: Vector2i) -> void:
	if _touched.has(cell):
		return
	_touched[cell] = true
	# Schedule mode: in the order tapped (Step 61).
	last_result = sim.execute({"type": "momo.watch", "momo": momo, "cells": [[cell.x, cell.y]], "op": _op, "schedule": true})
	if not last_result["ok"]:
		return
	if not (last_result["changed"] as Array).is_empty():
		_changed.append(cell)
		overlay.pulse(cell, _op == "add")
	elif _op == "add" and not (last_result["refused"] as Dictionary).is_empty():
		# The sea is just where the stroke went past; say no only on land.
		if (sim.system(&"world") as WorldSystem).is_owned(cell) or _touched.size() == 1:
			overlay.flash(cell)


# --- look ---------------------------------------------------------------------------------

func _refresh_count() -> void:
	if momo == 0:
		return
	schedule.tooltip_text = tr("watch.done") if active else tr("watch.schedule_hint")
	schedule.accessibility_name = tr("watch.schedule")
	var n := momos.watched(momo).size()
	var cap := momos.watch_capacity(momo)
	count_label.text = tr("watch.count") % [n, cap]
	# Full: the count turns amber (more tiles would be refused).
	count_label.add_theme_color_override("font_color", Color("#ffd27a") if n >= cap else Color("#9ff5ec"))
	count_label.visible = active
	count_pill.visible = active
	count_pill.reset_size()


func _process(_delta: float) -> void:
	if visible:
		_place()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and schedule != null:
		_refresh_count()


## Just under the selected Momo's feet, following it as it walks and as the
## view moves -- whole pixels, read from where it stands (`ground`), not from
## the bobbing sprite, so it never jitters. Where that does not fit (the
## screen's edge, a HUD button) it goes above the head, then beside the Momo,
## always on screen and never over the Momo itself.
func _place() -> void:
	var p := target()
	if p == Vector2.INF:
		return
	schedule.position = p
	var screen := get_viewport_rect().size
	count_pill.position = Vector2(p.x + BUTTON.x + 6.0, p.y + (BUTTON.y - count_pill.size.y) * 0.5).round()
	if count_pill.position.x + count_pill.size.x > screen.x - 8.0:
		count_pill.position.x = p.x - count_pill.size.x - 6.0


## Where the button goes now (top-left, screen units), or INF with no Momo.
func target() -> Vector2:
	var a := momo_views.actor(momo) if momo_views != null else null
	if a == null:
		return Vector2.INF
	var feet := cameras.world_to_screen(a.global_position - Vector2(0, a.depth_lift))
	var hud: Array[Rect2] = []
	if avoid.is_valid():
		hud = avoid.call()
	var got := spot(feet, cameras.camera.zoom.y, safe_rect(), hud, side)
	side = got[1]
	return got[0]


## The button's place for a Momo whose feet are at `feet` on screen, drawn
## at `zoom`: under the feet, else above the head, else to its right or
## left -- the first that is inside `safe` and on no `hud` rectangle. Away
## from under the feet (`prefer`, where it was), it stays where it is until
## there is clear room under the feet again (RETURN_ROOM more on every side),
## so a Momo walking along an edge does not make it flap. None fits: under
## the feet, pulled inside the screen. Returns [top-left, side].
static func spot(feet: Vector2, zoom: float, safe: Rect2, hud: Array[Rect2], prefer: String) -> Array:
	var body := Rect2(feet + Vector2(-26.0, -76.0) * zoom, Vector2(52.0, 80.0) * zoom)
	var spots := {
		"below": Vector2(feet.x - BUTTON.x * 0.5, body.end.y + GAP),
		"above": Vector2(feet.x - BUTTON.x * 0.5, body.position.y - GAP - BUTTON.y),
		"right": Vector2(body.end.x + GAP, body.get_center().y - BUTTON.y * 0.5),
		"left": Vector2(body.position.x - GAP - BUTTON.x, body.get_center().y - BUTTON.y * 0.5),
	}
	var order: Array[String] = ["below", "above", "right", "left"]
	if prefer != "below" and spots.has(prefer) and not _fits(Rect2(spots["below"], BUTTON).grow(RETURN_ROOM), safe, hud):
		order.erase(prefer)
		order.push_front(prefer)
	var chosen := "below"
	for s: String in order:
		if _fits(Rect2(spots[s], BUTTON), safe, hud):
			chosen = s
			break
	var p: Vector2 = spots[chosen]
	p.x = clampf(p.x, safe.position.x, safe.end.x - BUTTON.x)
	p.y = clampf(p.y, safe.position.y, safe.end.y - BUTTON.y)
	return [p.round(), chosen]


## The screen less its edges (the device's safe area, as the HUD keeps it).
func safe_rect() -> Rect2:
	if safe_area.is_valid():
		return safe_area.call()
	var screen := get_viewport_rect().size
	return Rect2(Vector2(8, 8), screen - Vector2(16, 16))


static func _fits(r: Rect2, safe: Rect2, hud: Array[Rect2]) -> bool:
	if not safe.encloses(r):
		return false
	for h: Rect2 in hud:
		if h.intersects(r):
			return false
	return true


## A planner: a small board with two rings on top and three lines, each with
## its box. In Schedule mode it is filled, the boxes ticked.
func _draw_icon() -> void:
	var c := schedule.size * 0.5
	var ink := Color(1, 1, 1, 0.95)
	var teal := Color("#7ff0e6")
	var board := Rect2(c + Vector2(-12, -11), Vector2(24, 25))
	if active:
		schedule.draw_circle(c, 23.0, Color(teal, 0.28))
		schedule.draw_rect(board, teal, true)
		ink = Color("#0b2f4a")
	schedule.draw_rect(board, Color(1, 1, 1, 0.95) if not active else teal.lightened(0.4), false, 2.5)
	for x: float in [-6.0, 6.0]:
		schedule.draw_line(c + Vector2(x, -15), c + Vector2(x, -8), Color(1, 1, 1, 0.95), 3.0, true)
	for i in 3:
		var y := -3.0 + i * 6.0
		var box := Rect2(c + Vector2(-8, y - 2), Vector2(4, 4))
		if active:
			schedule.draw_rect(box, ink, false, 1.5)
			schedule.draw_polyline(PackedVector2Array([box.position + Vector2(0.5, 2), box.position + Vector2(2, 3.5), box.position + Vector2(5, -0.5)]), ink, 1.8, true)
		else:
			schedule.draw_rect(box, ink, true)
		schedule.draw_line(c + Vector2(-1, y), c + Vector2(8, y), ink, 2.0, true)
