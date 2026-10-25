class_name LifeView
extends VBoxContainer

## Momo life, explained: happiness and where each point comes from (an open
## park, a pub that had its crops today, a hall with power -- and why one is
## shut), the homes and how many still sleep outdoors, and what all of it does
## to Momo work time.

var sim: Simulation
var community: CommunitySystem
var happy_bar: Bar
var happy_label: Label
var parts: VBoxContainer
var homes_row: HBoxContainer
var homeless: Label
var work_row: HBoxContainer


func setup(p_sim: Simulation, _lib: SpriteLibrary) -> void:
	sim = p_sim
	community = sim.system(&"community")
	name = "LifeView"
	add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	var title := PanelViews.label("", 20)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	happy_label = PanelViews.label("", 20)
	happy_label.name = "Happiness"
	head.add_child(happy_label)
	add_child(head)
	happy_bar = Bar.new(Color("#ffb3c8"))
	happy_bar.custom_minimum_size = Vector2(0, 12)
	add_child(happy_bar)
	parts = VBoxContainer.new()
	parts.name = "Parts"
	add_child(parts)
	homes_row = PanelViews.row("", "")
	homes_row.name = "Homes"
	add_child(homes_row)
	homeless = PanelViews.label("", 15)
	homeless.name = "Homeless"
	homeless.add_theme_color_override("font_color", Color("#ffb3a8"))
	add_child(homeless)
	work_row = PanelViews.row("", "")
	work_row.name = "Work"
	add_child(work_row)


## Why an amenity is shut today, in words.
func shut_reason(id: int) -> String:
	var bs: BuildingSystem = sim.system(&"buildings")
	var am: Dictionary = bs.type_def(bs.get_building(id)).get("amenity", {})
	var daily: Dictionary = am.get("daily", {})
	if not daily.is_empty():
		var names: Array[String] = []
		for item: String in daily:
			names.append("%s %d" % [tr(String(sim.data.item(item).get("name", item))), int(daily[item])])
		return tr("life.shut_short").format({"items": ", ".join(names)})
	return tr("life.shut_power").format({"kw": BuildingDetailView.amount(float(am.get("power", 0)))})


func refresh() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	(get_child(0).get_node("Title") as Label).text = tr("life.happiness")
	var h := community.happiness()
	var max_h := sim.data.get_float("balance", "community.max_happiness", 100.0)
	happy_label.text = "%d / %d" % [int(round(h)), int(max_h)]
	happy_bar.value = h / max_h
	PanelViews.clear(parts)
	var bd := community.breakdown()
	if bd.is_empty():
		parts.add_child(PanelViews.label(tr("life.none"), 15, true))
	for part: Dictionary in bd:
		var name_ := tr(String(sim.data.building_type(String(part["type"])).get("name", "")))
		var value := ""
		if not bool(part["open"]):
			value = shut_reason(int(part["id"]))
		elif float(part["adds"]) <= 0.0:
			value = tr("life.extra_copy")
		else:
			value = "%s +%s" % [tr("life.open"), BuildingDetailView.amount(float(part["adds"]))]
		var r := PanelViews.row(name_, value)
		r.name = "Part_%d" % int(part["id"])
		parts.add_child(r)
	var momos: MomoSystem = sim.system(&"momo")
	var housed := community.housing().size()
	_set_row(homes_row, tr("life.homes"), "%d / %d" % [housed, community.capacity()])
	var out := momos.ids().size() - housed
	homeless.visible = out > 0
	homeless.text = tr("life.homeless").format({"n": out})
	var sample := momos.ids()[0] if not momos.ids().is_empty() else 0
	var f := community.work_factor(sample) if sample != 0 else 1.0
	_set_row(work_row, tr("life.work"), "×%s" % BuildingDetailView.amount(snappedf(f, 0.01)))


func _set_row(row: HBoxContainer, key: String, value: String) -> void:
	(row.get_child(0) as Label).text = key
	(row.get_node("Value") as Label).text = value
