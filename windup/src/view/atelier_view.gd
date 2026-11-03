class_name AtelierView
extends Node2D

## The placeholder atelier (Step 02): a dark, moonlit workshop drawn from
## shapes, the big brass key in the middle and one sleeping doll. No art yet --
## Step 03 makes it -- and no economy yet -- Step 04 does.
##
## The key is the one control. Pressing it (mouse, touch, Space) turns it a
## quarter turn and says so through `wind_pressed`; nothing on screen explains
## it in words.

signal wind_pressed(source: String)

const DESIGN := Vector2(1280, 720)
const KEY_CENTER := Vector2(640, 380)
const KEY_HIT_RADIUS := 120.0
const QUARTER := PI / 2.0

const C_WALL := Color(0.105, 0.098, 0.135)
const C_WALL_LOW := Color(0.075, 0.07, 0.095)
const C_FLOOR := Color(0.13, 0.095, 0.08)
const C_MOON := Color(0.78, 0.84, 0.95)
const C_BRASS := Color(0.85, 0.64, 0.25)
const C_BRASS_DARK := Color(0.55, 0.38, 0.14)
const C_SPIRIT := Color(1.0, 0.92, 0.66)
const C_DOLL := Color(0.24, 0.2, 0.22)

var key_angle: float = 0.0
var _target_angle: float = 0.0
var _anim: float = 0.0
var version_text: String = ""


func reset() -> void:
	key_angle = 0.0
	_target_angle = 0.0
	queue_redraw()


## One quarter turn of the key (the visual half of a wind; the caller counts it).
func turn() -> void:
	_target_angle += QUARTER


func _process(delta: float) -> void:
	_anim += delta
	key_angle = lerpf(key_angle, _target_angle, 1.0 - exp(-delta * 18.0))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and key_hit(to_local(mb.position)):
			wind_pressed.emit("click")
			get_viewport().set_input_as_handled()


## Whether a point (in this node's space) is on the key.
func key_hit(point: Vector2) -> bool:
	return point.distance_to(key_center()) <= KEY_HIT_RADIUS


## The key's centre in this node's space.
func key_center() -> Vector2:
	return _layout_offset() + KEY_CENTER


## The design rectangle is centred in whatever the window shows (stretch
## aspect "expand" can make the visible area wider or taller than 1280x720).
func _layout_offset() -> Vector2:
	var size := get_viewport_rect().size
	return ((size - DESIGN) * 0.5).floor()


func _draw() -> void:
	var size := get_viewport_rect().size
	var o := _layout_offset()
	# Wall and floor, filling the whole visible area.
	draw_rect(Rect2(Vector2.ZERO, size), C_WALL)
	var floor_y := o.y + 520.0
	draw_rect(Rect2(0, floor_y - 120.0, size.x, 120.0), C_WALL_LOW)
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), C_FLOOR)
	# The window and its moonlight on the floor.
	var win := Rect2(o + Vector2(140, 120), Vector2(170, 230))
	draw_rect(win, C_MOON.darkened(0.55))
	draw_circle(win.position + Vector2(118, 60), 26.0, C_MOON)
	draw_rect(Rect2(win.position.x + 82, win.position.y, 6, win.size.y), C_WALL)
	draw_rect(Rect2(win.position.x, win.position.y + 112, win.size.x, 6), C_WALL)
	var beam := PackedVector2Array([win.position + Vector2(0, win.size.y), win.end,
		Vector2(win.end.x + 260, floor_y + 150), Vector2(win.position.x + 120, floor_y + 150)])
	draw_colored_polygon(beam, Color(C_MOON, 0.07))
	# Workbench under the key.
	draw_rect(Rect2(o + Vector2(470, 500), Vector2(340, 26)), C_FLOOR.lightened(0.15))
	draw_rect(Rect2(o + Vector2(490, 526), Vector2(18, 90)), C_FLOOR.lightened(0.08))
	draw_rect(Rect2(o + Vector2(772, 526), Vector2(18, 90)), C_FLOOR.lightened(0.08))
	# A sleeping doll slumped on a stool, right of the bench.
	var d := o + Vector2(980, 470)
	draw_rect(Rect2(d + Vector2(-34, 60), Vector2(68, 14)), C_FLOOR.lightened(0.12))
	draw_rect(Rect2(d + Vector2(-26, 74), Vector2(8, 60)), C_FLOOR.lightened(0.05))
	draw_rect(Rect2(d + Vector2(18, 74), Vector2(8, 60)), C_FLOOR.lightened(0.05))
	draw_rect(Rect2(d + Vector2(-20, 6), Vector2(40, 56)), C_DOLL)
	draw_circle(d + Vector2(14, 0), 18.0, C_DOLL.lightened(0.08))
	draw_circle(d + Vector2(-22, 26), 6.0, C_BRASS_DARK)
	# The key: its stand, then the turning bow and shaft.
	var k := o + KEY_CENTER
	draw_rect(Rect2(k + Vector2(-16, 40), Vector2(32, 82)), C_BRASS_DARK)
	var wobble := sin(_anim * 2.4) * 0.05
	_draw_key(k, key_angle + wobble)
	# The spirit, bobbing beside the key.
	var s := k + Vector2(-150, -90 + sin(_anim * 1.7) * 10.0)
	draw_circle(s, 22.0, Color(C_SPIRIT, 0.18))
	draw_circle(s, 11.0, C_SPIRIT)
	if version_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 70, size.y - 14), version_text,
			HORIZONTAL_ALIGNMENT_RIGHT, 60, 12, Color(1, 1, 1, 0.35))


func _draw_key(center: Vector2, angle: float) -> void:
	draw_set_transform(center, angle)
	draw_arc(Vector2.ZERO, 70.0, 0.0, TAU, 48, C_BRASS, 22.0, true)
	draw_circle(Vector2.ZERO, 16.0, C_BRASS_DARK)
	for i in 4:
		var a := i * QUARTER
		draw_line(Vector2.from_angle(a) * 24.0, Vector2.from_angle(a) * 58.0, C_BRASS, 10.0, true)
	draw_set_transform(Vector2.ZERO, 0.0)
