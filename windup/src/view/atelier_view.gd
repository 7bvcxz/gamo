class_name AtelierView
extends Node2D

## The atelier on screen: the backdrop, the big brass key in the middle (the
## one control), a doll, and the spirit. Art comes from assets/art/ (Step 03,
## design/ART_GUIDE.md); when it is missing the view draws the Step 02 shapes
## instead, so the game always opens -- `use_art` says which.
##
## Pressing the key (mouse, touch; Space is handled by the game) says so
## through `wind_pressed`; nothing on screen explains it in words.

signal wind_pressed(source: String)

const DESIGN := Vector2(1280, 720)
const KEY_CENTER := Vector2(640, 380)
const KEY_HIT_RADIUS := 120.0
const KEY_DRAW := 224.0
const QUARTER := PI / 2.0
## The first sleeping doll: on the floor in the moonlight, left of the bench.
const DOLL_POS := Vector2(430, 648)
const DOLL_SCALE := 0.8

const BACKDROP := "res://assets/art/backdrop.svg"
const KEY := "res://assets/art/key.svg"
## Where the design rectangle's centre is in the backdrop picture.
const BACKDROP_CENTER := Vector2(720, 480)

const C_WALL := Color(0.105, 0.098, 0.135)
const C_WALL_LOW := Color(0.075, 0.07, 0.095)
const C_FLOOR := Color(0.13, 0.095, 0.08)
const C_MOON := Color(0.78, 0.84, 0.95)
const C_BRASS := Color(0.85, 0.64, 0.25)
const C_BRASS_DARK := Color(0.55, 0.38, 0.14)
const C_SPIRIT := Color(1.0, 0.92, 0.66)
const C_DOLL := Color(0.24, 0.2, 0.22)

var key_angle: float = 0.0
var version_text: String = ""
## True when the art is in the project; false draws the shape fallback.
var use_art: bool = true
var doll: DollRig

var _target_angle: float = 0.0
var _anim: float = 0.0
var _backdrop: Texture2D
var _key: Texture2D


func _ready() -> void:
	use_art = use_art and ResourceLoader.exists(BACKDROP) and ResourceLoader.exists(KEY) and DollRig.art_present()
	if use_art:
		_backdrop = load(BACKDROP)
		_key = load(KEY)
		doll = DollRig.new()
		doll.scale = Vector2.ONE * DOLL_SCALE
		add_child(doll)
	_layout()
	get_viewport().size_changed.connect(_layout)


func reset() -> void:
	key_angle = 0.0
	_target_angle = 0.0
	if doll != null:
		doll.set_pose("asleep")
	queue_redraw()


## One quarter turn of the key (the visual half of a wind; the caller counts it).
func turn() -> void:
	_target_angle += QUARTER


func _layout() -> void:
	if doll != null:
		doll.position = _layout_offset() + DOLL_POS
	queue_redraw()


func _process(delta: float) -> void:
	_anim += delta
	key_angle = lerpf(key_angle, _target_angle, 1.0 - exp(-delta * 18.0))
	if doll != null:
		doll.advance(delta)
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
	if use_art:
		_draw_art()
	else:
		_draw_shapes()
	var s := key_center() + Vector2(-150, -96 + sin(_anim * 1.7) * 9.0)
	_draw_spirit(s)
	if version_text != "":
		var size := get_viewport_rect().size
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 70, size.y - 14), version_text,
			HORIZONTAL_ALIGNMENT_RIGHT, 60, 12, Color(1, 1, 1, 0.35))


func _draw_art() -> void:
	var size := get_viewport_rect().size
	var tex := Vector2(_backdrop.get_size())
	# Cover the visible area; the backdrop's centre stays on the design centre.
	var s := maxf(1.0, maxf(size.x / tex.x, size.y / tex.y))
	var centre := _layout_offset() + DESIGN * 0.5
	draw_texture_rect(_backdrop, Rect2(centre - BACKDROP_CENTER * s, tex * s), false)
	var wobble := sin(_anim * 2.4) * 0.04
	var k := key_center()
	draw_set_transform(k, key_angle + wobble)
	draw_texture_rect(_key, Rect2(Vector2(-KEY_DRAW, -KEY_DRAW) * 0.5, Vector2(KEY_DRAW, KEY_DRAW)), false)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_spirit(at: Vector2) -> void:
	for i in 4:
		draw_circle(at, 30.0 - i * 6.0, Color(C_SPIRIT, 0.06 + i * 0.05))
	draw_circle(at, 10.0, C_SPIRIT)
	draw_circle(at + Vector2(-3, -1), 1.6, Color(0.25, 0.18, 0.1))
	draw_circle(at + Vector2(3, -1), 1.6, Color(0.25, 0.18, 0.1))


## The Step 02 shapes: the fallback when the art is not there.
func _draw_shapes() -> void:
	var size := get_viewport_rect().size
	var o := _layout_offset()
	draw_rect(Rect2(Vector2.ZERO, size), C_WALL)
	var floor_y := o.y + 520.0
	draw_rect(Rect2(0, floor_y - 120.0, size.x, 120.0), C_WALL_LOW)
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), C_FLOOR)
	var win := Rect2(o + Vector2(140, 120), Vector2(170, 230))
	draw_rect(win, C_MOON.darkened(0.55))
	draw_circle(win.position + Vector2(118, 60), 26.0, C_MOON)
	draw_rect(Rect2(win.position.x + 82, win.position.y, 6, win.size.y), C_WALL)
	draw_rect(Rect2(win.position.x, win.position.y + 112, win.size.x, 6), C_WALL)
	var beam := PackedVector2Array([win.position + Vector2(0, win.size.y), win.end,
		Vector2(win.end.x + 260, floor_y + 150), Vector2(win.position.x + 120, floor_y + 150)])
	draw_colored_polygon(beam, Color(C_MOON, 0.07))
	draw_rect(Rect2(o + Vector2(470, 500), Vector2(340, 26)), C_FLOOR.lightened(0.15))
	draw_rect(Rect2(o + Vector2(490, 526), Vector2(18, 90)), C_FLOOR.lightened(0.08))
	draw_rect(Rect2(o + Vector2(772, 526), Vector2(18, 90)), C_FLOOR.lightened(0.08))
	var d := o + Vector2(980, 470)
	draw_rect(Rect2(d + Vector2(-34, 60), Vector2(68, 14)), C_FLOOR.lightened(0.12))
	draw_rect(Rect2(d + Vector2(-26, 74), Vector2(8, 60)), C_FLOOR.lightened(0.05))
	draw_rect(Rect2(d + Vector2(18, 74), Vector2(8, 60)), C_FLOOR.lightened(0.05))
	draw_rect(Rect2(d + Vector2(-20, 6), Vector2(40, 56)), C_DOLL)
	draw_circle(d + Vector2(14, 0), 18.0, C_DOLL.lightened(0.08))
	draw_circle(d + Vector2(-22, 26), 6.0, C_BRASS_DARK)
	var k := key_center()
	draw_rect(Rect2(k + Vector2(-16, 40), Vector2(32, 82)), C_BRASS_DARK)
	draw_set_transform(k, key_angle + sin(_anim * 2.4) * 0.05)
	draw_arc(Vector2.ZERO, 70.0, 0.0, TAU, 48, C_BRASS, 22.0, true)
	draw_circle(Vector2.ZERO, 16.0, C_BRASS_DARK)
	for i in 4:
		var a := i * QUARTER
		draw_line(Vector2.from_angle(a) * 24.0, Vector2.from_angle(a) * 58.0, C_BRASS, 10.0, true)
	draw_set_transform(Vector2.ZERO, 0.0)
