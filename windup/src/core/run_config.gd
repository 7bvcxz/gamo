class_name RunConfig
extends RefCounted

## How this run was asked to start: from the page's address on the web
## (`?fresh=1&seed=3&variant=a&dev=1`), from user arguments natively
## (`godot --path windup -- --fresh --seed 3 --variant a --dev`).
##
## Read once at boot. Everything that changes how a run starts goes through
## here, so a test can build the same run from a dictionary.

const DEFAULT_SEED := 1
const VARIANTS: Array[String] = ["base", "a", "b", "c"]

var fresh: bool = false
var seed: int = DEFAULT_SEED
var variant: String = "base"
var dev: bool = false
## Headless smoke run: play a few scripted presses, print a summary, quit.
var smoke: bool = false


static func from_pairs(pairs: Dictionary) -> RunConfig:
	var c := RunConfig.new()
	c.fresh = _truthy(pairs.get("fresh", ""))
	c.dev = _truthy(pairs.get("dev", ""))
	c.smoke = _truthy(pairs.get("smoke", ""))
	var s: String = str(pairs.get("seed", ""))
	if s.is_valid_int():
		c.seed = int(s)
	var v: String = str(pairs.get("variant", "base")).to_lower()
	c.variant = v if VARIANTS.has(v) else "base"
	return c


## `a=1&b` -> {"a": "1", "b": "true"}.
static func parse_query(query: String) -> Dictionary:
	var out := {}
	for part: String in query.trim_prefix("?").split("&", false):
		var kv := part.split("=", true, 1)
		var key := kv[0].uri_decode()
		out[key] = kv[1].uri_decode() if kv.size() > 1 else "true"
	return out


## `--seed 3 --fresh` -> {"seed": "3", "fresh": "true"}.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < args.size():
		var a: String = args[i]
		if a.begins_with("--"):
			var key := a.trim_prefix("--")
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				out[key] = args[i + 1]
				i += 2
				continue
			out[key] = "true"
		i += 1
	return out


static func from_environment() -> RunConfig:
	if OS.has_feature("web"):
		return from_pairs(parse_query(WindupWeb.query_string()))
	return from_pairs(parse_args(OS.get_cmdline_user_args()))


func to_dict() -> Dictionary:
	return {"fresh": fresh, "seed": seed, "variant": variant, "dev": dev, "smoke": smoke}


static func _truthy(v: Variant) -> bool:
	var s := str(v).to_lower()
	return s in ["1", "true", "yes", "on"]
