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


func show_building(id: int) -> void:
	building_id = id
	PanelViews.clear(workers_box)
	refresh()


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
		gives.append("%s %d" % [tr(String(sim.data.item(item).get("name", item))), int(you["yield"][item])])
	_set_row(yield_row, tr("detail.cycle"), ", ".join(gives))
	_set_row(cycle_you, tr("detail.by_you"), duration(you["cycle_seconds"]))
	_set_row(cycle_momo, tr("detail.by_momo"), duration(by_momo["cycle_seconds"]))
	_set_row(done_row, tr("panel.records.tasks"), str(int(b.get("completed", 0))))


func _set_row(row: HBoxContainer, key: String, value: String) -> void:
	(row.get_child(0) as Label).text = key
	(row.get_node("Value") as Label).text = value


## One chip per worker spot: the Momo there and what it is doing, or an
## empty place. While the player is doing the current stage a "you" chip
## shows first.
func _refresh_workers(b: Dictionary, momos: MomoSystem) -> void:
	var slots := momos.slots_of(building_id)
	var ids := momos.workers_at(building_id)
	var want: Array[String] = []
	if b["state"] == BuildingSystem.WORKING and int(b.get("worker", 0)) == 0:
		want.append("you")
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
		if who == "you":
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
	var face := PanelViews.icon(lib, "momo_front" if who != "you" else "ui_build", 40.0)
	if who == "empty":
		face.modulate = Color(1, 1, 1, 0.25)
	row.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	var n: String
	if who == "you":
		n = tr("detail.you")
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
