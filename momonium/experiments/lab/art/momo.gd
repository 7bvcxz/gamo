class_name LabMomo
extends Node2D

## One Momo from the game's sheet (shared/momo, a copy of momonium/assets/momo):
## standing at the node's origin (the root between its feet, the sheet's
## pivot), breathing and blinking as in the game (momonium
## src/actors/momo_rig.gd: 72 world pixels tall at size 1, the game draws 0.8),
## and two flourishes the experiments use: `cheer()` (a happy face and a hop)
## and `look(cell_name)`. Reduced motion keeps the faces, not the hop.

const SHEET := preload("res://shared/momo/momo_sheet.png")
const DATA_PATH := "res://shared/momo/momo_sheet.json"
const HEIGHT := 72.0

static var _data: Dictionary = {}

## Drawn height relative to the game's Momo beside a 128-pixel tile.
var size := 0.8
var reduced_motion := false
var cell := "front_idle"
var flipped := false

var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _next_blink := 2.0
var _blink_until := -1.0
var _face_until := -1.0
var _face := ""
var _hop := 0.0
## Walking: from, to, how far along (1 = standing), pixels a second.
var walk_speed := 38.0
var _walk_from := Vector2.ZERO
var _walk_to := Vector2.ZERO
var _walk_t := 1.0
var _walk_len := 0.0

signal arrived


static func sheet() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) as Dictionary
	return _data


static func cell_info(name: String) -> Dictionary:
	for c: Dictionary in sheet()["cells"]:
		if String(c["name"]) == name:
			return c
	return {}


func _init() -> void:
	_rng.seed = 86
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## A happy face for a moment and a little hop.
func cheer(seconds: float = 1.2) -> void:
	_face = "happy"
	_face_until = _time + seconds
	if not reduced_motion:
		var tw := create_tween()
		tw.tween_property(self, "_hop", 1.0, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(self, "_hop", 0.0, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func look(name: String, seconds: float = 1.0) -> void:
	_face = name
	_face_until = _time + seconds


## Walks to `p` (the parent's coordinates) at walk_speed, the game's walk
## cycle facing the way it goes; `arrived` when there.
func walk_to(p: Vector2) -> void:
	_walk_from = position
	_walk_to = p
	_walk_len = position.distance_to(p)
	_walk_t = 0.0 if _walk_len > 1.0 else 1.0


func walking() -> bool:
	return _walk_t < 1.0


## Height on screen in local pixels (before the node's own scale).
func height() -> float:
	return HEIGHT * size


func _process(delta: float) -> void:
	_time += delta
	if walking():
		_walk_t = minf(1.0, _walk_t + delta * walk_speed / _walk_len)
		position = _walk_from.lerp(_walk_to, _walk_t)
		var d := _walk_to - _walk_from
		var view := "side" if absf(d.x) > absf(d.y) * 1.2 else ("back" if d.y < 0.0 else "front")
		flipped = view == "side" and d.x < 0.0
		cell = "%s_walk_%s" % [view, ["a", "b", "c", "b"][int(_time * 8.0) % 4]]
		if _walk_t >= 1.0:
			cell = "front_idle"
			flipped = false
			arrived.emit()
	if _time >= _next_blink:
		_blink_until = _time + 0.14
		_next_blink = _time + _rng.randf_range(1.5, 4.0)
	queue_redraw()


func _draw() -> void:
	var pose := cell
	if _time < _face_until and _face != "":
		pose = _face
	elif pose == "front_idle" and _time < _blink_until:
		pose = "front_blink"
	var info := cell_info(pose)
	if info.is_empty():
		return
	var d := sheet()
	var cw := Vector2(float(d["cell"][0]), float(d["cell"][1]))
	var pivot := Vector2(float(d["pivot"][0]), float(d["pivot"][1]))
	var region := Rect2(Vector2(float(info["col"]), float(info["row"])) * cw, cw)
	var s := HEIGHT * size / float(d["stand_height"])
	var breathe := 0.0 if reduced_motion else sin(_time * TAU * 0.45)
	var sc := Vector2(s * (1.0 - 0.006 * breathe) * (-1.0 if flipped else 1.0), s * (1.0 + 0.012 * breathe))
	var lift := -_hop * HEIGHT * size * 0.35
	# A soft shadow on the ground, smaller as it hops.
	var shadow := 1.0 - _hop * 0.4
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, HEIGHT * size * 0.36 * shadow, Color(0.05, 0.2, 0.1, 0.22))
	draw_set_transform(Vector2(0, lift), 0.0, sc)
	draw_texture_rect_region(SHEET, Rect2(-pivot, cw), region)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
