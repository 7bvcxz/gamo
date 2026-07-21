extends Control
class_name TouchControls

const JOYSTICK_RADIUS := 64.0
const KNOB_RADIUS := 25.0
const BUTTON_RADIUS := 28.0
const BUTTON_LABELS := ["RUN", "Z", "X", "MODE"]
const SYNTHETIC_MOUSE_GUARD_MSEC := 750

var player
var main_controller
var joystick_center := Vector2.ZERO
var joystick_knob := Vector2.ZERO
var joystick_touch_id := -1
var button_centers: Array[Vector2] = []
var button_touches: Dictionary[int, int] = {}
var action_pressed := [false, false, false, false]
var last_touch_input_msec := -10000

func _ready() -> void:
	resized.connect(_update_layout)
	_update_layout()
	visible = _is_touch_device()
	set_process_input(true)

func _is_touch_device() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("'ontouchstart' in window || navigator.maxTouchPoints > 0"))
	return DisplayServer.is_touchscreen_available()

func set_controls_visible(value: bool) -> void:
	visible = value
	if not value:
		_reset_inputs()

func get_button_count() -> int:
	return button_centers.size()

func _update_layout() -> void:
	joystick_center = Vector2(size.x - 90.0, size.y - 92.0)
	if joystick_touch_id == -1:
		joystick_knob = joystick_center
	button_centers = [
		Vector2(68.0, size.y - 76.0),
		Vector2(132.0, size.y - 116.0),
		Vector2(154.0, size.y - 52.0),
		Vector2(74.0, size.y - 148.0),
	]
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if visible:
			set_controls_visible(false)
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if Time.get_ticks_msec() - last_touch_input_msec < SYNTHETIC_MOUSE_GUARD_MSEC:
			return
		if visible:
			set_controls_visible(false)
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		last_touch_input_msec = Time.get_ticks_msec()
		if not visible:
			set_controls_visible(true)
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(event.index, event.position)
		else:
			_end_touch(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == joystick_touch_id:
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()

func _begin_touch(touch_id: int, position: Vector2) -> void:
	if position.x >= size.x * 0.5 and joystick_touch_id == -1:
		joystick_touch_id = touch_id
		_update_joystick(position)
		return
	for index in button_centers.size():
		if position.distance_to(button_centers[index]) <= BUTTON_RADIUS * 1.25:
			button_touches[touch_id] = index
			action_pressed[index] = true
			if main_controller:
				if index == 1:
					main_controller.collect_action_held = true
					main_controller.primary_action()
				elif index == 2:
					main_controller.preview_action()
				elif index == 3:
					main_controller.toggle_interaction_mode()
			_sync_player()
			queue_redraw()
			return

func _end_touch(touch_id: int) -> void:
	if touch_id == joystick_touch_id:
		joystick_touch_id = -1
		joystick_knob = joystick_center
		if player:
			player.touch_direction = Vector2.ZERO
		queue_redraw()
		return
	if button_touches.has(touch_id):
		var index: int = button_touches[touch_id]
		button_touches.erase(touch_id)
		action_pressed[index] = false
		if main_controller and index == 1:
			main_controller.collect_action_held = false
		_sync_player()
		queue_redraw()

func _update_joystick(position: Vector2) -> void:
	var offset := position - joystick_center
	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS
	joystick_knob = joystick_center + offset
	if player:
		player.touch_direction = offset / JOYSTICK_RADIUS
	queue_redraw()

func _sync_player() -> void:
	if player:
		player.touch_sprint = action_pressed[0]

func _reset_inputs() -> void:
	joystick_touch_id = -1
	button_touches.clear()
	action_pressed = [false, false, false, false]
	joystick_knob = joystick_center
	if player:
		player.touch_direction = Vector2.ZERO
		player.touch_sprint = false
	if main_controller:
		main_controller.collect_action_held = false
	queue_redraw()

func _draw() -> void:
	# Movement wheel on the lower right.
	draw_circle(joystick_center, JOYSTICK_RADIUS, Color(0.05, 0.07, 0.065, 0.62))
	draw_arc(joystick_center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.82, 0.88, 0.82, 0.55), 3.0)
	draw_circle(joystick_knob, KNOB_RADIUS, Color(0.84, 0.67, 0.25, 0.78))

	# Three action buttons on the lower left.
	for index in button_centers.size():
		var fill := Color(0.84, 0.49, 0.18, 0.88) if action_pressed[index] else Color(0.16, 0.21, 0.19, 0.72)
		draw_circle(button_centers[index], BUTTON_RADIUS, fill)
		draw_arc(button_centers[index], BUTTON_RADIUS, 0.0, TAU, 32, Color(0.9, 0.92, 0.86, 0.65), 2.0)
		var label: String = BUTTON_LABELS[index]
		var font: Font = ThemeDB.fallback_font
		var font_size := 11 if index == 0 else 16
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, button_centers[index] - Vector2(text_size.x / 2.0, -text_size.y / 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
