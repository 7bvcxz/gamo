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
## The game's work loops (momo_work: a packed atlas, each frame its own rect,
## root pivot and measured torso and eyes marks).
const WORK_SHEET := preload("res://shared/momo/momo_work.png")
const WORK_PATH := "res://shared/momo/momo_work.json"
const HEADS_PATH := "res://lab/art/work_heads.json"
## Texels from a work frame's head top down to its eyes (the frames that have both).
const EYES_BELOW_TOP := 57.0

static var _data: Dictionary = {}
static var _work: Dictionary = {}
static var _work_frames: Dictionary = {}

## Drawn height relative to the game's Momo beside a 128-pixel tile.
var size := 0.8
## A work loop instead of standing ("" stands): `work_t` seconds into the
## loop of `work_anim` (the caller drives the clock, so the picture and the
## work it pays for keep step).
var work_anim := ""
var work_t := 0.0
## What Momo wears, drawn on the frame's own marks so it moves with the body:
## bag, hat, apron, scarf, helmet, medal, crown.
var accessories: Array[String] = []
## Where each worn thing was last drawn (local), for tests.
var worn_at: Dictionary = {}
## Stars twinkling round a Momo past every level (experiment B's endless).
var sparkle := 0
## Only what it wears, not the Momo (a teaser of the next thing to wear).
var only_wear := false
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


static func work() -> Dictionary:
	if _work.is_empty():
		_work = JSON.parse_string(FileAccess.get_file_as_string(WORK_PATH)) as Dictionary
		# Each frame's head top, measured from its texels (tools/work_heads.gd).
		var heads: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(HEADS_PATH)) as Dictionary)["heads"]
		for f: Dictionary in _work["frames"]:
			var name := String(f["name"])
			_work_frames[name] = f
			f["head"] = heads[name]
			# A frame bent over its work has no eyes mark (the face is hidden):
			# they are put where the head is, as far below its top as eyes are.
			if not f.has("eyes"):
				f["eyes"] = [float(heads[name][0]), float(heads[name][1]) + EYES_BELOW_TOP]
				f["eyes_from"] = "head"
	return _work


static func work_frame(name: String) -> Dictionary:
	work()
	return _work_frames.get(name, {})


## One pass of a work loop: its frames' times and the rest on the last.
static func loop_seconds(anim: String) -> float:
	var a: Dictionary = (work()["animations"] as Dictionary)[anim]
	var total := float(a.get("rest", 0.0))
	for d: Variant in a["durations"]:
		total += float(d)
	return total


## The frame of `anim` at `t` seconds into its loop, and its index.
static func frame_at(anim: String, t: float) -> Array:
	var a: Dictionary = (work()["animations"] as Dictionary)[anim]
	var cells: Array = a["cells"]
	var durations: Array = a["durations"]
	var at := fposmod(t, loop_seconds(anim))
	var sum := 0.0
	for i in durations.size():
		sum += float(durations[i])
		if at < sum:
			return [String(cells[i]), i]
	return [String(cells[cells.size() - 1]), cells.size() - 1]


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
	if work_anim != "":
		_draw_work()
		return
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


func _draw_work() -> void:
	var f := work_frame(String(frame_at(work_anim, work_t)[0]))
	if f.is_empty():
		return
	var r: Array = f["rect"]
	var region := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var pivot := Vector2(float(f["pivot"][0]), float(f["pivot"][1]))
	var s := HEIGHT * size / float(work()["stand_height"])
	var sx := -s if flipped else s
	var lift := -_hop * HEIGHT * size * 0.35
	if not only_wear:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, HEIGHT * size * 0.36 * (1.0 - _hop * 0.4), Color(0.05, 0.2, 0.1, 0.22))
		draw_set_transform(Vector2(0, lift), 0.0, Vector2(sx, s))
		draw_texture_rect_region(WORK_SHEET, Rect2(-pivot, region.size), region)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var to_local := func(mark: Array) -> Vector2:
		return Vector2((float(mark[0]) - pivot.x) * sx, (float(mark[1]) - pivot.y) * s + lift)
	if sparkle > 0:
		for k in mini(3 + sparkle, 10):
			var a := TAU * k / float(mini(3 + sparkle, 10)) + _time * 0.6
			var p := Vector2(cos(a) * HEIGHT * size * 0.6, -HEIGHT * size * 0.55 + sin(a) * HEIGHT * size * 0.45 + lift)
			var tw := 0.5 + 0.5 * sin(_time * 4.0 + k * 1.7)
			draw_circle(p, 3.2 * tw + 1.0, Color(1, 0.95, 0.6, 0.85))
	var eyes: Vector2 = to_local.call(f["eyes"])
	var torso: Vector2 = to_local.call(f["torso"])
	var head: Vector2 = to_local.call(f["head"])
	worn_at.clear()
	for a: String in accessories:
		worn_at[a] = LabWear.draw(self, a, eyes, torso, head, s, flipped)
