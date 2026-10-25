class_name PowerView
extends VBoxContainer

## Power at a glance: supply against draw and the share it makes, every
## generator with what it gives now and what it depends on, every building
## that uses power, and today's supply as a curve with now marked -- so a
## brownout at dusk is seen coming, not explained.

var sim: Simulation
var lib: SpriteLibrary
var power: PowerSystem
var head: Label
var gens: VBoxContainer
var users: VBoxContainer
var chart: SupplyChart


func setup(p_sim: Simulation, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	lib = p_lib
	power = sim.system(&"power")
	name = "PowerView"
	add_theme_constant_override("separation", 8)
	head = PanelViews.label("", 20)
	head.name = "Head"
	add_child(head)
	chart = SupplyChart.new()
	chart.name = "Chart"
	chart.power = power
	chart.custom_minimum_size = Vector2(0, 90)
	add_child(chart)
	gens = VBoxContainer.new()
	gens.name = "Generators"
	add_child(gens)
	users = VBoxContainer.new()
	users.name = "Users"
	add_child(users)


func kind_note(id: int) -> String:
	var bs: BuildingSystem = sim.system(&"buildings")
	var gen := power.generator_def(String(bs.get_building(id)["type"]))
	match String(gen.get("kind", "")):
		"wind":
			return tr("power.kind.wind").format({"pct": int(round(power.wind(sim.now_ms()) * 100.0))})
		"steam":
			return tr("power.kind.steam") if power.output_of(id, sim.now_ms()) > 0.0 else tr("power.cold")
	return tr("power.kind." + String(gen.get("kind", "")))


func refresh() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	head.text = "%s %s kW · %s %s kW · %s %d%%" % [tr("power.supply"), BuildingDetailView.amount(snappedf(power.supply(), 0.1)),
		tr("power.demand"), BuildingDetailView.amount(snappedf(power.demand(), 0.1)), tr("power.share"), int(round(power.ratio() * 100.0))]
	PanelViews.clear(gens)
	if power.generators().is_empty():
		gens.add_child(PanelViews.label(tr("power.none"), 16, true))
	for id: int in power.generators():
		var b := bs.get_building(id)
		var gen := power.generator_def(String(b["type"]))
		var r := PanelViews.row("%s · %s" % [tr(String(bs.type_def(b).get("name", ""))), kind_note(id)],
			"%s / %s kW" % [BuildingDetailView.amount(snappedf(power.output_of(id, sim.now_ms()), 0.1)), BuildingDetailView.amount(float(gen.get("kw", 0)))])
		r.name = "Gen_%d" % id
		gens.add_child(r)
	PanelViews.clear(users)
	var any := false
	for id: int in bs.ids():
		var b := bs.get_building(id)
		var use := power.use_of(String(b["type"]))
		if use.is_empty():
			continue
		if not any:
			users.add_child(PanelViews.label(tr("power.users"), 15, true))
			any = true
		var share := int(round(float(power.shares.get(id, power.satisfaction(String(b["type"])))) * 100.0))
		var r := PanelViews.row(tr(String(bs.type_def(b).get("name", ""))), "%s kW · %d%%" % [BuildingDetailView.amount(float(use["draw"])), share])
		r.name = "Use_%d" % id
		users.add_child(r)
	chart.queue_redraw()


## Today's supply, sampled from the same functions the simulation uses, with
## the draw now as a line and the present moment marked.
class SupplyChart:
	extends Control

	var power: PowerSystem

	func _draw() -> void:
		if power == null:
			return
		var sim := power.sim
		var day := sim.clock.day_ms
		var start := sim.now_ms() - posmod(sim.now_ms(), day)
		var cap := maxf(power.capacity(), maxf(power.demand(), 1.0))
		var pts := PackedVector2Array()
		for i in 49:
			var t := start + int(day * i / 48.0)
			var y := size.y - 4.0 - (size.y - 8.0) * power.supply(t) / cap
			pts.append(Vector2(size.x * i / 48.0, y))
		var fill := pts.duplicate()
		fill.append(Vector2(size.x, size.y))
		fill.append(Vector2(0, size.y))
		draw_colored_polygon(fill, Color(1.0, 0.85, 0.3, 0.25))
		draw_polyline(pts, Color("#ffd84d"), 2.5, true)
		var dy := size.y - 4.0 - (size.y - 8.0) * power.demand() / cap
		draw_dashed_line(Vector2(0, dy), Vector2(size.x, dy), Color("#ff8a7a"), 2.0, 6.0)
		var nx := size.x * float(posmod(sim.now_ms(), day)) / float(day)
		draw_line(Vector2(nx, 0), Vector2(nx, size.y), Color(1, 1, 1, 0.8), 2.0)
