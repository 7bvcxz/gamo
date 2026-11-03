class_name Hud
extends CanvasLayer

## The only numbers on screen: the wind-up energy, beside a coiled spring
## (top centre). And one control without words: the circular arrow (top right)
## starts over -- the first press arms it (it turns red and shakes), a second
## press within three seconds restarts.

signal restart_requested

const ARM_SECONDS := 3.0
const BUTTON_RADIUS := 22.0

var energy: float = 0.0
var armed: float = 0.0
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


## Spends one frame of real time on the HUD's own little motions.
func advance(dt: float) -> void:
	_flash = maxf(0.0, _flash - dt * 4.0)
	armed = maxf(0.0, armed - dt)
	_canvas.queue_redraw()


func restart_center() -> Vector2:
	return Vector2(_canvas.size.x - 40.0, 40.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.position.distance_to(restart_center()) <= BUTTON_RADIUS + 6.0:
			press_restart()
			get_viewport().set_input_as_handled()


func press_restart() -> void:
	if armed > 0.0:
		armed = 0.0
		restart_requested.emit()
	else:
		armed = ARM_SECONDS


func _draw_hud() -> void:
	var c := _canvas
	var font := ThemeDB.fallback_font
	var text := str(int(floorf(energy)))
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
