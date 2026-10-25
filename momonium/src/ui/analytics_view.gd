class_name AnalyticsView
extends VBoxContainer

## The island's numbers over the last seven days, all from its daily book:
## money in and out, what was made, used and sold, each building's output and
## how much of the day it worked (tap one for its details), how busy the Momo
## were, power, and what stood idle and why.

signal building_chosen(id: int)

var sim: Simulation
var analytics: AnalyticsSystem
var money_box: VBoxContainer
var items_box: VBoxContainer
var buildings_box: VBoxContainer
var momo_row: HBoxContainer
var power_row: HBoxContainer
var blocked_box: VBoxContainer
var empty: Label


func setup(p_sim: Simulation, _lib: SpriteLibrary) -> void:
	sim = p_sim
	analytics = sim.system(&"analytics")
	name = "AnalyticsView"
	add_theme_constant_override("separation", 6)
	empty = PanelViews.label("", 16, true)
	empty.name = "Empty"
	add_child(empty)
	money_box = _section("Money")
	items_box = _section("Items")
	buildings_box = _section("Buildings")
	momo_row = PanelViews.row("", "")
	momo_row.name = "Momo"
	add_child(momo_row)
	power_row = PanelViews.row("", "")
	power_row.name = "Power"
	add_child(power_row)
	blocked_box = _section("Blocked")


func _section(node_name: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = node_name
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	return v


func _heading(box: VBoxContainer, key: String) -> void:
	box.add_child(PanelViews.label(tr(key), 15, true))


static func n(x: float) -> String:
	return NumberFormat.compact(x)


func refresh() -> void:
	var ds := analytics.last(7)
	empty.visible = ds.is_empty()
	empty.text = tr("stats.wait")
	for box: VBoxContainer in [money_box, items_box, buildings_box, blocked_box]:
		PanelViews.clear(box)
		box.visible = not ds.is_empty()
	momo_row.visible = not ds.is_empty()
	power_row.visible = not ds.is_empty()
	if ds.is_empty():
		return
	var days := ds.size()
	var bs: BuildingSystem = sim.system(&"buildings")
	# Money
	_heading(money_box, "stats.money")
	var inc := AnalyticsSystem.total(ds, "income")
	var exp := AnalyticsSystem.total(ds, "expense")
	var tin := 0
	var tout := 0
	for k: Variant in inc:
		tin += int(inc[k])
	for k: Variant in exp:
		tout += int(exp[k])
	var r := PanelViews.row(tr("stats.per_day").format({"d": days}), "+$%s / -$%s" % [n(tin / float(days)), n(tout / float(days))])
	r.name = "Money"
	money_box.add_child(r)
	# Items
	_heading(items_box, "stats.items")
	var made := AnalyticsSystem.total(ds, "made")
	var used := AnalyticsSystem.total(ds, "used")
	var sold := AnalyticsSystem.total(ds, "sold")
	var keys := made.keys()
	for k: Variant in used.keys() + sold.keys():
		if not keys.has(k):
			keys.append(k)
	for item: Variant in keys:
		var line := tr("stats.item_line").format({"made": n(float(made.get(item, 0)) / days), "used": n(float(used.get(item, 0)) / days), "sold": n(float(sold.get(item, 0)) / days)})
		var row := PanelViews.row(tr(String(sim.data.item(String(item)).get("name", item))), line)
		row.name = "Item_" + String(item)
		items_box.add_child(row)
	# Buildings, busiest first; tap for details
	_heading(buildings_box, "stats.buildings")
	var ids := bs.ids().filter(func(id: int) -> bool: return not bs.stages(bs.get_building(id)).is_empty())
	ids.sort_custom(func(a: int, b: int) -> bool: return analytics.building_rate(a)["utilization"] > analytics.building_rate(b)["utilization"] or (analytics.building_rate(a)["utilization"] == analytics.building_rate(b)["utilization"] and a < b))
	for id: int in ids.slice(0, 8):
		var rate := analytics.building_rate(id)
		var btn := Button.new()
		btn.name = "Building_%d" % id
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 44)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "%s · %s · %d%%" % [tr(String(bs.type_def(bs.get_building(id)).get("name", ""))),
			tr("stats.rate").format({"made": n(rate["made"]), "stages": n(rate["stages"])}), int(round(float(rate["utilization"]) * 100.0))]
		btn.add_theme_font_size_override("font_size", 15)
		var bid := id
		btn.pressed.connect(func() -> void: building_chosen.emit(bid))
		buildings_box.add_child(btn)
	# Momo and power
	(momo_row.get_child(0) as Label).text = tr("stats.momo")
	(momo_row.get_node("Value") as Label).text = "%d%%" % int(round(analytics.momo_utilization() * 100.0))
	var samples := 0
	var supply := 0.0
	var demand := 0.0
	var short := 0
	for d: Dictionary in ds:
		samples += int(d["samples"])
		supply += float(d["supply"])
		demand += float(d["demand"])
		short += int(d["short"])
	(power_row.get_child(0) as Label).text = tr("stats.power")
	(power_row.get_node("Value") as Label).text = tr("stats.power_line").format({"s": n(supply / maxf(samples, 1)), "d": n(demand / maxf(samples, 1)), "short": int(round(100.0 * short / maxf(samples, 1)))})
	# Bottlenecks
	_heading(blocked_box, "stats.blocked")
	var blocked := AnalyticsSystem.total(ds, "blocked")
	if blocked.is_empty():
		blocked_box.add_child(PanelViews.label(tr("stats.none_blocked"), 15, true))
	var by := AnalyticsSystem.total(ds, "blocked_by")
	for why: Variant in blocked:
		var worst := 0
		for id: Variant in by:
			if worst == 0 or int(by[id]) > int(by[worst]):
				worst = int(id)
		var row := PanelViews.row(tr("stats.why." + String(why)), "%d%%" % int(round(100.0 * int(blocked[why]) / maxf(samples, 1))))
		row.name = "Why_" + String(why)
		blocked_box.add_child(row)
