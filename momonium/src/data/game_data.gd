class_name GameData
extends RefCounted

## Every number and table the game plays by, loaded from res://data/*.json.
##
## Balance lives in data, not in code: a cost, a duration or an unlock is
## changed by editing a table, and the table is validated before the game
## trusts it. JSON rather than .tres because the tables are edited outside the
## editor, diff cleanly and are read by tests and tools as plain data.
##
## One instance is created at startup and handed to the Simulation -- there is
## no global. Tests may build their own instance with overrides.

## Tables the game loads. A file in data/ that is not listed here is an error
## (see test_data), so a new table cannot be silently ignored.
const TABLES: PackedStringArray = ["balance", "art"]

var tables: Dictionary = {}
var errors: Array[String] = []


static func load_default() -> GameData:
	var data := GameData.new()
	for name: String in TABLES:
		data.tables[name] = data._read_json("res://data/%s.json" % name)
	data.validate()
	return data


## Builds data from in-memory tables (tests). Missing tables come from disk.
static func from_tables(overrides: Dictionary) -> GameData:
	var data := GameData.new()
	for name: String in TABLES:
		data.tables[name] = overrides[name] if overrides.has(name) else data._read_json("res://data/%s.json" % name)
	data.validate()
	return data


func table(name: String) -> Dictionary:
	return tables.get(name, {})


## Reads a nested value: get_value("balance", "start.money").
func get_value(table_name: String, path: String, fallback: Variant = null) -> Variant:
	var node: Variant = table(table_name)
	for part: String in path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(part):
			return fallback
		node = node[part]
	return node


## JSON numbers arrive as floats; these read them as the type the rule means.
func get_int(table_name: String, path: String, fallback: int = 0) -> int:
	var value: Variant = get_value(table_name, path, fallback)
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback


func get_float(table_name: String, path: String, fallback: float = 0.0) -> float:
	var value: Variant = get_value(table_name, path, fallback)
	return float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback


func get_vec2i(table_name: String, path: String, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	var value: Variant = get_value(table_name, path)
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 2:
		return fallback
	return Vector2i(int(value[0]), int(value[1]))


func is_valid() -> bool:
	return errors.is_empty()


func validate() -> void:
	errors.clear()
	_validate_balance(table("balance"))
	_validate_art()


func _validate_balance(t: Dictionary) -> void:
	_require_number(t, "balance", "start.money", 0)
	_require_number(t, "balance", "start.level", 1)
	_require_number(t, "balance", "start.exp", 0)
	_require_number(t, "balance", "clock.day_seconds", 1)
	var size: Variant = get_value("balance", "start.island.size")
	if typeof(size) != TYPE_ARRAY or (size as Array).size() != 2:
		errors.append("balance: start.island.size must be [w, h]")
	var origin: Variant = get_value("balance", "start.island.origin")
	if typeof(origin) != TYPE_ARRAY or (origin as Array).size() != 2:
		errors.append("balance: start.island.origin must be [x, y]")


func _validate_art() -> void:
	_require_number({}, "art", "projection.tile_width", 16)
	_require_number({}, "art", "projection.elevation_deg", 30)
	_require_number({}, "art", "projection.cliff_height", 0)
	var elevation := get_float("art", "projection.elevation_deg")
	if elevation < 50.0 or elevation > 60.0:
		errors.append("art: projection.elevation_deg %s is outside the 50-60 degree view the art is drawn for" % elevation)
	if int(get_int("art", "projection.tile_width")) % 2 != 0:
		errors.append("art: projection.tile_width must be even so tile corners land on whole pixels")
	var palette: Variant = get_value("art", "palette")
	if typeof(palette) != TYPE_DICTIONARY:
		errors.append("art: palette missing")
		return
	for key: String in palette:
		var value: Variant = palette[key]
		var colors: Array = value if typeof(value) == TYPE_ARRAY else [value]
		for c: Variant in colors:
			if typeof(c) == TYPE_STRING and not Color.html_is_valid(c):
				errors.append("art: palette.%s has invalid colour %s" % [key, c])


## A palette colour by key (index into a gradient list when the entry is one).
func color(key: String, index: int = 0) -> Color:
	var value: Variant = get_value("art", "palette." + key)
	if typeof(value) == TYPE_ARRAY:
		value = value[clampi(index, 0, (value as Array).size() - 1)]
	return Color.html(value) if typeof(value) == TYPE_STRING and Color.html_is_valid(value) else Color.MAGENTA


func _require_number(_t: Dictionary, table_name: String, path: String, minimum: float) -> void:
	var value: Variant = get_value(table_name, path)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		errors.append("%s: %s must be a number (got %s)" % [table_name, path, var_to_str(value)])
	elif float(value) < minimum:
		errors.append("%s: %s must be >= %s (got %s)" % [table_name, path, minimum, value])


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing data file %s" % path)
		return {}
	var json := JSON.new()
	var err := json.parse(FileAccess.get_file_as_string(path))
	if err != OK:
		errors.append("%s:%d %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("%s: top level must be an object" % path)
		return {}
	return json.data
