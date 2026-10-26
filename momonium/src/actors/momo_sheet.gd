class_name MomoSheet
extends RefCounted

## Momo's 5x5 sprite sheet and its map (Step 51, design/MOMO_SPRITES.md):
## equal cells, one pose of the same Momo in each, the feet of every pose on
## the same pivot. Loaded once and shared by every Momo on the island.

const TEXTURE := "res://assets/momo/momo_sheet.png"
const MAP := "res://assets/momo/momo_sheet.json"

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
	animations = map["animations"]


## The cell `name` occupies on the texture.
func region(name: String) -> Rect2:
	var c: Dictionary = cells[name]
	return Rect2(Vector2(int(c["col"]) * cell.x, int(c["row"]) * cell.y), Vector2(cell))


## The cells `animation` plays, in order (a still pose is one cell).
func frames(animation: String) -> Array:
	return animations.get(animation, {}).get("cells", [])


func fps(animation: String) -> float:
	return float(animations.get(animation, {}).get("fps", 0.0))
