class_name JourneyView
extends VBoxContainer

## The island's journey on the Records tab: time played, time away (and how
## much of it the island caught up on), then each first -- the first farm,
## harvest, sale, Momo at work, land, hire, research, letter, the levels, each
## tier -- with when it came: in time played, and since the island began.
## Read from JourneySystem whenever shown.

var sim: Simulation
var journey: JourneySystem
var head: Label
var totals: Label
var list: VBoxContainer


func setup(p_sim: Simulation) -> void:
	sim = p_sim
	journey = sim.system(&"journey")
	name = "JourneyView"
	add_theme_constant_override("separation", 6)
	head = PanelViews.label("", 22)
	head.name = "Head"
	add_child(head)
	totals = PanelViews.label("", 16, true)
	totals.name = "Totals"
	totals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(totals)
	list = VBoxContainer.new()
	list.name = "Firsts"
	list.add_theme_constant_override("separation", 6)
	add_child(list)


func refresh() -> void:
	head.text = tr("journey.title")
	if journey == null:
		return
	var t := journey.totals()
	totals.text = tr("journey.totals").format({"p": AwayView.long_duration(int(t["played_ms"])),
		"a": AwayView.long_duration(int(t["wall_ms"]) - int(t["played_ms"])), "o": AwayView.long_duration(int(t["offline_ms"]))})
	PanelViews.clear(list)
	var line := journey.timeline()
	if line.is_empty():
		list.add_child(PanelViews.label(tr("journey.empty"), 15, true))
		return
	for e: Dictionary in line:
		var r := PanelViews.row(label_of(String(e["key"])), tr("journey.when").format({
			"p": AwayView.long_duration(int(e["played_ms"])), "w": AwayView.long_duration(int(e["wall_ms"]))}))
		r.name = "First_" + String(e["key"]).replace(":", "_")
		list.add_child(r)


## The words for a first: "First harvest", "Level 5", "Became a City", ...
func label_of(k: String) -> String:
	var parts := k.split(":")
	match parts[0]:
		"built":
			if parts[1] == "special":
				return tr("journey.built_special")
			var def := sim.data.building_type(parts[1])
			return tr("journey.built").format({"name": tr(String(def.get("name", parts[1])))})
		"level":
			return tr("journey.level").format({"n": parts[1]})
		"tier":
			var tiers: TierSystem = sim.system(&"tiers")
			return tr("journey.tier").format({"name": tr("tier." + tiers.tier_name(int(parts[1])))})
	return tr("journey." + parts[0])
