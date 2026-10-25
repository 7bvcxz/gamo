class_name StatsView
extends VBoxContainer

## The island's record: days, size, buildings, Momo at work, jobs done, crops
## grown, money earned and spent -- and below, its journey (JourneyView).
## Read from the systems each time it is shown.

var sim: Simulation
var values: Dictionary = {}
var journey_view: JourneyView

const ROWS := ["days", "land", "buildings", "momo", "tasks", "crops"]


func setup(p_sim: Simulation, _lib: SpriteLibrary) -> void:
	sim = p_sim
	name = "StatsView"
	add_theme_constant_override("separation", 10)
	for key: String in ROWS:
		var r := PanelViews.row("", "")
		r.name = "Row_" + key
		add_child(r)
		values[key] = r
	journey_view = JourneyView.new()
	journey_view.setup(sim)
	add_child(journey_view)


## The numbers themselves, for the view and for tests.
func numbers() -> Dictionary:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	var working := 0
	for id: int in momos.ids():
		if int(momos.get_momo(id)["assigned"]) != 0:
			working += 1
	var tasks := 0
	for id: int in buildings.ids():
		tasks += int(buildings.get_building(id).get("completed", 0))
	return {
		"days": sim.clock.day_number(),
		"land": (sim.system(&"world") as WorldSystem).owned_count(),
		"buildings": buildings.ids().size(),
		"momo": momos.ids().size(),
		"momo_working": working,
		"tasks": tasks,
		"crops": int((sim.system(&"inventory") as InventorySystem).produced.get("crop", 0)),
	}


func refresh() -> void:
	journey_view.refresh()
	var n := numbers()
	for key: String in ROWS:
		var r: HBoxContainer = values[key]
		(r.get_child(0) as Label).text = tr("panel.records." + key)
		var text := str(n[key])
		if key == "momo":
			text = tr("panel.records.momo_value") % [n["momo"], n["momo_working"]]
		(r.get_node("Value") as Label).text = text
