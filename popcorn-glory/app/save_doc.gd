class_name PopSaveDoc
extends RefCounted

## Step 45: the save's envelope, apart from where it is stored (app/save_store.gd)
## and from what a game keeps (each rules' to_save / from_save).
##
## The text is one JSON object whose last key is "rules":
##   {"schema":1,"game":"popcorn-glory","exp":"factory","version":"0.45.0",
##    "active_ms":...,"saved_unix":...,"sum":"<sha256 of the rules text>","rules":{...}}
## The schema stays 1 and every new key is additive, so a 0.12-0.44 build still
## reads a 0.45 save (it ignores "sum" and "saved_unix") -- the Pages CDN can hand a
## returning player an older build for ten minutes after a deploy, and an older
## build that rejects a save starts a fresh run over it.
## "sum" is the sha256 of the exact characters after "rules": -- a truncated or
## edited save is caught before any of it is applied. A save without "sum" (every
## build before 0.45) is read as before.

const SCHEMA := 1
const GAME := "popcorn-glory"
const RULES_KEY := ",\"rules\":"


## The text of a save: header fields, the checksum, the rules text last.
static func encode(exp: String, version: String, active_ms: int, saved_unix: int, rules: Dictionary) -> String:
	var rules_text := JSON.stringify(rules)
	var head := {"schema": SCHEMA, "game": GAME, "exp": exp, "version": version, "active_ms": active_ms,
		"saved_unix": saved_unix, "sum": rules_text.sha256_text()}
	var h := JSON.stringify(head)
	return h.substr(0, h.length() - 1) + RULES_KEY + rules_text + "}"


## Reads a save for `exp`. Answers {"ok": true, "doc": header, "rules": rules dict}
## or {"ok": false, "reason": why}. Nothing here applies anything.
static func decode(text: String, exp: String) -> Dictionary:
	if text.strip_edges() == "":
		return {"ok": false, "reason": "empty"}
	# JSON.parse (not parse_string): a broken save must not print an engine error.
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "not_json"}
	var doc: Dictionary = json.data
	if String(doc.get("game", "")) != GAME:
		return {"ok": false, "reason": "foreign"}
	if String(doc.get("exp", "")) != exp:
		return {"ok": false, "reason": "other_experiment"}
	var schema: Variant = doc.get("schema", -1)
	if not (typeof(schema) in [TYPE_INT, TYPE_FLOAT]) or int(schema) != SCHEMA:
		return {"ok": false, "reason": "newer_schema" if (typeof(schema) in [TYPE_INT, TYPE_FLOAT] and int(schema) > SCHEMA) else "schema"}
	if typeof(doc.get("rules")) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "no_rules"}
	if doc.has("sum"):
		var at := text.find(RULES_KEY)
		var rules_text := text.substr(at + RULES_KEY.length(), text.length() - at - RULES_KEY.length() - 1) if at >= 0 and text.ends_with("}") else ""
		if rules_text == "" or rules_text.sha256_text() != String(doc["sum"]):
			return {"ok": false, "reason": "checksum"}
	var am: Variant = doc.get("active_ms", 0)
	if not (typeof(am) in [TYPE_INT, TYPE_FLOAT]) or float(am) < 0.0 or float(am) > 1e13:
		return {"ok": false, "reason": "clock"}
	var head := doc.duplicate()
	head.erase("rules")
	return {"ok": true, "doc": head, "rules": doc["rules"]}
