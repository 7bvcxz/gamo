class_name BuildingDetailView
extends VBoxContainer

## Everything about one building: what it is doing now (with the time left or
## the wait to the next step), who works it (one place per worker spot, empty
## ones shown as empty), what a full cycle takes and gives by hand and by a
## Momo, and how many jobs it has done. The cycle figures come from the
## building system's own estimate, so they cannot drift from the simulation.

## The building is no longer there (construction cancelled): nothing to show.
signal gone

var sim: Simulation
var lib: SpriteLibrary
var building_id := 0
var icon: TextureRect
var state_label: Label
var progress: Bar
var workers_box: HBoxContainer
var cycle_you: HBoxContainer
var cycle_momo: HBoxContainer
var yield_row: HBoxContainer
var done_row: HBoxContainer
## What this building grows (farms): one choice per variety.
var variety_box: HBoxContainer
var variety_hint: Label
## Finished research acting on this building, in words.
var research_box: VBoxContainer
## What a processing building makes: one choice per recipe; what the next
## batch takes (have / need) and, when it cannot start, why.
var recipe_box: HBoxContainer
var takes_row: HBoxContainer
var block_label: Label
var power_row: HBoxContainer
## How much the manager should want workers here (shown once management exists).
var priority_box: HBoxContainer
var manager_label: Label
var _shown_recipes := ""
var last_result: Dictionary = {}
var _shown_varieties := ""


func setup(p_sim: Simulation, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	lib = p_lib
	name = "BuildingDetailView"
	add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	icon = PanelViews.icon(lib, "ui_sprout", 56.0)
	head.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label = PanelViews.label("", 20)
	state_label.name = "State"
	col.add_child(state_label)
	progress = Bar.new(Color("#9be15d"))
	progress.name = "Progress"
	progress.custom_minimum_size = Vector2(0, 10)
	col.add_child(progress)
	head.add_child(col)
	add_child(head)
	workers_box = HBoxContainer.new()
	workers_box.name = "Workers"
	workers_box.add_theme_constant_override("separation", 10)
	add_child(workers_box)
	yield_row = PanelViews.row("", "")
	yield_row.name = "Yield"
	add_child(yield_row)
	cycle_you = PanelViews.row("", "")
	cycle_you.name = "CycleYou"
	add_child(cycle_you)
	cycle_momo = PanelViews.row("", "")
	cycle_momo.name = "CycleMomo"
	add_child(cycle_momo)
	done_row = PanelViews.row("", "")
	done_row.name = "Done"
	add_child(done_row)
	variety_box = HBoxContainer.new()
	variety_box.name = "Varieties"
	variety_box.add_theme_constant_override("separation", 8)
	add_child(variety_box)
	variety_hint = PanelViews.label("", 15, true)
	variety_hint.name = "VarietyHint"
	add_child(variety_hint)
	recipe_box = HBoxContainer.new()
	recipe_box.name = "Recipes"
	recipe_box.add_theme_constant_override("separation", 8)
	add_child(recipe_box)
	takes_row = PanelViews.row("", "")
	takes_row.name = "Takes"
	add_child(takes_row)
	block_label = PanelViews.label("", 16)
	block_label.name = "Blocked"
	block_label.add_theme_color_override("font_color", Color("#ffb3a8"))
	block_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(block_label)
	power_row = PanelViews.row("", "")
	power_row.name = "Power"
	add_child(power_row)
	priority_box = HBoxContainer.new()
	priority_box.name = "Priority"
	priority_box.add_theme_constant_override("separation", 6)
	var ptitle := PanelViews.label("", 15, true)
	ptitle.name = "Title"
	priority_box.add_child(ptitle)
	for p: String in ManagerSystem.PRIORITIES:
		var pb := Button.new()
		pb.name = "P_" + p
		pb.custom_minimum_size = Vector2(0, 48)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.focus_mode = Control.FOCUS_NONE
		pb.add_theme_font_size_override("font_size", 15)
		pb.pressed.connect(func() -> void:
			last_result = sim.execute({"type": "building.priority", "id": building_id, "priority": p})
			refresh())
		priority_box.add_child(pb)
	add_child(priority_box)
	manager_label = PanelViews.label("", 16)
	manager_label.name = "Manager"
	manager_label.add_theme_color_override("font_color", Color("#ffe27a"))
	add_child(manager_label)
	research_box = VBoxContainer.new()
	research_box.name = "Research"
	add_child(research_box)


func show_building(id: int) -> void:
	building_id = id
	PanelViews.clear(workers_box)
	_shown_varieties = ""
	_shown_recipes = ""
	refresh()


## 1 -> "1", 0.25 -> "0.25", 0.2 -> "0.2": a rate as people write it.
static func amount(x: float) -> String:
	if is_equal_approx(x, round(x)):
		return str(int(round(x)))
	return String.num(x, 3).rstrip("0").rstrip(".")


static func duration(seconds: float) -> String:
	var s := int(round(seconds))
	if s < 60:
		return TranslationServer.translate("time.s").format({"s": s})
	if s % 60 == 0:
		return TranslationServer.translate("time.m").format({"m": s / 60})
	return TranslationServer.translate("time.ms").format({"m": s / 60, "s": s % 60})


func state_text(b: Dictionary) -> String:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var left := ceili(buildings.remaining_ms(b) / 1000.0)
	var stage_name := tr(String(buildings.current_stage(b).get("label", "")))
	match String(b["state"]):
		BuildingSystem.CONSTRUCTING:
			return tr("detail.building").format({"s": left})
		BuildingSystem.WORKING:
			return tr("detail.working").format({"stage": stage_name, "s": left})
		BuildingSystem.COOLDOWN:
			return tr("detail.waiting").format({"stage": stage_name, "s": left})
	return tr("detail.next").format({"stage": stage_name})


func refresh() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	var b := buildings.get_building(building_id)
	if b.is_empty():
		if building_id != 0:
			building_id = 0
			gone.emit()
		return
	var def := buildings.type_def(b)
	icon.texture = lib.atlas_texture(String(def.get("icon", "ui_sprout")) if lib.has(String(def.get("icon", ""))) else "ui_sprout")
	state_label.text = state_text(b)
	progress.value = buildings.progress(b) if b["state"] in [BuildingSystem.WORKING, BuildingSystem.CONSTRUCTING] else 0.0
	progress.visible = b["state"] in [BuildingSystem.WORKING, BuildingSystem.CONSTRUCTING]
	_refresh_workers(b, momos)
	var you := buildings.cycle_estimate(b, 1.0)
	var mult := sim.data.get_float("balance", "momo.work_time_multiplier", 4.0)
	var by_momo := buildings.cycle_estimate(b, mult)
	var gives: Array[String] = []
	for item: String in you["yield"]:
		gives.append("%s %s" % [tr(String(sim.data.item(item).get("name", item))), amount(float(you["yield"][item]))])
	_set_row(yield_row, tr("detail.cycle"), ", ".join(gives))
	_set_row(cycle_you, tr("detail.by_you"), duration(you["cycle_seconds"]))
	_set_row(cycle_momo, tr("detail.by_momo"), duration(by_momo["cycle_seconds"]))
	_set_row(done_row, tr("panel.records.tasks"), str(int(b.get("completed", 0))))
	_refresh_varieties(b, buildings)
	_refresh_recipes(b, buildings)
	_refresh_power(b)
	_refresh_management(b, buildings)
	_refresh_research(b)


func _set_row(row: HBoxContainer, key: String, value: String) -> void:
	(row.get_child(0) as Label).text = key
	(row.get_node("Value") as Label).text = value


## The varieties this building can grow, each with what it asks and gives:
## waterings, crops a harvest, a cycle by hand. Tapping one sets it (between
## cycles only -- the simulation says no otherwise, and the hint says why).
func _refresh_varieties(b: Dictionary, buildings: BuildingSystem) -> void:
	var type := String(b["type"])
	var list := buildings.varieties(type)
	variety_box.visible = list.size() > 1
	variety_hint.visible = false
	if list.size() <= 1:
		return
	var key := ""
	for v: String in list:
		key += "%s:%s:%s;" % [v, buildings.variety_unlocked(type, v), buildings.variety_of(b) == v]
	key += TranslationServer.get_locale()
	if key != _shown_varieties:
		_shown_varieties = key
		PanelViews.clear(variety_box)
		for v: String in list:
			variety_box.add_child(_variety_button(b, buildings, v))
	var between: bool = b["state"] == BuildingSystem.IDLE and int(b["stage"]) == 0
	if not between:
		variety_hint.text = tr("err.variety_busy")
		variety_hint.visible = true
	for c: Node in variety_box.get_children():
		var open: bool = buildings.variety_unlocked(type, String(c.get_meta("variety")))
		(c as Button).disabled = not open or (not between and buildings.variety_of(b) != String(c.get_meta("variety")))


func _variety_button(b: Dictionary, buildings: BuildingSystem, v: String) -> Button:
	var type := String(b["type"])
	var def := buildings.variety_def(type, v)
	var btn := Button.new()
	btn.name = "Variety_" + v
	btn.set_meta("variety", v)
	btn.custom_minimum_size = Vector2(0, 92)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	var id := int(b["id"])
	btn.pressed.connect(func() -> void:
		last_result = sim.execute({"type": "building.variety", "id": id, "variety": v})
		refresh())
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := PanelViews.icon(lib, String(def.get("icon", "ui_sprout")), 30.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var n := PanelViews.label(tr(String(def.get("name", v))), 16)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(n)
	var probe := b.duplicate()
	probe["variety"] = v
	var waterings := buildings.stages(probe).filter(func(st: Dictionary) -> bool: return st.get("action", "") == "water").size()
	var crops := 0
	for item: String in buildings.cycle_estimate(probe)["yield"]:
		crops += int(round(float(buildings.cycle_estimate(probe)["yield"][item])))
	var facts := PanelViews.label(tr("detail.variety_facts").format({"w": waterings, "c": crops}), 13, true)
	facts.name = "Facts"
	facts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(facts)
	btn.add_child(col)
	var chosen := buildings.variety_of(b) == v
	var open := buildings.variety_unlocked(type, v)
	btn.draw.connect(func() -> void:
		if chosen:
			btn.draw_rect(Rect2(Vector2.ONE * 2, btn.size - Vector2.ONE * 4), Color("#ffe27a"), false, 3.0)
		if not open:
			var c := Vector2(btn.size.x - 14, 14)
			btn.draw_circle(c, 11.0, Color(0.1, 0.18, 0.3, 0.85))
			btn.draw_arc(c + Vector2(0, -2), 4.0, PI, TAU, 10, Color.WHITE, 2.0, true)
			btn.draw_rect(Rect2(c + Vector2(-5, -2), Vector2(10, 8)), Color.WHITE))
	return btn


## "Copper ore 1/2 · Wood 3/1": each item with what the store holds and what is needed.
func items_line(items: Dictionary, with_have: bool) -> String:
	var inv: InventorySystem = sim.system(&"inventory")
	var parts: Array[String] = []
	for item: String in items:
		var name_ := tr(String(sim.data.item(item).get("name", item)))
		parts.append("%s %d/%d" % [name_, inv.count(item), int(items[item])] if with_have else "%s %d" % [name_, int(items[item])])
	return " · ".join(parts)


func _refresh_recipes(b: Dictionary, buildings: BuildingSystem) -> void:
	var type := String(b["type"])
	var list := buildings.recipes(type)
	recipe_box.visible = not list.is_empty()
	var stage := buildings.current_stage(b)
	var consumes: Dictionary = stage.get("consumes", {})
	takes_row.visible = not consumes.is_empty()
	if not consumes.is_empty():
		_set_row(takes_row, tr("detail.takes"), items_line(consumes, true))
	var block := buildings.blocked(b)
	block_label.visible = not block.is_empty()
	if block.has("missing"):
		block_label.text = tr("detail.short").format({"items": items_line(block["missing"], false)})
	elif block.has("full"):
		block_label.text = tr("detail.full").format({"items": items_line(block["full"], false)})
	if list.is_empty():
		return
	var key := ""
	for r: String in list:
		key += "%s:%s:%s;" % [r, buildings.recipe_unlocked(type, r), buildings.recipe_of(b) == r]
	key += "%d%s" % [buildings.batch_of(b), TranslationServer.get_locale()]
	if key != _shown_recipes:
		_shown_recipes = key
		PanelViews.clear(recipe_box)
		for r: String in list:
			recipe_box.add_child(_recipe_button(b, buildings, r))
	for c: Node in recipe_box.get_children():
		var r := String(c.get_meta("recipe"))
		var open: bool = buildings.recipe_unlocked(type, r)
		(c as Button).disabled = not open or (b["state"] != BuildingSystem.IDLE and buildings.recipe_of(b) != r)


func _recipe_button(b: Dictionary, buildings: BuildingSystem, r: String) -> Button:
	var type := String(b["type"])
	var def := buildings.recipe_def(r)
	var btn := Button.new()
	btn.name = "Recipe_" + r
	btn.set_meta("recipe", r)
	btn.custom_minimum_size = Vector2(0, 96)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	var id := int(b["id"])
	btn.pressed.connect(func() -> void:
		last_result = sim.execute({"type": "building.recipe", "id": id, "recipe": r})
		refresh())
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := PanelViews.icon(lib, String(def.get("icon", "ui_sprout")), 30.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var n := PanelViews.label(tr(String(def.get("name", r))), 15)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(n)
	var facts := PanelViews.label(items_line(def.get("inputs", {}), false), 12, true)
	facts.name = "Facts"
	facts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(facts)
	btn.add_child(col)
	var chosen := buildings.recipe_of(b) == r
	var open := buildings.recipe_unlocked(type, r)
	btn.draw.connect(func() -> void:
		if chosen:
			btn.draw_rect(Rect2(Vector2.ONE * 2, btn.size - Vector2.ONE * 4), Color("#ffe27a"), false, 3.0)
		if not open:
			var c := Vector2(btn.size.x - 14, 14)
			btn.draw_circle(c, 11.0, Color(0.1, 0.18, 0.3, 0.85))
			btn.draw_arc(c + Vector2(0, -2), 4.0, PI, TAU, 10, Color.WHITE, 2.0, true)
			btn.draw_rect(Rect2(c + Vector2(-5, -2), Vector2(10, 8)), Color.WHITE))
	return btn


## Priority buttons once the island can have a manager (the research is
## done); and, on an office, who manages and how many moves it has made.
func _refresh_management(b: Dictionary, buildings: BuildingSystem) -> void:
	var research: ResearchSystem = sim.system(&"research")
	var manager: ManagerSystem = sim.system(&"manager")
	var managed := research != null and research.is_done("management")
	var is_office := bool(buildings.type_def(b).get("manages", false))
	priority_box.visible = managed and not is_office and not buildings.stages(b).is_empty()
	if priority_box.visible:
		(priority_box.get_node("Title") as Label).text = tr("priority.title")
		var current := String(b.get("priority", "normal"))
		for p: String in ManagerSystem.PRIORITIES:
			var pb: Button = priority_box.get_node("P_" + p)
			pb.text = tr("priority." + p)
			pb.modulate = Color(1.3, 1.25, 0.8) if p == current else Color(1, 1, 1, 0.75)
	manager_label.visible = is_office
	if is_office and manager != null:
		manager_label.text = tr("manager.status").format({"n": manager.moves_made}) if manager.manager() != 0 else tr("manager.none")


## A generator: what it gives now of its most. A powered building: what it
## draws and the share it got.
func _refresh_power(b: Dictionary) -> void:
	var power: PowerSystem = sim.system(&"power")
	power_row.visible = false
	if power == null:
		return
	var type := String(b["type"])
	if power.is_generator(type):
		power_row.visible = true
		_set_row(power_row, tr("power.supply"), tr("detail.power_gen").format({
			"kw": amount(snappedf(power.output_of(int(b["id"]), sim.now_ms()), 0.1)), "max": amount(float(power.generator_def(type).get("kw", 0)))}))
		return
	var use := power.use_of(type)
	if not use.is_empty():
		power_row.visible = true
		var share := float(power.shares.get(int(b["id"]), power.satisfaction(type)))
		_set_row(power_row, tr("power.demand"), tr("detail.power_use").format({"kw": amount(float(use["draw"])), "pct": int(round(share * 100.0))}))


## Finished research that acts on this building type, in the research menu's words.
func _refresh_research(b: Dictionary) -> void:
	var research: ResearchSystem = sim.system(&"research")
	var lines: Array[String] = []
	if research != null:
		for id: String in research.completed:
			for line: String in ResearchText.effect_lines(sim, research.node(id), String(b["type"])):
				lines.append("%s · %s" % [tr(String(research.node(id).get("name", ""))), line])
	var key := "|".join(lines)
	if research_box.get_meta("key", "") == key:
		return
	research_box.set_meta("key", key)
	PanelViews.clear(research_box)
	if lines.is_empty():
		return
	research_box.add_child(PanelViews.label(tr("detail.research"), 15, true))
	for line: String in lines:
		var l := PanelViews.label(line, 15)
		l.add_theme_color_override("font_color", Color("#b7f08a"))
		research_box.add_child(l)


## One chip per worker spot: the Momo there and what it is doing, or an
## empty place. While the player is doing the current stage a "you" chip
## shows first.
func _refresh_workers(b: Dictionary, momos: MomoSystem) -> void:
	var slots := momos.slots_of(building_id)
	var ids := momos.workers_at(building_id)
	var want: Array[String] = []
	if b["state"] == BuildingSystem.WORKING and int(b.get("worker", 0)) == 0:
		want.append("you")
	elif b["state"] == BuildingSystem.WORKING and int(b.get("worker", 0)) == JobSystem.AUTO_WORKER:
		want.append("auto")
	for i in slots:
		want.append("momo:%d" % ids[i] if i < ids.size() else "empty")
	var have: Array[String] = []
	for c: Node in workers_box.get_children():
		if not c.is_queued_for_deletion():
			have.append(String(c.get_meta("who", "")))
	if have != want:
		PanelViews.clear(workers_box)
		for who: String in want:
			workers_box.add_child(_chip(who))
	for c: Node in workers_box.get_children():
		var who := String(c.get_meta("who", ""))
		var status := c.find_child("Status", true, false) as Label
		if status == null:
			continue
		if who == "you" or who == "auto":
			status.text = tr("detail.momo_working")
		elif who.begins_with("momo:"):
			var id := int(who.trim_prefix("momo:"))
			if int(b.get("worker", 0)) == id and b["state"] == BuildingSystem.WORKING:
				status.text = tr("detail.momo_working")
			elif not momos.at_work(id):
				status.text = tr("detail.momo_walking")
			else:
				status.text = tr("detail.momo_waiting")


func _chip(who: String) -> Control:
	var chip := PanelContainer.new()
	chip.name = "Chip_" + who.replace(":", "_")
	chip.set_meta("who", who)
	chip.custom_minimum_size = Vector2(150, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var face := PanelViews.icon(lib, {"you": "ui_build", "auto": "ui_water"}.get(who, "momo_front"), 40.0)
	if who == "empty":
		face.modulate = Color(1, 1, 1, 0.25)
	row.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	var n: String
	if who == "you":
		n = tr("detail.you")
	elif who == "auto":
		n = tr("detail.irrigation")
	elif who == "empty":
		n = tr("detail.empty_slot")
	else:
		n = tr(String((sim.system(&"momo") as MomoSystem).get_momo(int(who.trim_prefix("momo:")))["name"]))
	col.add_child(PanelViews.label(n, 18, who == "empty"))
	if who != "empty":
		var st := PanelViews.label("", 14, true)
		st.name = "Status"
		col.add_child(st)
	row.add_child(col)
	chip.add_child(row)
	return chip
