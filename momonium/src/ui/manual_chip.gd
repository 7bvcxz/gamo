class_name ManualChip
extends Control

## Step 83: the player's hands on the building card -- a little glove and
## "2/3", at the corner of the job the player can do, only while one of their
## hands is busy somewhere (a new island never sees it). With all of them
## busy and this job ready, it turns warm: the job waits for a free hand
## (the card says so when tapped). Drawn, not a sentence; takes no taps.

const SIZE := Vector2(84, 36)
const FACE := Color(0.09, 0.2, 0.38, 0.92)
const FULL := Color("#e2683c")

var used := 0
var limit := 3
var full := false
var _label: Label


func _init() -> void:
	name = "ManualChip"
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_label = Label.new()
	_label.name = "Count"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.position = Vector2(38, 4)
	add_child(_label)


func show_count(p_used: int, p_limit: int, p_full: bool) -> void:
	if used == p_used and limit == p_limit and full == p_full and visible:
		return
	used = p_used
	limit = p_limit
	full = p_full
	_label.text = "%d/%d" % [used, limit]
	visible = true
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var box := StyleBoxFlat.new()
	box.bg_color = FULL if full else FACE
	box.set_corner_radius_all(int(size.y * 0.5))
	box.border_color = Color(1, 1, 1, 0.9)
	box.set_border_width_all(2)
	draw_style_box(box, r)
	HandWorks.draw_glove(self, Vector2(18, size.y * 0.5), 1.2)
