class_name ResearchText
extends RefCounted

## Research effects in words, written from the same effect data the
## simulation applies -- the research menu and the building details share
## this, so what a panel says a technology does is what it does.


static func effect_lines(sim: Simulation, node: Dictionary, only_type: String = "") -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in node.get("effects", []):
		if only_type != "" and String(e.get("type", "")) != only_type:
			continue
		var line := effect_line(sim, e)
		if line != "":
			out.append(line)
	return out


static func effect_line(sim: Simulation, e: Dictionary) -> String:
	var t := TranslationServer
	var pct := int(round((1.0 - float(e.get("multiply", 1.0))) * 100.0))
	var type := String(e.get("type", ""))
	match String(e.get("kind", "")):
		"yield":
			return t.translate("effect.yield").format({"stage": t.translate(stage_label(sim, type, "id", String(e["stage"]))),
				"item": t.translate(String(sim.data.item(String(e["item"])).get("name", ""))), "n": int(e["add"])})
		"cooldown":
			return t.translate("effect.cooldown").format({"action": t.translate(stage_label(sim, type, "action", String(e.get("action", "")))), "pct": pct})
		"work":
			return t.translate("effect.work").format({"action": t.translate(stage_label(sim, type, "action", String(e.get("action", "")))), "pct": pct})
		"auto":
			return t.translate("effect.auto").format({"action": t.translate(stage_label(sim, type, "action", String(e.get("action", ""))))})
		"variety":
			var v: Dictionary = sim.data.building_type(type).get("varieties", {}).get(String(e.get("variety", "")), {})
			return t.translate("effect.variety").format({"name": t.translate(String(v.get("name", "")))})
		"recipe":
			var r: Dictionary = {}
			for x: Dictionary in sim.data.table("recipes").get("recipes", []):
				if String(x["id"]) == String(e.get("recipe", "")):
					r = x
			return t.translate("effect.recipe").format({"name": t.translate(String(r.get("name", "")))})
		"batch":
			return t.translate("effect.batch").format({"n": int(e.get("add", 1)) + 1})
		"power_use":
			return t.translate("effect.power_use").format({"kw": BuildingDetailView.amount(float(e.get("draw", 0))), "pct": pct})
		"research_time":
			return t.translate("effect.research_time").format({"pct": pct})
	return ""


static func stage_label(sim: Simulation, type: String, field: String, value: String) -> String:
	for st: Dictionary in sim.data.building_type(type).get("cycle", {}).get("stages", []):
		if String(st.get(field, "")) == value:
			return String(st.get("label", value))
	return value
