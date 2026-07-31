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
## Multiplies every dimension below. The pad is sized in logical pixels, which on
## a phone are far smaller than physical ones, so the defaults draw a wheel about
## 50 CSS px across -- well under a thumb. The settings slider drives this.
var pad_scale: float = Defs.UI_SCALE_TOUCH_BASE * Defs.UI_SCALE_DEFAULT
## What the screen can actually hold. Layout, drawing and hit-testing all read
## this rather than the requested scale, so they can never disagree.
var _effective: float = Defs.UI_SCALE_TOUCH_BASE * Defs.UI_SCALE_DEFAULT

func set_pad_scale(user_scale: float) -> void:
	pad_scale = Defs.UI_SCALE_TOUCH_BASE * Defs.quantise_ui_scale(user_scale)
	_effective = pad_scale
	# Settings can load before the pad enters the tree, and there is no viewport
	# to measure against until it does. _ready lays out again anyway.
	if is_inside_tree():
		_update_layout()

## A pad larger than the display is not a bigger target, it is a pad with no
## room left for the game, so the request is capped against the actual screen.
func _clamp_to_screen(view: Vector2) -> float:
	var by_width: float = view.x * 0.42 / (JOYSTICK_RADIUS * 2.0)
	var by_height: float = view.y * 0.32 / (JOYSTICK_RADIUS * 2.0)
	var by_stack: float = maxf(view.y * 0.5 - 24.0, 1.0) / 148.0
	return clampf(pad_scale, 0.3, maxf(minf(by_width, minf(by_height, by_stack)), 0.3))

func wheel_radius() -> float:
	return JOYSTICK_RADIUS * _effective

func button_radius() -> float:
	return BUTTON_RADIUS * _effective

## Hit radius, generously larger than the drawn circle.
func button_hit_radius() -> float:
	return button_radius() + 12.0 * _effective

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
	_effective = _clamp_to_screen(view)
	var wheel: float = wheel_radius()
	var radius: float = button_radius()
	# The inset grows with the pad but far more slowly: a margin is about the
	# distance from the screen edge, not about thumb size, and scaling it fully
	# pushed the controls into the middle of the display.
	var edge: float = 20.0 + 12.0 * _effective
	joystick_center = Vector2(view.x - wheel - edge, view.y - wheel - edge)
	joystick_knob = joystick_center
	button_centers.clear()
	# Centres must sit at least two hit radii apart or the generous hit circles
	# overlap and the first match in draw order silently wins the tap.
	var gap: float = button_hit_radius() * 2.0 + 4.0
	var base := Vector2(edge + radius, view.y - edge - radius)
	button_centers.append(base + Vector2(0.0, -gap))              # Run
	button_centers.append(base + Vector2(gap, -gap * 0.30))       # Z
	button_centers.append(base)                                   # X
	queue_redraw()

## How far up the screen the pad reaches, so the HUD can keep its own controls
## out of the way instead of drawing on top of the player's thumbs.
func reserved_height() -> float:
	if not visible:
		return 0.0
	var view: Vector2 = get_viewport_rect().size
	var highest: float = joystick_center.y - wheel_radius()
	for centre: Vector2 in button_centers:
		highest = minf(highest, centre.y - button_hit_radius())
	return maxf(0.0, view.y - highest)

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
		elif main_controller != null:
			main_controller.call("touch_hud_drag", drag.position)
		return
	# A real keyboard or mouse means a desktop player; hide the pad. The guard
	# keeps the browser's synthetic post-tap mouse event from doing this.
	if event is InputEventKey and visible:
		set_controls_visible(false)
	elif event is InputEventMouseButton and visible:
		if Time.get_ticks_msec() - last_touch_msec > SYNTHETIC_MOUSE_GUARD_MSEC:
			set_controls_visible(false)

func _begin_touch(touch_id: int, position: Vector2) -> void:
	# The HUD gets first refusal, ahead of the tap-anywhere shortcut below: the
	# settings gear lives on the title screen too, and if "start" ran first the
	# gear could never be pressed there.
	if main_controller != null and main_controller.call("touch_hud", position):
		return
	# On a menu screen the whole display is the button. Requiring a player to
	# find the small Z pad to get past the title is why the game looked broken
	# on a phone: the prompt said "press any key" and a phone has none.
	if main_controller != null and main_controller.call("touch_anywhere_starts"):
		main_controller.call("touch_primary")
		return
	var hit: float = button_hit_radius()
	for index in button_centers.size():
		if position.distance_to(button_centers[index]) <= hit:
			button_touch[touch_id] = index
			_press_button(index, true)
			return
	if position.x > size.x * 0.45:
		joystick_touch = touch_id
		_update_joystick(position)

func _end_touch(touch_id: int) -> void:
	if main_controller != null:
		main_controller.call("touch_hud_release")
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
	var wheel: float = wheel_radius()
	var offset: Vector2 = position - joystick_center
	if offset.length() > wheel:
		offset = offset.normalized() * wheel
	joystick_knob = joystick_center + offset
	if player == null:
		return
	if offset.length() < 12.0 * _effective:
		player.touch_direction = Vector2.ZERO
	else:
		player.touch_direction = snap_to_eight_directions(offset / wheel)
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

## Called when a modal panel opens, so a held direction cannot survive it and
## walk the player into the cold while they are reading a menu.
func release_all() -> void:
	_reset_inputs()
	queue_redraw()

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
	var wheel: float = wheel_radius()
	var knob: float = KNOB_RADIUS * _effective
	draw_circle(joystick_center, wheel + 4.0 * _effective, Color(0.02, 0.07, 0.08, 0.28))
	draw_circle(joystick_center, wheel, Color(0.035, 0.12, 0.13, 0.62))
	draw_arc(joystick_center, wheel, 0.0, TAU, 48, Color(0.50, 0.72, 0.68, 0.55), 2.0 * _effective)
	for tick in 8:
		var direction := Vector2.from_angle(float(tick) * TAU / 8.0)
		draw_line(joystick_center + direction * wheel * 0.73,
			joystick_center + direction * wheel * 0.84,
			Color(0.73, 0.86, 0.81, 0.42), 2.0 * _effective)
	draw_circle(joystick_knob + Vector2(2, 3) * _effective, knob + _effective, Color(0.03, 0.08, 0.08, 0.38))
	draw_circle(joystick_knob, knob, Color(0.90, 0.65, 0.24, 0.9))
	draw_circle(joystick_knob + Vector2(-6, -7) * _effective, knob * 0.24, Color(1.0, 0.86, 0.48, 0.42))
	for index in button_centers.size():
		_draw_action_button(index)

func _draw_action_button(index: int) -> void:
	var at: Vector2 = button_centers[index]
	var radius: float = button_radius()
	var held: bool = button_touch.values().has(index)
	draw_circle(at + Vector2(2, 3) * _effective, radius + _effective, Color(0.02, 0.07, 0.08, 0.34))
	draw_circle(at, radius, Color(0.06, 0.16, 0.17, 0.88 if held else 0.66))
	draw_arc(at, radius, 0.0, TAU, 32, Color(0.85, 0.65, 0.30, 0.85 if held else 0.55), 2.0 * _effective)
	var label: String = BUTTON_LABELS[index]
	var font: Font = UIFont.FONT
	var glyph: int = int(round(16.0 * _effective))
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph).x
	draw_string(font, at + Vector2(-width * 0.5, 6.0 * _effective), label, HORIZONTAL_ALIGNMENT_LEFT,
		-1, glyph, Color(0.95, 0.98, 0.96, 0.92))
