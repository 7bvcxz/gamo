class_name PopRegistry
extends RefCounted

## The experiments the chooser can open, in the chooser's order. `listed` puts
## a tile on the chooser; an unlisted one still opens from its address (#stub is
## the Step 03 foundation, kept for tests). The address of each is its id:
## #click (A), #perfect (B), #explosion (C). Each entry names its rules script (no picture
## in it) and the colour of its tile and frame.

const EXPERIMENTS: Array[Dictionary] = [
	# Step 10: the owner-approved vertical slice on B's hold and release (#114).
	# `keep`: leaving parks the run and reopening resumes it (Step 11); restart starts over.
	{"id": "stand", "letter": "", "listed": true, "keep": true,
		"rules": "res://variants/stand/stand_rules.gd", "view": "res://variants/stand/stand_view.gd",
		"color": Color(0.85, 0.2, 0.32)},
	{"id": "click", "letter": "A", "listed": true,
		"rules": "res://variants/click/click_rules.gd", "view": "res://variants/click/click_view.gd",
		"color": Color(0.91, 0.27, 0.23)},
	{"id": "perfect", "letter": "B", "listed": true,
		"rules": "res://variants/perfect/perfect_rules.gd", "view": "res://variants/perfect/perfect_view.gd",
		"color": Color(0.95, 0.6, 0.12)},
	{"id": "explosion", "letter": "C", "listed": true,
		"rules": "res://variants/explosion/explosion_rules.gd", "view": "res://variants/explosion/explosion_view.gd",
		"color": Color(0.55, 0.3, 0.75)},
	{"id": "stub", "letter": "S", "listed": false,
		"rules": "res://variants/stub/stub_rules.gd", "view": "res://variants/stub/stub_view.gd",
		"color": Color(0.5, 0.5, 0.5)},
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
