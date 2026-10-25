class_name InputRouter
extends Node

## One place where pointer input becomes intent: taps, drags, pinches.
##
## Priority, highest first:
##   1. UI -- Godot's GUI sees every event before `_unhandled_input`, so a
##      press on a button never reaches here.
##   2. Drag handlers (Momo, later tools) -- asked in registration order
##      whether they want a drag that starts at this point.
##   3. The camera -- anything unclaimed pans; two fingers pinch-zoom.
## A press that ends without moving past TAP_SLOP is a tap, delivered to tap
## handlers (Step 11). A second finger cancels whatever the first was doing.
##
## Touch and mouse are one model. Mouse events that the engine synthesises
## from touches (device == DEVICE_ID_EMULATION) are ignored so one tap is one
## action, and so are real mouse events arriving right after a touch (mobile
## browsers send compatibility clicks).

signal tapped(screen: Vector2, world: Vector2)

const TAP_SLOP := 10.0
const WHEEL_STEP := 1.12
const MOUSE_AFTER_TOUCH_MS := 600

enum Mode { IDLE, PRESSED, PANNING, DRAGGING, PINCHING }

var cameras: CameraController
var mode: Mode = Mode.IDLE
## Active pointers: id -> current position. Mouse uses id -1.
var _points: Dictionary = {}
var _press_pos := Vector2.ZERO
var _press_id := 0
var _last_touch_ms := -100000
var _pinch_distance := 0.0
var _pinch_mid := Vector2.ZERO
var _drag_handlers: Array[Object] = []
var _drag_owner: Object = null


func setup(p_cameras: CameraController) -> void:
	cameras = p_cameras


## A drag handler implements:
##   try_begin_drag(screen: Vector2, world: Vector2) -> bool
##   drag_to(screen: Vector2, world: Vector2) -> void
##   end_drag(screen: Vector2, world: Vector2) -> void
##   cancel_drag() -> void
func add_drag_handler(handler: Object) -> void:
	_drag_handlers.append(handler)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_last_touch_ms = Time.get_ticks_msec()
		var t := event as InputEventScreenTouch
		if t.pressed:
			_press(t.index, t.position)
		else:
			_release(t.index, t.position, t.canceled)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_last_touch_ms = Time.get_ticks_msec()
		var d := event as InputEventScreenDrag
		_move(d.index, d.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		cameras.zoom_at((event as InputEventMagnifyGesture).factor, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		cameras.pan_screen(-(event as InputEventPanGesture).delta * 8.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouse:
		if event.device == InputEvent.DEVICE_ID_EMULATION or Time.get_ticks_msec() - _last_touch_ms < MOUSE_AFTER_TOUCH_MS:
			return
		_mouse(event as InputEventMouse)


func _mouse(event: InputEventMouse) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		match b.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if b.pressed:
					cameras.zoom_at(WHEEL_STEP, b.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if b.pressed:
					cameras.zoom_at(1.0 / WHEEL_STEP, b.position)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if b.pressed:
					_press(-1, b.position, b.button_index != MOUSE_BUTTON_LEFT)
				else:
					_release(-1, b.position, false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _points.has(-1):
		_move(-1, event.position)
		get_viewport().set_input_as_handled()


func _press(id: int, pos: Vector2, pan_only: bool = false) -> void:
	_points[id] = pos
	if _points.size() == 2:
		_begin_pinch()
		return
	if _points.size() > 2:
		return
	_press_id = id
	_press_pos = pos
	mode = Mode.PANNING if pan_only else Mode.PRESSED


func _move(id: int, pos: Vector2) -> void:
	if not _points.has(id):
		return
	var previous: Vector2 = _points[id]
	_points[id] = pos
	match mode:
		Mode.PRESSED:
			if pos.distance_to(_press_pos) > TAP_SLOP:
				_begin_drag(pos)
				if mode == Mode.PANNING:
					cameras.pan_screen(pos - _press_pos)
		Mode.PANNING:
			cameras.pan_screen(pos - previous)
		Mode.DRAGGING:
			_drag_owner.call("drag_to", pos, cameras.screen_to_world(pos))
		Mode.PINCHING:
			_update_pinch()


func _release(id: int, pos: Vector2, canceled: bool) -> void:
	if not _points.has(id):
		return
	_points.erase(id)
	match mode:
		Mode.PRESSED:
			if not canceled and id == _press_id:
				tapped.emit(pos, cameras.screen_to_world(pos))
			mode = Mode.IDLE
		Mode.DRAGGING:
			if id == _press_id:
				if canceled:
					_drag_owner.call("cancel_drag")
				else:
					_drag_owner.call("end_drag", pos, cameras.screen_to_world(pos))
				_drag_owner = null
				mode = Mode.IDLE
		Mode.PINCHING:
			if _points.size() < 2:
				# The remaining finger does not resume a pan by surprise.
				mode = Mode.IDLE if _points.is_empty() else Mode.PINCHING
		_:
			if _points.is_empty():
				mode = Mode.IDLE
	if _points.is_empty():
		mode = Mode.IDLE


func _begin_drag(pos: Vector2) -> void:
	var world_pos := cameras.screen_to_world(_press_pos)
	for handler: Object in _drag_handlers:
		if handler.call("try_begin_drag", _press_pos, world_pos):
			_drag_owner = handler
			mode = Mode.DRAGGING
			handler.call("drag_to", pos, cameras.screen_to_world(pos))
			return
	mode = Mode.PANNING


func _begin_pinch() -> void:
	if mode == Mode.DRAGGING and _drag_owner != null:
		_drag_owner.call("cancel_drag")
		_drag_owner = null
	mode = Mode.PINCHING
	var pts: Array = _points.values()
	_pinch_distance = (pts[0] as Vector2).distance_to(pts[1])
	_pinch_mid = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5


func _update_pinch() -> void:
	var pts: Array = _points.values()
	if pts.size() < 2:
		return
	var distance := (pts[0] as Vector2).distance_to(pts[1])
	var mid := ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	if _pinch_distance > 1.0:
		cameras.zoom_at(distance / _pinch_distance, mid)
	cameras.pan_screen(mid - _pinch_mid)
	_pinch_distance = distance
	_pinch_mid = mid
