class_name PopEconomy
extends RefCounted

## The numbers of every experiment, read from data/economy.json and checked
## once. Nothing else in the game writes a price or a yield down.

const PATH := "res://data/economy.json"

var tables: Dictionary = {}
var errors: Array[String] = []


static func load_default() -> PopEconomy:
	var e := PopEconomy.new()
	e.load_file(PATH)
	return e


func load_file(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("%s: not a JSON object" % path)
		return false
	return load_dict(parsed)


func load_dict(data: Dictionary) -> bool:
	tables.clear()
	errors.clear()
	for key: String in data.keys():
		if key.begins_with("_"):
			continue
		var t: Variant = data[key]
		if typeof(t) != TYPE_DICTIONARY:
			errors.append("%s: not an object" % key)
			continue
		_check(key, t)
		tables[key] = t
	return errors.is_empty()


func has(variant: String) -> bool:
	return tables.has(variant)


func table(variant: String) -> Dictionary:
	return tables.get(variant, {})


## Price of the upgrade bought at `level` (from level to level + 1);
## -1 when there is none.
func cost(variant: String, level: int) -> int:
	var t := table(variant)
	if level < 0 or level >= max_level(variant):
		return -1
	var c: Dictionary = t["cost"]
	return int(round(float(c["base"]) * pow(float(c["growth"]), level)))


func max_level(variant: String) -> int:
	return int(table(variant).get("max_level", 0))


## A list value of the table at `level`, clamped to the list's end.
func at(variant: String, key: String, level: int) -> int:
	var list: Array = table(variant).get(key, [])
	if list.is_empty():
		return 0
	return int(list[clampi(level, 0, list.size() - 1)])


func _check(key: String, t: Dictionary) -> void:
	var top := int(t.get("max_level", -1))
	if top < 1:
		errors.append("%s: max_level must be at least 1" % key)
	var c: Variant = t.get("cost")
	if typeof(c) != TYPE_DICTIONARY or float(c.get("base", 0)) < 1.0 or float(c.get("growth", 0)) <= 1.0:
		errors.append("%s: cost needs base >= 1 and growth > 1" % key)
	for list_key: String in ["pops", "batch", "burst"]:
		if not t.has(list_key):
			continue
		var list: Array = t[list_key]
		if list.size() < top + 1:
			errors.append("%s.%s: needs max_level + 1 = %d entries, has %d" % [key, list_key, top + 1, list.size()])
		var previous := 0
		for v: Variant in list:
			# Every upgrade must change what a press does (Step 02 found a
			# rounded table whose first upgrade changed nothing).
			if int(v) <= previous:
				errors.append("%s.%s: must rise strictly, %d after %d" % [key, list_key, int(v), previous])
			previous = int(v)
