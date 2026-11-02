class_name LabRegistry
extends RefCounted

## The six experiments, in the launcher's order. Each has a stable id -- its
## direct link is the Lab's address with `#<id>` -- a letter, a title, an icon
## from the game's atlas and a colour. `script` is the experiment once it is
## built; until then the tile says SOON and opens the common stub
## (experiments/stub), which is the Lab's frame with a tiny placeholder loop.

const STUB := "res://experiments/stub/stub.gd"

const EXPERIMENTS: Array[Dictionary] = [
	{"id": "island", "letter": "A", "title": "Island Growth", "icon": "villa", "color": Color("#4fb36b"), "script": "res://experiments/island/island.gd"},
	{"id": "evolution", "letter": "B", "title": "Momo Evolution", "icon": "momo_front", "color": Color("#e98fb1"), "script": ""},
	{"id": "rock", "letter": "C", "title": "Break & Upgrade", "icon": "prop_rocks", "color": Color("#8d8fa8"), "script": ""},
	{"id": "harvest", "letter": "D", "title": "Harvest Burst", "icon": "crop_ripe", "color": Color("#f0a843"), "script": ""},
	{"id": "tycoon", "letter": "E", "title": "Production Tycoon", "icon": "car_factory", "color": Color("#5a8fd8"), "script": ""},
	{"id": "tree", "letter": "F", "title": "Endless Growth", "icon": "prop_tree", "color": Color("#3d9a5a"), "script": ""},
]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in EXPERIMENTS:
		out.append(String(e["id"]))
	return out


static func has(id: String) -> bool:
	return ids().has(id)


static func find(id: String) -> Dictionary:
	for e: Dictionary in EXPERIMENTS:
		if String(e["id"]) == id:
			return e
	return {}


static func playable(id: String) -> bool:
	return String(find(id).get("script", "")) != ""


## The script that runs `id`: its own when built, the stub until then.
static func script_path(id: String) -> String:
	var own := String(find(id).get("script", ""))
	return own if own != "" else STUB


static func label(id: String) -> String:
	var e := find(id)
	return "%s · %s" % [e.get("letter", "?"), e.get("title", id)]
