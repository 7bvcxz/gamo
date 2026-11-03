class_name LabRoute
extends RefCounted

## Which screen the address asks for. The Lab's address alone is the launcher;
## `#<id>` is one experiment's direct link (`#island`, `#rock`...), which a
## reload keeps. The query adds options that survive moving between screens:
##   ?dev=1           the frame shows the play clock and the run report
##   ?motion=reduce   reduced motion even if the system does not ask for it
##   ?sound=off       start muted
##   ?alt=<name>      one of a track's experiment-only alternatives (Steps
##                    96 and 98); the experiment decides what it means, an
##                    unknown name is its default
## `?exp=<id>` is accepted as a direct link too. Off the web the same options
## come from the command line: `-- --exp island --dev --motion reduce --alt x`.


static func parse(hash: String, search: String, args: PackedStringArray = PackedStringArray()) -> Dictionary:
	var out := {"exp": "", "unknown": "", "dev": false, "motion": "", "sound": true, "alt": ""}
	var want := hash.trim_prefix("#").trim_prefix("/").strip_edges().to_lower()
	var q := _query(search)
	if want == "" and q.has("exp"):
		want = String(q["exp"]).to_lower()
	out["dev"] = q.has("dev") and String(q["dev"]) not in ["0", "false", "no"]
	out["motion"] = String(q.get("motion", ""))
	out["sound"] = String(q.get("sound", "on")) != "off"
	out["alt"] = String(q.get("alt", "")).to_lower()
	var i := 0
	while i < args.size():
		var a := args[i]
		var v := args[i + 1] if i + 1 < args.size() and not args[i + 1].begins_with("--") else ""
		match a:
			"--exp":
				want = v.to_lower()
			"--dev":
				out["dev"] = true
			"--motion":
				out["motion"] = v
			"--mute":
				out["sound"] = false
			"--alt":
				out["alt"] = v.to_lower()
		i += 2 if v != "" else 1
	if want != "":
		if LabRegistry.routable(want):
			out["exp"] = want
		else:
			out["unknown"] = want
	return out


static func _query(search: String) -> Dictionary:
	var out := {}
	for pair: String in search.trim_prefix("?").split("&", false):
		var kv := pair.split("=", true, 1)
		out[kv[0].uri_decode()] = kv[1].uri_decode() if kv.size() > 1 else "1"
	return out
