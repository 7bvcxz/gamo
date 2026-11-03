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
	{"id": "evolution", "letter": "B", "title": "Momo Evolution", "icon": "momo_front", "color": Color("#e98fb1"), "script": "res://experiments/evolution/evolution.gd"},
	{"id": "rock", "letter": "C", "title": "Break & Upgrade", "icon": "prop_rocks", "color": Color("#8d8fa8"), "script": "res://experiments/rock/rock.gd"},
	{"id": "harvest", "letter": "D", "title": "Harvest Burst", "icon": "crop_ripe", "color": Color("#f0a843"), "script": "res://experiments/harvest/harvest.gd"},
	{"id": "tycoon", "letter": "E", "title": "Production Tycoon", "icon": "car_factory", "color": Color("#5a8fd8"), "script": "res://experiments/tycoon/tycoon.gd"},
	{"id": "tree", "letter": "F", "title": "Endless Growth", "icon": "prop_tree", "color": Color("#3d9a5a"), "script": "res://experiments/tree/tree.gd"},
]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in EXPERIMENTS:
		out.append(String(e["id"]))
	return out


static func has(id: String) -> bool:
	return ids().has(id)


## Step 94: the owner played the six and chose two -- C and E. Each now has
## an improved track beside its frozen baseline: `#rock` and `#tycoon` stay
## exactly the Step 88 and Step 92 experiments (tests/unit/test_baselines.gd
## pins their files), `#rock-plus` and `#tycoon-plus` are where Steps 95-98
## improve them. A track has its own id, so its link, its records and its
## scores never mix with the baseline's; `base` names the experiment it grew
## from. Only the launcher's chooser says which is the baseline and which the
## improved one; a run shows the letter (C or C+) and nothing else.
const TRACKS: Array[Dictionary] = [
	{"id": "rock-plus", "base": "rock", "letter": "C+", "title": "Break & Upgrade", "icon": "prop_rocks", "color": Color("#8d8fa8"), "script": "res://experiments/rock_plus/rock_plus.gd"},
	{"id": "tycoon-plus", "base": "tycoon", "letter": "E+", "title": "Production Tycoon", "icon": "car_factory", "color": Color("#5a8fd8"), "script": "res://experiments/tycoon_plus/tycoon_plus.gd"},
]

## The frame's own demonstration (the stub) answers `#stub` too, though no
## tile shows it: the Lab's tests use it once every experiment is built.
const HIDDEN: Array[String] = ["stub"]


static func routable(id: String) -> bool:
	return has(id) or is_track(id) or HIDDEN.has(id)


static func find(id: String) -> Dictionary:
	for e: Dictionary in EXPERIMENTS + TRACKS:
		if String(e["id"]) == id:
			return e
	return {}


static func track_ids() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in TRACKS:
		out.append(String(e["id"]))
	return out


static func is_track(id: String) -> bool:
	return track_ids().has(id)


## The improved track grown from `base` ("" if it has none).
static func track_of(base: String) -> String:
	for e: Dictionary in TRACKS:
		if String(e["base"]) == base:
			return String(e["id"])
	return ""


## The baseline a track grew from; an experiment is its own baseline.
static func base_of(id: String) -> String:
	return String(find(id).get("base", id))


static func playable(id: String) -> bool:
	return String(find(id).get("script", "")) != ""


## The script that runs `id`: its own when built, the stub until then.
static func script_path(id: String) -> String:
	var own := String(find(id).get("script", ""))
	return own if own != "" else STUB


static func label(id: String) -> String:
	if id == "stub":
		return "Lab · Frame demo"
	var e := find(id)
	return "%s · %s" % [e.get("letter", "?"), e.get("title", id)]
