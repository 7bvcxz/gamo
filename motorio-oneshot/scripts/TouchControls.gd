extends Control
class_name TouchControls

## Mobile controls carried over from Motorio: a movement wheel on the right and
## three action buttons on the left. Two hard-won details come with it — the
## joystick snaps to eight directions so a thumb can hold a straight line, and
## touch-generated mouse events are ignored for a moment, because the browser
## synthesises a mouse event right after every tap and that used to reset the
## stick the instant you started dragging.

const JOYSTICK_RADIUS := 64.0
const KNOB_RADIUS := 25.0
const BUTTON_RADIUS := 28.0
const BUTTON_LABELS := ["Run", "Z", "X"]
const SYNTHETIC_MOUSE_GUARD_MSEC := 750

var main_controller
var player: PlayerActor

var joystick_center := Vector2.ZERO
var joystick_knob := Vector2.ZERO
var button_centers: Array[Vector2] = []
var joystick_touch := -1
var button_touch: Dictionary = {}
var last_touch_msec := -100000

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = _is_touch_device()
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)

func _is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func set_controls_visible(value: bool) -> void:
	visible = value
	if not value:
		_reset_inputs()

func _update_layout() -> void:
	var view: Vector2 = get_viewport_rect().size
	size = view
	joystick_center = Vector2(view.x - JOYSTICK_RADIUS - 42.0, view.y - JOYSTICK_RADIUS - 42.0)
	joystick_knob = joystick_center
	button_centers.clear()
	var base := Vector2(46.0 + BUTTON_RADIUS, view.y - 48.0 - BUTTON_RADIUS)
	button_centers.append(base + Vector2(0.0, -78.0))          # Run
	button_centers.append(base + Vector2(84.0, -14.0))         # Z
	button_centers.append(base + Vector2(6.0, 0.0))            # X
	queue_redraw()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		last_touch_msec = Time.get_ticks_msec()
		if not visible:
			set_controls_visible(true)
		if touch.pressed:
			_begin_touch(touch.index, touch.position)
		else:
			_end_touch(touch.index)
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		last_touch_msec = Time.get_ticks_msec()
		if drag.index == joystick_touch:
			_update_joystick(drag.position)
		return
	# A real keyboard or mouse means a desktop player; hide the pad. The guard
	# keeps the browser's synthetic post-tap mouse event from doing this.
	if event is InputEventKey and visible:
		set_controls_visible(false)
	elif event is InputEventMouseButton and visible:
		if Time.get_ticks_msec() - last_touch_msec > SYNTHETIC_MOUSE_GUARD_MSEC:
			set_controls_visible(false)

func _begin_touch(touch_id: int, position: Vector2) -> void:
	for index in button_centers.size():
		if position.distance_to(button_centers[index]) <= BUTTON_RADIUS + 12.0:
			button_touch[touch_id] = index
			_press_button(index, true)
			return
	if position.x > size.x * 0.45:
		joystick_touch = touch_id
		_update_joystick(position)

func _end_touch(touch_id: int) -> void:
	if button_touch.has(touch_id):
		_press_button(int(button_touch[touch_id]), false)
		button_touch.erase(touch_id)
		return
	if touch_id == joystick_touch:
		joystick_touch = -1
		joystick_knob = joystick_center
		if player != null:
			player.touch_direction = Vector2.ZERO
		queue_redraw()

func _update_joystick(position: Vector2) -> void:
	var offset: Vector2 = position - joystick_center
	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS
	joystick_knob = joystick_center + offset
	if player == null:
		return
	if offset.length() < 12.0:
		player.touch_direction = Vector2.ZERO
	else:
		player.touch_direction = snap_to_eight_directions(offset / JOYSTICK_RADIUS)
	queue_redraw()

## Eight-way snapping: a thumb cannot hold an exact angle, and a belt line built
## along a drifting diagonal is the most annoying way to waste heat.
func snap_to_eight_directions(direction: Vector2) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.ZERO
	var step: float = TAU / 8.0
	var angle: float = round(direction.angle() / step) * step
	return Vector2.from_angle(angle)

func _press_button(index: int, pressed: bool) -> void:
	if player != null and index == 0:
		player.touch_sprint = pressed
	if main_controller == null or not pressed:
		return
	match index:
		1: main_controller.call("touch_primary")
		2: main_controller.call("touch_secondary")

func _reset_inputs() -> void:
	joystick_touch = -1
	joystick_knob = joystick_center
	button_touch.clear()
	if player != null:
		player.touch_direction = Vector2.ZERO
		player.touch_sprint = false

func _draw() -> void:
	if not visible:
		return
	draw_circle(joystick_center, JOYSTICK_RADIUS + 4.0, Color(0.02, 0.07, 0.08, 0.28))
	draw_circle(joystick_center, JOYSTICK_RADIUS, Color(0.035, 0.12, 0.13, 0.62))
	draw_arc(joystick_center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.50, 0.72, 0.68, 0.55), 2.0)
	for tick in 8:
		var direction := Vector2.from_angle(float(tick) * TAU / 8.0)
		draw_line(joystick_center + direction * 47.0, joystick_center + direction * 54.0,
			Color(0.73, 0.86, 0.81, 0.42), 2.0)
	draw_circle(joystick_knob + Vector2(2, 3), KNOB_RADIUS + 1.0, Color(0.03, 0.08, 0.08, 0.38))
	draw_circle(joystick_knob, KNOB_RADIUS, Color(0.90, 0.65, 0.24, 0.9))
	draw_circle(joystick_knob + Vector2(-6, -7), 6.0, Color(1.0, 0.86, 0.48, 0.42))
	for index in button_centers.size():
		_draw_action_button(index)

func _draw_action_button(index: int) -> void:
	var at: Vector2 = button_centers[index]
	var held: bool = button_touch.values().has(index)
	draw_circle(at + Vector2(2, 3), BUTTON_RADIUS + 1.0, Color(0.02, 0.07, 0.08, 0.34))
	draw_circle(at, BUTTON_RADIUS, Color(0.06, 0.16, 0.17, 0.88 if held else 0.66))
	draw_arc(at, BUTTON_RADIUS, 0.0, TAU, 32, Color(0.85, 0.65, 0.30, 0.85 if held else 0.55), 2.0)
	var label: String = BUTTON_LABELS[index]
	var font: Font = UIFont.FONT
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, at + Vector2(-width * 0.5, 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(0.95, 0.98, 0.96, 0.92))
