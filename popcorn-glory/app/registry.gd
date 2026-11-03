class_name PopRegistry
extends RefCounted

## The experiments the chooser can open. `listed` puts a tile on the chooser;
## an unlisted one still opens from its address (#stub is the Step 03
## foundation, kept for tests). Each entry names its rules script (no picture
## in it) and the colour of its tile and frame.

const EXPERIMENTS: Array[Dictionary] = [
	{"id": "stub", "letter": "S", "listed": true,
		"rules": "res://variants/stub/stub_rules.gd", "view": "res://variants/stub/stub_view.gd",
		"color": Color(0.91, 0.27, 0.23)},
]


static func find(id: String) -> Dictionary:
	for e: Dictionary in EXPERIMENTS:
		if String(e["id"]) == id:
			return e
	return {}


static func listed() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in EXPERIMENTS:
		if bool(e["listed"]):
			out.append(e)
	return out


static func make_rules(id: String, economy: PopEconomy = null) -> PopRules:
	var e := find(id)
	if e.is_empty():
		return null
	var script: GDScript = load(String(e["rules"]))
	return script.new(economy)
