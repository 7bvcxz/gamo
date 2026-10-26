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
const TABLES: PackedStringArray = ["balance", "art", "buildings", "items", "letters", "research", "recipes"]

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
	_validate_buildings()
	_validate_letters()
	_validate_families()
	_validate_recipes()
	_validate_research()
	_require_number({}, "balance", "land.base", 1)
	_require_number({}, "balance", "land.growth", 1)
	_require_number({}, "balance", "land.round_to", 1)


## Varieties: base is the type's cycle; another variety's own process must be
## a real cycle (unique stage ids, something harvested, one look per stage).
func _validate_varieties(key: String, def: Dictionary, items: Dictionary) -> void:
	var vs: Dictionary = def.get("varieties", {})
	if vs.is_empty():
		return
	if not vs.has("base"):
		errors.append("buildings: %s.varieties needs base" % key)
	for v: String in vs:
		if v.begins_with("_"):
			continue
		var vdef: Dictionary = vs[v]
		if String(vdef.get("name", "")) == "":
			errors.append("buildings: %s variety %s needs a name" % [key, v])
		var stages: Array = vdef.get("stages", def.get("cycle", {}).get("stages", []))
		var ids := {}
		var yields := false
		for st: Dictionary in stages:
			if ids.has(st.get("id", "")):
				errors.append("buildings: %s variety %s repeats stage %s" % [key, v, st.get("id", "")])
			ids[st.get("id", "")] = true
			yields = yields or not (st.get("yield", {}) as Dictionary).is_empty()
		for sid: String in vdef.get("yield", {}):
			if not ids.has(sid):
				errors.append("buildings: %s variety %s yields at unknown stage %s" % [key, v, sid])
			for item: String in vdef["yield"][sid]:
				yields = true
				if not items.has(item):
					errors.append("buildings: %s variety %s yields unknown item %s" % [key, v, item])
		if not yields:
			errors.append("buildings: %s variety %s harvests nothing" % [key, v])
		if vdef.has("stages") and (vdef.get("looks", []) as Array).size() != stages.size():
			errors.append("buildings: %s variety %s needs one look per stage" % [key, v])


## Recipes: real inputs and outputs, a building that lists them, time > 0.
func _validate_recipes() -> void:
	var types: Dictionary = table("buildings").get("types", {})
	var items: Dictionary = table("items").get("items", {})
	var ids := {}
	for r: Dictionary in table("recipes").get("recipes", []):
		var id := String(r.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("recipes: every recipe needs a unique id (%s)" % id)
		ids[id] = true
		var b := String(r.get("building", ""))
		if not types.has(b) or not (types[b].get("recipes", []) as Array).has(id):
			errors.append("recipes: %s names building %s, which does not list it" % [id, b])
		if (r.get("inputs", {}) as Dictionary).is_empty() or (r.get("outputs", {}) as Dictionary).is_empty():
			errors.append("recipes: %s needs inputs and outputs -- nothing from nothing" % id)
		for side: String in ["inputs", "outputs"]:
			for item: String in r.get(side, {}):
				if not items.has(item) or int(r[side][item]) < 1:
					errors.append("recipes: %s %s unknown item or count %s" % [id, side, item])
		if float(r.get("seconds", 0)) <= 0.0:
			errors.append("recipes: %s.seconds must be > 0" % id)
	for t: String in types:
		for id: String in types[t].get("recipes", []):
			if not ids.has(id):
				errors.append("buildings: %s lists unknown recipe %s" % [t, id])


## Exactly the four families are placed on land; every other type belongs
## to one of them (refitted in place).
func _validate_families() -> void:
	var types: Dictionary = table("buildings").get("types", {})
	var placeable: Array[String] = []
	for key: String in types:
		if bool(types[key].get("placeable", true)) and not bool(types[key].get("special", false)):
			placeable.append(key)
	placeable.sort()
	if not table("buildings").has("_test_any_families") and placeable != (["farm", "lumberyard", "mine", "research"] as Array[String]):
		errors.append("buildings: exactly farm, mine, lumberyard and research are placeable (got %s)" % [placeable])
	for key: String in types:
		if bool(types[key].get("special", false)):
			# A landmark: no family, no work, and never a production type.
			if types[key].has("family") or int(types[key].get("workers", 0)) > 0 or types[key].has("cycle") or bool(types[key].get("placeable", false)):
				errors.append("buildings: special %s must have no family, workers, work cycle or plain placement" % key)
			var e: Dictionary = types[key].get("effect", {})
			match String(e.get("kind", "")):
				"work_burst":
					if float(e.get("multiply", 0)) <= 0.0 or float(e.get("multiply", 0)) >= 1.0 or float(e.get("active_seconds", 0)) <= 0.0 or float(e.get("cycle_seconds", 0)) <= float(e.get("active_seconds", 0)):
						errors.append("buildings: %s work_burst needs multiply in (0, 1) and a burst shorter than its cycle" % key)
				"skill_exp":
					if float(e.get("multiply", 0)) <= 1.0 or float(e.get("multiply", 0)) > 2.0:
						errors.append("buildings: %s skill_exp multiply must be in (1, 2]" % key)
				"legacy":
					if float(e.get("share", 0)) <= 0.0 or float(e.get("share", 0)) > 0.5:
						errors.append("buildings: %s legacy share must be in (0, 0.5]" % key)
				"":
					pass
				_:
					errors.append("buildings: %s has an unknown special effect %s" % [key, e.get("kind", "")])
			continue
		var fam := String(types[key].get("family", key))
		if not types.has(fam) or not bool(types[fam].get("placeable", true)):
			errors.append("buildings: %s belongs to family %s, which is not a placeable type" % [key, fam])


func _validate_letters() -> void:
	var types: Dictionary = table("buildings").get("types", {})
	var seen := {}
	for l: Dictionary in table("letters").get("letters", []):
		var id := String(l.get("id", ""))
		if id == "" or seen.has(id):
			errors.append("letters: every letter needs a unique id (%s)" % id)
		seen[id] = true
		if not types.has(String(l.get("industry", ""))):
			errors.append("letters: %s.industry %s is not a building type" % [id, l.get("industry", "")])
		var trigger: Dictionary = l.get("trigger", {})
		if trigger.size() != 1 or not (trigger.has("work") or trigger.has("mastery")):
			errors.append("letters: %s.trigger must be exactly one of {work}, {mastery}" % id)
		for kind: String in trigger:
			for t: String in trigger[kind]:
				if not types.has(t) or float(trigger[kind][t]) < 1.0:
					errors.append("letters: %s.trigger.%s.%s must name a building type and a count >= 1" % [id, kind, t])
		for key: String in ["title", "body", "research"]:
			if String(l.get(key, "")) == "":
				errors.append("letters: %s.%s missing" % [id, key])


func _validate_research() -> void:
	var types: Dictionary = table("buildings").get("types", {})
	var items: Dictionary = table("items").get("items", {})
	var ids := {}
	for n: Dictionary in table("research").get("nodes", []):
		var id := String(n.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("research: every node needs a unique id (%s)" % id)
		ids[id] = n
	for id: String in ids:
		var n: Dictionary = ids[id]
		var industry := String(n.get("industry", ""))
		if industry != "global" and not types.has(industry) and not (table("research").get("branches", []) as Array).has(industry):
			errors.append("research: %s.industry %s is neither a building type, a branch nor global" % [id, industry])
		for r: String in n.get("requires", []):
			if not ids.has(r):
				errors.append("research: %s requires unknown %s" % [id, r])
		if float(n.get("seconds", 0)) <= 0.0:
			errors.append("research: %s.seconds must be > 0" % id)
		for item: String in n.get("cost", {}).get("items", {}):
			if not items.has(item):
				errors.append("research: %s costs unknown item %s" % [id, item])
		for t: String in n.get("unlock", {}).get("mastery", {}):
			if not types.has(t):
				errors.append("research: %s.unlock.mastery names unknown type %s" % [id, t])
		for k: String in ["name", "desc"]:
			if String(n.get(k, "")) == "":
				errors.append("research: %s.%s missing" % [id, k])
		for e: Dictionary in n.get("effects", []):
			_validate_effect(id, e, types, items)
	# No node may (indirectly) require itself.
	for id: String in ids:
		var seen := {}
		var stack: Array = [id]
		while not stack.is_empty():
			var cur := String(stack.pop_back())
			for r: String in (ids.get(cur, {}) as Dictionary).get("requires", []):
				if r == id:
					errors.append("research: %s requires itself through %s" % [id, cur])
					stack.clear()
					break
				if not seen.has(r):
					seen[r] = true
					stack.append(r)
	# Every recipe that is not known from the start must be opened by research.
	var open_recipes := {}
	for id: String in ids:
		for e: Dictionary in (ids[id] as Dictionary).get("effects", []):
			if String(e.get("kind", "")) == "recipe":
				open_recipes[String(e.get("recipe", ""))] = true
	for r: Dictionary in table("recipes").get("recipes", []):
		if not bool(r.get("default", false)) and not open_recipes.has(String(r.get("id", ""))):
			errors.append("recipes: %s is opened by no research" % r.get("id", ""))
	# Every variety but base must be opened by some research, or it is unreachable.
	var opened := {}
	for id: String in ids:
		for e: Dictionary in (ids[id] as Dictionary).get("effects", []):
			if String(e.get("kind", "")) == "variety":
				opened["%s/%s" % [e.get("type", ""), e.get("variety", "")]] = true
	for t: String in table("buildings").get("types", {}):
		for v: String in table("buildings")["types"][t].get("varieties", {}):
			if v != "base" and not v.begins_with("_") and not opened.has("%s/%s" % [t, v]):
				errors.append("buildings: %s variety %s is opened by no research" % [t, v])
	# Letters and the tree must agree: every proposal is a node, and every
	# proposal-gated node is proposed by some letter (or it could never open).
	var proposed := {}
	for l: Dictionary in table("letters").get("letters", []):
		proposed[String(l.get("research", ""))] = true
		if not ids.has(String(l.get("research", ""))):
			errors.append("letters: %s proposes unknown research %s" % [l.get("id", "?"), l.get("research", "")])
	for id: String in ids:
		if bool((ids[id] as Dictionary).get("unlock", {}).get("proposal", false)) and not proposed.has(id):
			errors.append("research: %s waits for a proposal no letter makes" % id)


func _validate_effect(id: String, e: Dictionary, types: Dictionary, items: Dictionary) -> void:
	var kind := String(e.get("kind", ""))
	match kind:
		"work", "cooldown":
			var t := String(e.get("type", ""))
			if not types.has(t):
				errors.append("research: %s effect on unknown type %s" % [id, t])
			elif e.has("action") and not (types[t].get("cycle", {}).get("stages", []) as Array).any(func(st: Dictionary) -> bool: return st.get("action", "") == e["action"]):
				errors.append("research: %s effect on unknown action %s.%s" % [id, t, e["action"]])
			var m := float(e.get("multiply", 0.0))
			if m <= 0.0 or m > 1.0:
				errors.append("research: %s %s multiply must be in (0, 1] -- research makes things easier, not impossible" % [id, kind])
		"yield":
			var t := String(e.get("type", ""))
			var stage_ok := types.has(t) and (types[t].get("cycle", {}).get("stages", []) as Array).any(func(st: Dictionary) -> bool: return st.get("id", "") == e.get("stage", ""))
			if not stage_ok:
				errors.append("research: %s yield effect on unknown stage %s.%s" % [id, t, e.get("stage", "")])
			if not items.has(String(e.get("item", ""))):
				errors.append("research: %s yields unknown item %s" % [id, e.get("item", "")])
			var add := float(e.get("add", 0))
			if add <= 0.0 or absf(add * 1000.0 - round(add * 1000.0)) > 0.0001:
				errors.append("research: %s yield add must be > 0, in thousandths" % id)
		"auto":
			var t := String(e.get("type", ""))
			if not types.has(t) or not (types[t].get("cycle", {}).get("stages", []) as Array).any(func(st: Dictionary) -> bool: return st.get("action", "") == e.get("action", "")):
				errors.append("research: %s auto effect on unknown action %s.%s" % [id, t, e.get("action", "")])
		"variety":
			var t := String(e.get("type", ""))
			if not types.has(t) or not (types[t].get("varieties", {}) as Dictionary).has(String(e.get("variety", ""))):
				errors.append("research: %s opens unknown variety %s.%s" % [id, t, e.get("variety", "")])
		"recipe":
			var t := String(e.get("type", ""))
			if not types.has(t) or not (types[t].get("recipes", []) as Array).has(String(e.get("recipe", ""))):
				errors.append("research: %s opens unknown recipe %s.%s" % [id, t, e.get("recipe", "")])
		"batch":
			if not types.has(String(e.get("type", ""))) or int(e.get("add", 0)) < 1:
				errors.append("research: %s batch effect needs a type and add >= 1" % id)
		"power_use":
			var m := float(e.get("multiply", 0.0))
			if not types.has(String(e.get("type", ""))) or float(e.get("draw", 0)) <= 0.0 or m <= 0.0 or m > 1.0:
				errors.append("research: %s power_use needs a type, draw > 0 and multiply in (0, 1]" % id)
		"momo_work":
			var m := float(e.get("multiply", 0.0))
			if m <= 0.0 or m > 1.0 or (e.has("type") and not types.has(String(e["type"]))):
				errors.append("research: %s momo_work needs multiply in (0, 1] and a known type if any" % id)
		"sale_price", "walk_speed":
			var m := float(e.get("multiply", 0.0))
			if m < 1.0 or m > 2.0:
				errors.append("research: %s %s multiply must be in [1, 2]" % [id, kind])
		"research_time":
			var m := float(e.get("multiply", 0.0))
			if m <= 0.0 or m > 1.0:
				errors.append("research: %s research_time multiply must be in (0, 1]" % id)
		"watch_tiles":
			if int(e.get("add", 0)) < 1:
				errors.append("research: %s watch_tiles needs add >= 1" % id)
		"route":
			if not ["auto"].has(String(e.get("strategy", ""))):
				errors.append("research: %s opens an unknown route strategy %s" % [id, e.get("strategy", "")])
		_:
			errors.append("research: %s has unknown effect kind %s" % [id, kind])
	# Listed levels must only get better (a smaller multiplier for times, a
	# larger one or more for gains).
	var steps: Array = e.get("per_level", [])
	if not steps.is_empty():
		var prev := float(steps[0])
		for v: Variant in steps:
			var f := float(v)
			var better := f <= prev if e.has("multiply") and float(e["multiply"]) <= 1.0 else f >= prev
			if not better:
				errors.append("research: %s %s per_level must only get better with each level" % [id, kind])
				break
			prev = f


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
	_validate_day_cycle()
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


func _validate_buildings() -> void:
	var types: Variant = get_value("buildings", "types")
	if typeof(types) != TYPE_DICTIONARY or (types as Dictionary).is_empty():
		errors.append("buildings: types missing")
		return
	for key: String in types:
		var t: Dictionary = types[key]
		_validate_varieties(key, t, table("items").get("items", {}))
		var size: Variant = t.get("size")
		if typeof(size) != TYPE_ARRAY or (size as Array).size() != 2 or int(size[0]) < 1 or int(size[1]) < 1:
			errors.append("buildings: %s.size must be [w, h] >= 1" % key)
		var cost: Variant = t.get("cost", {})
		if typeof(cost) != TYPE_DICTIONARY or float((cost as Dictionary).get("money", 0)) < 0.0:
			errors.append("buildings: %s.cost must be {money >= 0, items}" % key)
		else:
			for item: String in (cost as Dictionary).get("items", {}):
				if not (get_value("items", "items", {}) as Dictionary).has(item):
					errors.append("buildings: %s costs unknown item %s" % [key, item])
		if float(t.get("build_seconds", 0)) <= 0.0:
			errors.append("buildings: %s.build_seconds must be > 0" % key)
		if int((t.get("unlock", {}) as Dictionary).get("level", 1)) < 1:
			errors.append("buildings: %s.unlock.level must be >= 1" % key)
		var stages: Variant = (t.get("cycle", {}) as Dictionary).get("stages")
		var generates := not ((t.get("power", {}) as Dictionary).get("generate", {}) as Dictionary).is_empty()
		var manages := bool(t.get("manages", false)) or not (t.get("housing", {}) as Dictionary).is_empty() or not (t.get("amenity", {}) as Dictionary).is_empty()
		var housing: Dictionary = t.get("housing", {})
		if not housing.is_empty() and (int(housing.get("capacity", 0)) < 1 or float(housing.get("rest", 0)) <= 0.0 or float(housing.get("rest", 0)) > 1.0):
			errors.append("buildings: %s.housing needs capacity >= 1 and rest in (0, 1]" % key)
		var amenity: Dictionary = t.get("amenity", {})
		if not amenity.is_empty() and float(amenity.get("happiness", 0)) <= 0.0:
			errors.append("buildings: %s.amenity needs happiness > 0" % key)
		for item: String in amenity.get("daily", {}):
			# `money`: a daily upkeep paid from the island's money (Step 50).
			if item == "money":
				continue
			if not table("items").get("items", {}).has(item):
				errors.append("buildings: %s.amenity.daily uses unknown item %s" % [key, item])
		if generates:
			var kind := String(t["power"]["generate"].get("kind", ""))
			if not ["solar", "wind", "steam", "hydro"].has(kind) or float(t["power"]["generate"].get("kw", 0)) <= 0.0:
				errors.append("buildings: %s.power.generate needs a known kind and kw > 0" % key)
			if kind == "steam" and (typeof(stages) != TYPE_ARRAY or not (stages as Array).any(func(st: Dictionary) -> bool: return not (st.get("consumes", {}) as Dictionary).is_empty())):
				errors.append("buildings: %s burns fuel but has no stage that takes any" % key)
		var research_needed := String((t.get("unlock", {}) as Dictionary).get("research", ""))
		if research_needed != "" and not (table("research").get("nodes", []) as Array).any(func(n: Dictionary) -> bool: return String(n.get("id", "")) == research_needed):
			errors.append("buildings: %s.unlock.research %s is not a research node" % [key, research_needed])
		# A landmark has no work cycle to check (its own rule is in _validate_families).
		if bool(t.get("special", false)):
			continue
		if typeof(stages) != TYPE_ARRAY or ((stages as Array).is_empty() and not generates and not manages):
			errors.append("buildings: %s.cycle.stages must list at least one stage" % key)
			continue
		var looks: Variant = (t.get("cycle", {}) as Dictionary).get("looks", [])
		if typeof(looks) == TYPE_ARRAY and not (looks as Array).is_empty() and (looks as Array).size() != (stages as Array).size():
			errors.append("buildings: %s.cycle.looks needs one entry per stage" % key)
		var ids := {}
		for st: Dictionary in stages:
			for item: String in st.get("yield", {}):
				if not (get_value("items", "items", {}) as Dictionary).has(item):
					errors.append("buildings: %s.%s yields unknown item %s" % [key, st.get("id", "?"), item])
			if not st.has("id") or ids.has(st["id"]):
				errors.append("buildings: %s has a stage without a unique id" % key)
			ids[st.get("id", "")] = true
			if float(st.get("seconds", 0)) <= 0.0:
				errors.append("buildings: %s.%s must take time (seconds > 0)" % [key, st.get("id", "?")])
			if float(st.get("cooldown", 0)) < 0.0:
				errors.append("buildings: %s.%s cooldown cannot be negative" % [key, st.get("id", "?")])


## Hot paths (every stage start asks): read the tables directly instead of
## splitting a path string on each call.
func item(key: String) -> Dictionary:
	var items: Variant = table("items").get("items", {})
	return (items as Dictionary).get(key, {}) if typeof(items) == TYPE_DICTIONARY else {}


func building_type(key: String) -> Dictionary:
	var types: Variant = table("buildings").get("types", {})
	return (types as Dictionary).get(key, {}) if typeof(types) == TYPE_DICTIONARY else {}


func _validate_day_cycle() -> void:
	var phases: Variant = get_value("balance", "clock.phases")
	if typeof(phases) != TYPE_ARRAY or (phases as Array).is_empty():
		errors.append("balance: clock.phases must list the parts of the day")
	else:
		var last := -1.0
		for p: Variant in phases:
			var from := float((p as Dictionary).get("from", -1.0))
			if from < last or from < 0.0 or from >= 1.0:
				errors.append("balance: clock.phases must start in [0, 1) and increase (%s)" % from)
			last = from
		if float((phases[0] as Dictionary).get("from", 1.0)) != 0.0:
			errors.append("balance: the first phase must start at 0")
	var keys: Variant = get_value("art", "day_cycle.keys")
	var looks: Variant = get_value("art", "day_cycle.looks")
	if typeof(keys) != TYPE_ARRAY or typeof(looks) != TYPE_DICTIONARY:
		errors.append("art: day_cycle needs keys and looks")
		return
	if float(keys[0]["t"]) != 0.0 or float(keys[-1]["t"]) != 1.0:
		errors.append("art: day_cycle keys must run from t=0 to t=1")
	for k: Dictionary in keys:
		if not (looks as Dictionary).has(k["look"]):
			errors.append("art: day_cycle key uses unknown look %s" % k["look"])
	for name: String in looks:
		for field: String in ["sky", "sea", "ambient", "cloud", "glint", "stars"]:
			if not (looks[name] as Dictionary).has(field):
				errors.append("art: day_cycle look %s lacks %s" % [name, field])


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
