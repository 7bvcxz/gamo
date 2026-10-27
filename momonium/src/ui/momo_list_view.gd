class_name MomoListView
extends VBoxContainer

## Every Momo on the island, one row each -- a tab of Status (Step 60). The
## card a selected Momo used to show (Assign, Release, its details) is gone:
## selecting a Momo shows only its Schedule button. What the card said lives
## here: who it is, what it is doing, its skill, its last places, how many
## tiles it works -- and the two settings about the Momo rather than its
## tiles: how it picks its next job on its rounds (tap to try the next way;
## the days before and after the change compared) and whether the manager
## may move it. Its name finds it on the island.
##
## Refreshed often by its frame (every event, four times a second): texts
## change in place; rows are built again only when the Momo come or go, so a
## button under a finger is never freed.

signal find_requested(id: int)

var sim: Simulation
var momos: MomoSystem
var lib: SpriteLibrary
var empty_label: Label
## id -> {"row", "name", "status", "skill", "history", "tiles", "route", "pin", "compare"}
var rows: Dictionary = {}
var _ids: Array[int] = []


func setup(p_sim: Simulation, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	momos = sim.system(&"momo")
	lib = p_lib
	name = "MomoListView"
	add_theme_constant_override("separation", 12)
	empty_label = PanelViews.label("", 16, true)
	empty_label.name = "Empty"
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(empty_label)
	refresh()


func refresh() -> void:
	var ids := momos.ids()
	if ids != _ids:
		_rebuild(ids)
	empty_label.text = tr("momolist.empty")
	empty_label.visible = ids.is_empty()
	for id: int in ids:
		_fill(id, rows[id])


func _rebuild(ids: Array[int]) -> void:
	_ids = ids.duplicate()
	for id: int in rows:
		var r: Control = rows[id]["row"]
		remove_child(r)
		r.queue_free()
	rows.clear()
	for id: int in ids:
		rows[id] = _row(id)
		add_child(rows[id]["row"])


func _row(id: int) -> Dictionary:
	var row := PanelContainer.new()
	row.name = "Momo_%d" % id
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var face := PanelViews.icon(lib, "momo_front", 48.0)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_button := Button.new()
	name_button.name = "Find"
	name_button.flat = true
	name_button.focus_mode = Control.FOCUS_NONE
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.custom_minimum_size = Vector2(0, 44)
	name_button.add_theme_font_size_override("font_size", 20)
	name_button.pressed.connect(func() -> void: find_requested.emit(id))
	col.add_child(name_button)
	var status := PanelViews.label("", 15, true)
	status.name = "Status"
	col.add_child(status)
	var skill := PanelViews.label("", 14)
	skill.name = "Skill"
	skill.theme_type_variation = &"GoldLabel"
	col.add_child(skill)
	var history := PanelViews.label("", 13, true)
	history.name = "History"
	history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(history)
	top.add_child(col)
	var tiles := PanelViews.label("", 15)
	tiles.name = "Tiles"
	tiles.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(tiles)
	outer.add_child(top)
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 8)
	var route := _setting("Route")
	route.pressed.connect(func() -> void:
		next_route(id)
		refresh())
	settings.add_child(route)
	var pin := _setting("Pin")
	pin.pressed.connect(func() -> void:
		var m := momos.get_momo(id)
		if not m.is_empty():
			sim.execute({"type": "momo.pin", "momo": id, "pinned": not bool(m.get("pinned", false))})
			refresh())
	settings.add_child(pin)
	outer.add_child(settings)
	var compare := PanelViews.label("", 13, true)
	compare.name = "Compare"
	outer.add_child(compare)
	row.add_child(outer)
	return {"row": row, "name": name_button, "status": status, "skill": skill, "history": history, "tiles": tiles,
		"route": route, "pin": pin, "compare": compare}


func _setting(node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 15)
	return b


## The next routing way this island has (wrapping round).
func next_route(id: int) -> void:
	var open := momos.routes_open()
	var i := open.find(momos.route_of(id))
	sim.execute({"type": "momo.route", "momo": id, "route": open[(i + 1) % open.size()]})


func _fill(id: int, r: Dictionary) -> void:
	var m := momos.get_momo(id)
	if m.is_empty():
		return
	var b := int(m["assigned"])
	var watch: Array = m.get("watch", [])
	(r["name"] as Button).text = tr(m["name"]) + "  ›"
	(r["name"] as Button).accessibility_name = tr("momolist.find") % tr(m["name"])
	(r["status"] as Label).text = status_text(id)
	(r["tiles"] as Label).text = tr("watch.count") % [watch.size(), momos.watch_capacity(id)]
	var skill := skill_text(m, b)
	(r["skill"] as Label).text = skill
	(r["skill"] as Label).visible = skill != ""
	var history := history_text(id, m)
	(r["history"] as Label).text = history
	(r["history"] as Label).visible = history != ""
	var route := r["route"] as Button
	route.text = tr("route.label") % tr("route." + momos.route_of(id))
	route.visible = not watch.is_empty()
	var pin := r["pin"] as Button
	pin.visible = b != 0
	pin.text = tr("momo.pinned") if bool(m.get("pinned", false)) else tr("momo.free_to_move")
	var compare := r["compare"] as Label
	compare.visible = false
	if route.visible and int(m.get("route_since", 0)) > 0:
		var ba := (sim.system(&"analytics") as AnalyticsSystem).momo_before_after(id, int(m["route_since"]))
		# Nothing to compare yet: say nothing (Step 50: "a few days are needed
		# on each side" meant nothing to any blind player).
		if int(ba["days_before"]) > 0 and int(ba["days_after"]) > 0:
			compare.text = tr("route.compare").format({"before": AnalyticsView.n(ba["before"]), "after": AnalyticsView.n(ba["after"])})
			compare.visible = true


## What it is doing, in a few words.
func status_text(id: int) -> String:
	var m := momos.get_momo(id)
	var b := int(m["assigned"])
	var bs: BuildingSystem = sim.system(&"buildings")
	if b != 0 and momos.is_moving(id):
		return tr("momo.heading_to") % tr(bs.type_def(bs.get_building(b)).get("name", ""))
	if b != 0:
		return tr("momo.working_at") % tr(bs.type_def(bs.get_building(b)).get("name", ""))
	if not (m.get("watch", []) as Array).is_empty():
		# Between jobs on its rounds: it is not idle, it waits for a crop.
		return tr("momo.on_rounds")
	return tr("momo.roaming")


## Its skill where it works (or its best), and how many jobs it has done there.
func skill_text(m: Dictionary, building: int) -> String:
	var bs: BuildingSystem = sim.system(&"buildings")
	var exp: Dictionary = m.get("experience", {})
	var type := String(bs.get_building(building).get("type", "")) if building != 0 else ""
	if type == "":
		for t: String in exp:
			if type == "" or int(exp[t]) > int(exp[type]):
				type = t
	if type == "":
		return ""
	var mastery_key := "mastery." + type
	var tname := tr(mastery_key) if tr(mastery_key) != mastery_key else tr(String(sim.data.building_type(type).get("name", type)))
	return "%s · %s" % [tr("momo.skill").format({"type": tname, "n": momos.proficiency(int(m["id"]), type)}),
		tr("momo.done").format({"n": int(exp.get(type, 0))})]


## Where it lives (once there are homes), and its last places.
func history_text(id: int, m: Dictionary) -> String:
	var bs: BuildingSystem = sim.system(&"buildings")
	var past: Array[String] = []
	var hist: Array = m.get("history", [])
	for i in range(hist.size() - 1, -1, -1):
		var h: Dictionary = hist[i]
		if int(h["to"]) < 0:
			continue
		past.append(tr(String(sim.data.building_type(String(h["type"])).get("name", h["type"]))))
		if past.size() >= 3:
			break
	var parts: Array[String] = []
	var community: CommunitySystem = sim.system(&"community")
	if community != null and community.capacity() > 0:
		var home := community.home_of(id)
		parts.append(tr("momo.home").format({"name": tr(String(bs.type_def(bs.get_building(home)).get("name", "")))}) if home != 0 else tr("momo.no_home"))
	if not past.is_empty():
		parts.append(tr("momo.history").format({"list": " · ".join(past)}))
	return "  ·  ".join(parts)
