class_name CameraPad
extends Control

## For anyone who would rather not drag or pinch: four arrows that move the
## view and two buttons that zoom, small, bottom right, shown only when chosen
## in Settings.

const STEP := 140.0
const ZOOM := 1.18

var cameras: CameraController
var buttons: Dictionary = {}


func setup(p_cameras: CameraController) -> void:
	cameras = p_cameras
	name = "CameraPad"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec: Array in [["up", Vector2(1, 0)], ["left", Vector2(0, 1)], ["right", Vector2(2, 1)], ["down", Vector2(1, 2)], ["in", Vector2(3, 0)], ["out", Vector2(3, 2)]]:
		var b := Button.new()
		b.name = String(spec[0])
		b.custom_minimum_size = Vector2(48, 48)
		b.size = Vector2(48, 48)
		b.position = (spec[1] as Vector2) * 52.0
		b.focus_mode = Control.FOCUS_NONE
		var what := String(spec[0])
		b.draw.connect(func() -> void: _draw_icon(b, what))
		b.pressed.connect(func() -> void: act(what))
		add_child(b)
		buttons[what] = b
	size = Vector2(4 * 52, 3 * 52)
	visible = false


## One step of the view: pan by a fixed amount, or zoom about the centre.
func act(what: String) -> void:
	var centre := get_viewport_rect().size * 0.5
	match what:
		"up":
			cameras.pan_screen(Vector2(0, STEP))
		"down":
			cameras.pan_screen(Vector2(0, -STEP))
		"left":
			cameras.pan_screen(Vector2(STEP, 0))
		"right":
			cameras.pan_screen(Vector2(-STEP, 0))
		"in":
			cameras.zoom_at(ZOOM, centre)
		"out":
			cameras.zoom_at(1.0 / ZOOM, centre)


func _draw_icon(b: Button, what: String) -> void:
	var c := b.size * 0.5
	var col := Color(1, 1, 1, 0.92)
	match what:
		"up":
			b.draw_polyline(PackedVector2Array([c + Vector2(-9, 5), c + Vector2(0, -6), c + Vector2(9, 5)]), col, 3.0, true)
		"down":
			b.draw_polyline(PackedVector2Array([c + Vector2(-9, -5), c + Vector2(0, 6), c + Vector2(9, -5)]), col, 3.0, true)
		"left":
			b.draw_polyline(PackedVector2Array([c + Vector2(5, -9), c + Vector2(-6, 0), c + Vector2(5, 9)]), col, 3.0, true)
		"right":
			b.draw_polyline(PackedVector2Array([c + Vector2(-5, -9), c + Vector2(6, 0), c + Vector2(-5, 9)]), col, 3.0, true)
		"in":
			b.draw_line(c + Vector2(-9, 0), c + Vector2(9, 0), col, 3.0, true)
			b.draw_line(c + Vector2(0, -9), c + Vector2(0, 9), col, 3.0, true)
		"out":
			b.draw_line(c + Vector2(-9, 0), c + Vector2(9, 0), col, 3.0, true)
