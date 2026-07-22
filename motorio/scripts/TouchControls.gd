extends Control
class_name TouchControls

const JOYSTICK_RADIUS := 64.0
const KNOB_RADIUS := 25.0
const BUTTON_RADIUS := 28.0
const BUTTON_LABELS := ["달리기", "Z", "X"]
const SYNTHETIC_MOUSE_GUARD_MSEC := 750

var player
var main_controller
var joystick_center := Vector2.ZERO
var joystick_knob := Vector2.ZERO
var joystick_touch_id := -1
var button_centers: Array[Vector2] = []
var button_touches: Dictionary[int, int] = {}
var action_pressed := [false, false, false]
var last_touch_input_msec := -10000
var ui_passthrough_touches: Dictionary[int, bool] = {}
var menu_navigation_axis := 0

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
		if event.pressed and _is_top_tutorial_control(event.position):
			ui_passthrough_touches[event.index] = true
			_activate_top_tutorial_control(event.position)
			get_viewport().set_input_as_handled()
			return
		if ui_passthrough_touches.has(event.index):
			if not event.pressed:
				ui_passthrough_touches.erase(event.index)
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			_begin_touch(event.index, event.position)
		else:
			_end_touch(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if ui_passthrough_touches.has(event.index):
			return
		if event.index == joystick_touch_id:
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()

func _is_top_tutorial_control(position: Vector2) -> bool:
	return position.y <= 64.0 and position.x >= size.x * 0.5 - 170.0 and position.x <= size.x * 0.5 + 170.0

func _activate_top_tutorial_control(position: Vector2) -> void:
	if main_controller == null:
		return
	if position.x < size.x * 0.5:
		main_controller._developer_previous_tutorial()
	else:
		main_controller._developer_advance_tutorial()

func _begin_touch(touch_id: int, position: Vector2) -> void:
	var in_shelter: bool = main_controller != null and main_controller.shelter_open
	if not in_shelter and position.x >= size.x * 0.5 and joystick_touch_id == -1:
		joystick_touch_id = touch_id
		_update_joystick(position)
		return
	for index in button_centers.size():
		if in_shelter and index != 1:
			continue
		if position.distance_to(button_centers[index]) <= BUTTON_RADIUS * 1.25:
			if main_controller != null and main_controller.interaction_locked() and index in [1, 2]:
				return
			button_touches[touch_id] = index
			action_pressed[index] = true
			if main_controller:
				if index == 0 and main_controller.base_menu_open:
					action_pressed[index] = false
					main_controller.close_base_menu_action()
				elif index == 1:
					main_controller.collect_action_held = true
					main_controller.primary_action()
				elif index == 2:
					main_controller.begin_placement_action()
			_sync_player()
			queue_redraw()
			return

func _end_touch(touch_id: int) -> void:
	if touch_id == joystick_touch_id:
		joystick_touch_id = -1
		joystick_knob = joystick_center
		if player:
			player.touch_direction = Vector2.ZERO
		menu_navigation_axis = 0
		queue_redraw()
		return
	if button_touches.has(touch_id):
		var index: int = button_touches[touch_id]
		button_touches.erase(touch_id)
		action_pressed[index] = false
		if main_controller and index == 1:
			main_controller.collect_action_held = false
		elif main_controller and index == 2:
			main_controller.end_placement_action()
		_sync_player()
		queue_redraw()

func _update_joystick(position: Vector2) -> void:
	var offset := position - joystick_center
	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS
	joystick_knob = joystick_center + offset
	if main_controller != null and main_controller.base_menu_open:
		if player:
			player.touch_direction = Vector2.ZERO
		var next_axis := 0
		if offset.y <= -JOYSTICK_RADIUS * 0.32:
			next_axis = -1
		elif offset.y >= JOYSTICK_RADIUS * 0.32:
			next_axis = 1
		if next_axis != 0 and next_axis != menu_navigation_axis:
			main_controller.move_fabricator_selection(next_axis)
		menu_navigation_axis = next_axis
		queue_redraw()
		return
	if player:
		player.touch_direction = snap_to_eight_directions(offset / JOYSTICK_RADIUS)
	queue_redraw()

func snap_to_eight_directions(direction: Vector2) -> Vector2:
	if direction.length() < 0.12:
		return Vector2.ZERO
	var snapped_angle := roundf(direction.angle() / (PI / 4.0)) * (PI / 4.0)
	return Vector2.from_angle(snapped_angle) * clampf(direction.length(), 0.0, 1.0)

func _sync_player() -> void:
	if player:
		player.touch_sprint = action_pressed[0] and (main_controller == null or not main_controller.base_menu_open)

func _reset_inputs() -> void:
	joystick_touch_id = -1
	ui_passthrough_touches.clear()
	menu_navigation_axis = 0
	button_touches.clear()
	action_pressed = [false, false, false]
	joystick_knob = joystick_center
	if player:
		player.touch_direction = Vector2.ZERO
		player.touch_sprint = false
	if main_controller:
		main_controller.collect_action_held = false
		main_controller.cancel_placement_action()
	queue_redraw()

func _draw() -> void:
	if main_controller != null and main_controller.shelter_open:
		_draw_action_button(1)
		return
	# Movement wheel on the lower right.
	draw_circle(joystick_center, JOYSTICK_RADIUS, Color(0.05, 0.07, 0.065, 0.62))
	draw_arc(joystick_center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.82, 0.88, 0.82, 0.55), 3.0)
	draw_circle(joystick_knob, KNOB_RADIUS, Color(0.84, 0.67, 0.25, 0.78))

	# Three action buttons on the lower left.
	for index in button_centers.size():
		_draw_action_button(index)

func _draw_action_button(index: int) -> void:
	var fill := Color(0.84, 0.49, 0.18, 0.88) if action_pressed[index] else Color(0.16, 0.21, 0.19, 0.72)
	draw_circle(button_centers[index], BUTTON_RADIUS, fill)
	draw_arc(button_centers[index], BUTTON_RADIUS, 0.0, TAU, 32, Color(0.9, 0.92, 0.86, 0.65), 2.0)
	var label: String = BUTTON_LABELS[index]
	var font: Font = UIFont.FONT
	var font_size := 11 if index == 0 else 16
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, button_centers[index] - Vector2(text_size.x / 2.0, -text_size.y / 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
