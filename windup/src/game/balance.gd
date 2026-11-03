class_name Balance
extends RefCounted

## data/balance.json, read once and checked. Every number the rules use comes
## from here; tests read the same file, so a tuning change is one edit.

const PATH := "res://data/balance.json"
const VARIANTS_PATH := "res://data/variants.json"

var energy_per_turn: float
var gear_bonus_per_doll: float
var max_turns_per_second: float
var hold_turns_per_second: float
var hold_delay: float
var awaken_seconds: float
var hint_idle_seconds: float
var idle_report_seconds: float
var autosave_seconds: float
var costs: PackedFloat64Array = PackedFloat64Array()
var rates: PackedFloat64Array = PackedFloat64Array()
var positions: Array[Vector2] = []
## [[min dolls, name], ...] ascending.
var stages: Array = []
## Step 06 variants ("base" is balance.json alone).
var variant: String = "base"
## A: turns coil a spring that is released on letting go.
var spring_enabled: bool = false
var spring_capacity_of_next_cost: float = 1.0
## B: sleepers under sheets, longer reveals (presentation only).
var reveal: bool = false
## C: a doll that finishes waking gives the next one rate x kick_seconds at once.
var kick_seconds: float = 0.0


static func load_default() -> Balance:
	var text := FileAccess.get_file_as_string(PATH)
	var data: Variant = JSON.parse_string(text)
	assert(data is Dictionary, "balance.json does not parse")
	return from_dict(data)


## balance.json with a variant's overrides from variants.json on top.
static func load_variant(id: String) -> Balance:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if id == "base":
		var b0 := from_dict(base)
		return b0
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VARIANTS_PATH))
	var over: Dictionary = all.get(id, {})
	for k: String in over:
		if not k.begins_with("_"):
			base[k] = over[k]
	var b := from_dict(base)
	b.variant = id
	return b


static func from_dict(d: Dictionary) -> Balance:
	var b := Balance.new()
	var w: Dictionary = d["wind"]
	b.energy_per_turn = float(w["energy_per_turn"])
	b.gear_bonus_per_doll = float(w["gear_bonus_per_doll"])
	b.max_turns_per_second = float(w["max_turns_per_second"])
	b.hold_turns_per_second = float(w["hold_turns_per_second"])
	b.hold_delay = float(w["hold_delay"])
	b.awaken_seconds = float(d["awaken_seconds"])
	b.hint_idle_seconds = float(d["hint_idle_seconds"])
	b.idle_report_seconds = float(d["idle_report_seconds"])
	b.autosave_seconds = float(d["autosave_seconds"])
	var rate_scale := float(d.get("dolls_rate_scale", 1.0))
	for doll: Dictionary in d["dolls"]:
		b.costs.append(float(doll["cost"]))
		b.rates.append(float(doll["rate"]) * rate_scale)
		var p: Array = doll["pos"]
		b.positions.append(Vector2(float(p[0]), float(p[1])))
	# A variant may set its own first price without restating every doll.
	if d.has("first_cost") and not b.costs.is_empty():
		b.costs[0] = float(d["first_cost"])
	for s: Dictionary in d["stages"]:
		b.stages.append([int(s["dolls"]), String(s["name"])])
	var sp: Dictionary = d.get("spring", {})
	b.spring_enabled = bool(sp.get("enabled", false))
	b.spring_capacity_of_next_cost = float(sp.get("capacity_of_next_cost", 1.0))
	b.reveal = bool(d.get("reveal", false))
	b.kick_seconds = float(d.get("kick_seconds", 0.0))
	return b


func doll_count() -> int:
	return costs.size()


## Problems with the data, empty when it is usable.
func problems() -> Array[String]:
	var out: Array[String] = []
	if energy_per_turn <= 0.0:
		out.append("energy_per_turn must be positive")
	if hold_turns_per_second > max_turns_per_second:
		out.append("holding may not wind faster than the cap")
	if costs.is_empty():
		out.append("no dolls")
	for i in costs.size():
		if costs[i] <= 0.0 or rates[i] <= 0.0:
			out.append("doll %d: cost and rate must be positive" % i)
		if i > 0 and costs[i] <= costs[i - 1]:
			out.append("doll %d: costs must rise" % i)
	if stages.is_empty() or int(stages[0][0]) != 0:
		out.append("the first stage starts at 0 dolls")
	for i in range(1, stages.size()):
		if int(stages[i][0]) <= int(stages[i - 1][0]):
			out.append("stages must rise")
	return out
