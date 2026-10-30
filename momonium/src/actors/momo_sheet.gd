class_name MomoSheet
extends RefCounted

## Momo's 5x5 sprite sheet and its map (Step 51, design/MOMO_SPRITES.md):
## equal cells, one pose of the same Momo in each, the feet of every pose on
## the same pivot. Loaded once and shared by every Momo on the island.
##
## Step 66: beside it, the work atlas (design/MOMO_TOOLS.md) -- Momo with the
## tool of each job, trimmed frames packed with a pivot each, at the same
## texel scale. A frame name is looked up in either; `texture_of`, `region`
## and `pivot_of` answer for both, so the rig never asks which.
##
## Step 76: every pivot is the picture's root -- the point on the ground
## between Momo's feet, measured from the drawing (design/MOMO_ANCHORS.md) --
## so a frame change never moves Momo. `marks` gives the measured feet, torso
## and eyes for the calibration gallery (scenes/dev/momo_calibration.tscn).

const TEXTURE := "res://assets/momo/momo_sheet.png"
const MAP := "res://assets/momo/momo_sheet.json"
const WORK_TEXTURE := "res://assets/momo/momo_work.png"
const WORK_MAP := "res://assets/momo/momo_work.json"

static var _shared: MomoSheet

var texture: Texture2D
var cell := Vector2i(256, 256)
var cols := 5
var rows := 5
## Where the feet are, from a cell's top-left.
var pivot := Vector2(128, 242)
## Texels from the fur curl to the feet of a standing pose.
var stand_height := 200.0
## name -> {row, col, view, state, frame, box}
var cells: Dictionary = {}
## name -> {cells: [names], fps}
var animations: Dictionary = {}
var work_texture: Texture2D
## The work atlas's texels from feet to fur curl (Step 67: stored at a share
## of the sheet's density; drawn by it, the same size on the island).
var work_stand_height := 200.0
## Work atlas frames: name -> {rect: Rect2, pivot: Vector2 (from the rect's top-left)}.
var work_frames: Dictionary = {}
## name -> the map's entry (its `root` method and measured marks).
var _entries: Dictionary = {}
## A building stage's action (data/buildings.json) -> the work animation it plays.
var actions: Dictionary = {}


static func shared() -> MomoSheet:
	if _shared == null:
		_shared = MomoSheet.new()
		_shared._load()
	return _shared


func _load() -> void:
	texture = load(TEXTURE)
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	cell = Vector2i(int(map["cell"][0]), int(map["cell"][1]))
	cols = int(map["cols"])
	rows = int(map["rows"])
	pivot = Vector2(float(map["pivot"][0]), float(map["pivot"][1]))
	stand_height = float(map["stand_height"])
	for c: Dictionary in map["cells"]:
		cells[String(c["name"])] = c
		_entries[String(c["name"])] = c
	animations = map["animations"]
	if not ResourceLoader.exists(WORK_TEXTURE):
		return
	work_texture = load(WORK_TEXTURE)
	var work: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORK_MAP))
	work_stand_height = float(work["stand_height"])
	for f: Dictionary in work["frames"]:
		var r: Array = f["rect"]
		work_frames[String(f["name"])] = {"rect": Rect2(r[0], r[1], r[2], r[3]), "pivot": Vector2(f["pivot"][0], f["pivot"][1])}
		_entries[String(f["name"])] = f
	for a: String in work["animations"]:
		animations[a] = work["animations"][a]
	actions = work["actions"]


## The rect `name` occupies on its texture.
func region(name: String) -> Rect2:
	if work_frames.has(name):
		return work_frames[name]["rect"]
	var c: Dictionary = cells[name]
	return Rect2(Vector2(int(c["col"]) * cell.x, int(c["row"]) * cell.y), Vector2(cell))


func texture_of(name: String) -> Texture2D:
	return work_texture if work_frames.has(name) else texture


## Texels from the feet to the fur curl in `name`'s texture.
func stand_height_of(name: String) -> float:
	return work_stand_height if work_frames.has(name) else stand_height


## Where the feet are, from the top-left of `name`'s rect.
func pivot_of(name: String) -> Vector2:
	return work_frames[name]["pivot"] if work_frames.has(name) else pivot


## How `name`'s root was found ("feet", "head" for a walk, or an authored
## one -- "planted", "foot", "torso", "box", "at"), and its measured marks
## from the top-left of its rect: {method, feet: [Vector2], torso: Vector2,
## eyes: Vector2 (absent when shut)}.
func marks(name: String) -> Dictionary:
	var e: Dictionary = _entries.get(name, {})
	var out := {"method": String(e.get("root", "")), "feet": []}
	for f: Array in e.get("feet", []):
		(out["feet"] as Array).append(Vector2(float(f[0]), float(f[1])))
	for k: String in ["torso", "eyes"]:
		if e.has(k):
			out[k] = Vector2(float(e[k][0]), float(e[k][1]))
	return out


## The work animation a stage's action plays ("" none: back turned).
func work_animation(action: String) -> String:
	return String(actions.get(action, ""))


## The cells `animation` plays, in order (a still pose is one cell).
func frames(animation: String) -> Array:
	return animations.get(animation, {}).get("cells", [])


func fps(animation: String) -> float:
	return float(animations.get(animation, {}).get("fps", 0.0))
