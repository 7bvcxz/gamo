class_name MomoPanel
extends PanelContainer

## The small card for a selected Momo: face, name, what it is doing, and the
## buttons that do without dragging what a drag does -- Assign (then tap a
## building) and Release. Accessible for anyone who cannot or would rather not
## drag.

signal assign_requested(momo: int)
signal release_requested(momo: int)

var sim: Simulation
var momos: MomoSystem
var momo_id := 0
var name_label: Label
var status_label: Label
var assign_button: Button
var release_button: Button
var assigning := false
var skill_label: Label
var history_label: Label
## Keeps a Momo where the player put it, or lets the manager move it.
var pin_button: Button
## How it picks its next job (tap to try the next way), and how the days
## before and after the last change compare.
var route_button: Button
var compare_label: Label


func setup(p_sim: Simulation, lib: SpriteLibrary) -> void:
	sim = p_sim
	momos = sim.system(&"momo")
	name = "MomoPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var face := TextureRect.new()
	face.texture = lib.atlas_texture("momo_front")
	face.custom_minimum_size = Vector2(64, 64)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 22)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.modulate = Color(1, 1, 1, 0.85)
	col.add_child(name_label)
	col.add_child(status_label)
	skill_label = Label.new()
	skill_label.name = "Skill"
	skill_label.add_theme_font_size_override("font_size", 14)
	skill_label.modulate = Color(1, 0.93, 0.6)
	col.add_child(skill_label)
	history_label = Label.new()
	history_label.name = "History"
	history_label.add_theme_font_size_override("font_size", 13)
	history_label.modulate = Color(1, 1, 1, 0.65)
	col.add_child(history_label)
	pin_button = Button.new()
	pin_button.name = "Pin"
	pin_button.flat = true
	pin_button.focus_mode = Control.FOCUS_NONE
	pin_button.custom_minimum_size = Vector2(0, 44)
	pin_button.add_theme_font_size_override("font_size", 15)
	pin_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pin_button.pressed.connect(func() -> void:
		var m := momos.get_momo(momo_id)
		if not m.is_empty():
			sim.execute({"type": "momo.pin", "momo": momo_id, "pinned": not bool(m.get("pinned", false))})
			refresh())
	col.add_child(pin_button)
	route_button = Button.new()
	route_button.name = "Route"
	route_button.flat = true
	route_button.focus_mode = Control.FOCUS_NONE
	route_button.custom_minimum_size = Vector2(0, 44)
	route_button.add_theme_font_size_override("font_size", 15)
	route_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	route_button.pressed.connect(next_route)
	col.add_child(route_button)
	compare_label = PanelViews.label("", 13, true)
	compare_label.name = "Compare"
	col.add_child(compare_label)
	row.add_child(col)
	assign_button = _button("Assign")
	assign_button.pressed.connect(func() -> void:
		assigning = not assigning
		assign_requested.emit(momo_id)
		refresh())
	row.add_child(assign_button)
	release_button = _button("Release")
	release_button.pressed.connect(func() -> void: release_requested.emit(momo_id))
	row.add_child(release_button)
	add_child(row)
	visible = false


func _button(node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(110, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	return b


## The next routing way this island has (wrapping round).
func next_route() -> void:
	var open := momos.routes_open()
	var i := open.find(momos.route_of(momo_id))
	sim.execute({"type": "momo.route", "momo": momo_id, "route": open[(i + 1) % open.size()]})
	refresh()


func show_momo(id: int) -> void:
	momo_id = id
	assigning = false
	visible = true
	refresh()


## A short line in place of the status for a moment (why something was refused).
func say(line: String) -> void:
	_said = line
	_said_until = Time.get_ticks_msec() + 2500
	refresh()


var _said := ""
var _said_until := 0


func hide_panel() -> void:
	visible = false
	assigning = false
	momo_id = 0


func _process(_delta: float) -> void:
	if visible:
		refresh()


func refresh() -> void:
	var m := momos.get_momo(momo_id)
	if m.is_empty():
		hide_panel()
		return
	name_label.text = tr(m["name"])
	var b := int(m["assigned"])
	var buildings: BuildingSystem = sim.system(&"buildings")
	if _said != "" and Time.get_ticks_msec() < _said_until:
		status_label.text = _said
	elif assigning:
		# What Assign waits for (Step 50: blind players tapped it and saw nothing).
		status_label.text = tr("momo.assign_hint")
	elif b != 0 and momos.is_moving(momo_id):
		status_label.text = tr("momo.heading_to") % tr(buildings.type_def(buildings.get_building(b)).get("name", ""))
	elif b != 0:
		status_label.text = tr("momo.working_at") % tr(buildings.type_def(buildings.get_building(b)).get("name", ""))
	elif not (m.get("watch", []) as Array).is_empty():
		# Between jobs on its rounds: it is not idle, it waits for a crop.
		status_label.text = tr("momo.on_rounds")
	else:
		status_label.text = tr("momo.roaming")
	assign_button.text = tr("momo.assign")
	assign_button.modulate = Color(1.3, 1.25, 0.8) if assigning else Color.WHITE
	release_button.text = tr("momo.unassign")
	release_button.visible = b != 0
	route_button.text = tr("route.label") % tr("route." + momos.route_of(momo_id))
	route_button.visible = not (m.get("watch", []) as Array).is_empty()
	compare_label.visible = route_button.visible and int(m.get("route_since", 0)) > 0
	if compare_label.visible:
		var ba := (sim.system(&"analytics") as AnalyticsSystem).momo_before_after(momo_id, int(m["route_since"]))
		if int(ba["days_before"]) > 0 and int(ba["days_after"]) > 0:
			compare_label.text = tr("route.compare").format({"before": AnalyticsView.n(ba["before"]), "after": AnalyticsView.n(ba["after"])})
		else:
			# Nothing to compare yet: say nothing (Step 50: "a few days are
			# needed on each side" meant nothing to any blind player).
			compare_label.visible = false
	_refresh_skill(m, b)


## The Momo's skill where it works (or its best), its last places, and
## whether the manager may move it.
func _refresh_skill(m: Dictionary, building: int) -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var exp: Dictionary = m.get("experience", {})
	var type := String(buildings.get_building(building).get("type", "")) if building != 0 else ""
	if type == "":
		for t: String in exp:
			if type == "" or int(exp[t]) > int(exp[type]):
				type = t
	skill_label.visible = type != ""
	if type != "":
		var mastery_key := "mastery." + type
		var tname := tr(mastery_key) if tr(mastery_key) != mastery_key else tr(String(sim.data.building_type(type).get("name", type)))
		skill_label.text = "%s · %s" % [tr("momo.skill").format({"type": tname, "n": momos.proficiency(momo_id, type)}),
			tr("momo.done").format({"n": int(exp.get(type, 0))})]
	var past: Array[String] = []
	var hist: Array = m.get("history", [])
	for i in range(hist.size() - 1, -1, -1):
		var h: Dictionary = hist[i]
		if int(h["to"]) < 0:
			continue
		past.append(tr(String(sim.data.building_type(String(h["type"])).get("name", h["type"]))))
		if past.size() >= 3:
			break
	history_label.visible = not past.is_empty()
	history_label.text = tr("momo.history").format({"list": " · ".join(past)})
	var community: CommunitySystem = sim.system(&"community")
	if community != null and community.capacity() > 0:
		var home := community.home_of(momo_id)
		var line := tr("momo.home").format({"name": tr(String(buildings.type_def(buildings.get_building(home)).get("name", "")))}) if home != 0 else tr("momo.no_home")
		history_label.text = line + ("  ·  " + history_label.text if history_label.visible else "")
		history_label.visible = true
	pin_button.visible = building != 0
	pin_button.text = tr("momo.pinned") if bool(m.get("pinned", false)) else tr("momo.free_to_move")
