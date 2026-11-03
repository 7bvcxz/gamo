class_name Hud
extends CanvasLayer

## The only numbers on screen: the wind-up energy, beside a coiled spring
## (top centre). Controls without words: the circular arrow (top right) starts
## over -- the first press arms it (it turns red and shakes), a second press
## within three seconds restarts; the speaker (top left) steps the volume
## full / half / off; the star beside it turns off flashes and shaking.

signal restart_requested
signal volume_pressed
signal motion_pressed

const ARM_SECONDS := 3.0
const BUTTON_RADIUS := 22.0

var energy: float = 0.0
## Step 12: a doll's price leaves the number over its awakening, not in one
## frame (11 of 16 blind players saw "the counter suddenly dropped" and could
## not tell what it paid for). Shown = energy + what is still on its way.
var _pending: float = 0.0
var _pending_rate: float = 0.0
var armed: float = 0.0
var volume_step: int = 0
var reduced_motion: bool = false
## A warm flash over the whole screen (an awakening); 0 when motion is reduced.
var flash: float = 0.0
var _flash: float = 0.0
var _canvas: Control


func _ready() -> void:
	layer = 10
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func set_energy(value: float) -> void:
	if floorf(value) > floorf(energy):
		_flash = 1.0
	energy = value


## The price of a doll that started waking: it drains out of the number over `seconds`.
func spend(amount: float, seconds: float) -> void:
	_pending += amount
	_pending_rate = _pending / maxf(0.1, seconds)


func clear_spend() -> void:
	_pending = 0.0
	_pending_rate = 0.0


## The number on screen.
func shown() -> float:
	return energy + _pending


## Game time: the price drains with the game (and stops when it is paused),
## in step with the light carrying it to the doll.
func step(dt: float) -> void:
	_pending = maxf(0.0, _pending - _pending_rate * dt)


## Spends one frame of real time on the HUD's own little motions.
func advance(dt: float) -> void:
	_flash = maxf(0.0, _flash - dt * 4.0)
	flash = maxf(0.0, flash - dt * 3.0)
	armed = maxf(0.0, armed - dt)
	_canvas.queue_redraw()


func restart_center() -> Vector2:
	return Vector2(_canvas.size.x - 40.0, 40.0)


## Top left, over the wall: the floor along the bottom is where dolls sleep.
func volume_center() -> Vector2:
	return Vector2(40.0, 40.0)


func motion_center() -> Vector2:
	return Vector2(92.0, 40.0)


func flash_now() -> void:
	if not reduced_motion:
		flash = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.position.distance_to(restart_center()) <= BUTTON_RADIUS + 6.0:
			press_restart()
			get_viewport().set_input_as_handled()
		elif mb.position.distance_to(volume_center()) <= BUTTON_RADIUS + 4.0:
			volume_pressed.emit()
			get_viewport().set_input_as_handled()
		elif mb.position.distance_to(motion_center()) <= BUTTON_RADIUS + 4.0:
			motion_pressed.emit()
			get_viewport().set_input_as_handled()


func press_restart() -> void:
	if armed > 0.0:
		armed = 0.0
		restart_requested.emit()
	else:
		armed = ARM_SECONDS


func _draw_hud() -> void:
	var c := _canvas
	if flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1.0, 0.85, 0.55, 0.14 * flash))
	var font := ThemeDB.fallback_font
	var text := str(int(floorf(shown())))
	# While a price is leaving, the number glows warm (a state you can see in a still picture).
	if _pending > 0.5:
		c.draw_rect(Rect2(c.size.x * 0.5 - 70.0, 14.0, 140.0, 56.0), Color(1.0, 0.6, 0.25, 0.28))
	var size := 34
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var centre := Vector2(c.size.x * 0.5, 44.0)
	var left := centre.x - (w + 44.0) * 0.5
	var plate := Rect2(left - 18.0, 14.0, w + 80.0, 56.0)
	c.draw_rect(plate, Color(0.06, 0.05, 0.08, 0.55))
	# The spring: a coil drawn as a spiral.
	var sc := Vector2(left + 14.0, centre.y)
	var pts := PackedVector2Array()
	for i in 60:
		var t := float(i) / 59.0
		var a := t * TAU * 2.6
		pts.append(sc + Vector2.from_angle(a) * (3.0 + t * 12.0))
	c.draw_polyline(pts, Color(0.88, 0.67, 0.3), 3.0, true)
	var glow := Color(1.0, 0.93, 0.75).lerp(Color(1, 1, 1), _flash)
	c.draw_string_outline(font, Vector2(left + 40.0, centre.y + 12.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.1, 0.07, 0.05))
	c.draw_string(font, Vector2(left + 40.0, centre.y + 12.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, glow)
	# Restart: a circular arrow; red and shaking while armed.
	var rc := restart_center()
	if armed > 0.0:
		rc.x += sin(armed * 40.0) * 2.0
	var col := Color(0.95, 0.35, 0.3) if armed > 0.0 else Color(1, 1, 1, 0.45)
	c.draw_circle(rc, BUTTON_RADIUS, Color(0.06, 0.05, 0.08, 0.5))
	c.draw_arc(rc, 11.0, 0.5, TAU - 0.4, 24, col, 3.0, true)
	var tip := rc + Vector2.from_angle(0.5) * 11.0
	c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -3), tip + Vector2(5, -6), tip + Vector2(2, 5)]), col)
	_draw_volume(volume_center())
	_draw_motion(motion_center())


## A speaker with as many waves as the volume step allows; crossed out at off.
func _draw_volume(at: Vector2) -> void:
	var c := _canvas
	var col := Color(1, 1, 1, 0.5)
	c.draw_circle(at, BUTTON_RADIUS, Color(0.06, 0.05, 0.08, 0.5))
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-10, -4), at + Vector2(-5, -4), at + Vector2(1, -10),
		at + Vector2(1, 10), at + Vector2(-5, 4), at + Vector2(-10, 4)]), col)
	var waves: int = [2, 1, 0][clampi(volume_step, 0, 2)]
	for w in waves:
		c.draw_arc(at + Vector2(2, 0), 6.0 + w * 5.0, -0.8, 0.8, 8, col, 2.0, true)
	if waves == 0:
		c.draw_line(at + Vector2(5, -6), at + Vector2(13, 6), Color(0.95, 0.4, 0.35, 0.8), 2.5, true)


## A small burst (motion on), crossed out when motion is reduced.
func _draw_motion(at: Vector2) -> void:
	var c := _canvas
	var col := Color(1, 1, 1, 0.5)
	c.draw_circle(at, BUTTON_RADIUS, Color(0.06, 0.05, 0.08, 0.5))
	for i in 8:
		var a := TAU * i / 8.0
		c.draw_line(at + Vector2.from_angle(a) * 4.0, at + Vector2.from_angle(a) * (10.0 if i % 2 == 0 else 7.0), col, 2.0, true)
	if reduced_motion:
		c.draw_line(at + Vector2(-11, 11), at + Vector2(11, -11), Color(0.95, 0.4, 0.35, 0.85), 2.5, true)
