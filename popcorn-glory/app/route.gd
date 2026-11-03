class_name PopRoute
extends RefCounted

## Which experiment and which options, from the address
## (`…/popcorn-glory/?dev=1#stub`) or, off the web, from the command line
## (`godot --path popcorn-glory -- --exp stub --dev`).

static func parse(hash: String, search: String, args: PackedStringArray) -> Dictionary:
	var out := {"exp": "", "dev": false, "sound": true, "motion": ""}
	var h := hash.trim_prefix("#").strip_edges()
	if h != "":
		out["exp"] = h.uri_decode()
	for pair: String in search.trim_prefix("?").split("&", false):
		var kv := pair.split("=", true, 1)
		var k: String = kv[0]
		var v: String = kv[1].uri_decode() if kv.size() > 1 else "1"
		match k:
			"dev":
				out["dev"] = v != "0"
			"sound":
				out["sound"] = v != "off" and v != "0"
			"motion":
				out["motion"] = v
	var i := 0
	while i < args.size():
		match args[i]:
			"--exp":
				if i + 1 < args.size():
					out["exp"] = args[i + 1]
					i += 1
			"--dev":
				out["dev"] = true
			"--mute":
				out["sound"] = false
		i += 1
	return out
