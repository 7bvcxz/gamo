class_name InventoryView
extends VBoxContainer

## The store: one row per item the island has ever had -- icon, name, how
## full its stack is, and how many were made. Crops are sold the moment they
## are picked (Step 50): their row says so instead of showing a stack that
## never fills. Items the player has never seen stay out of the list, so the
## store does not name resources before the game has introduced them.

var sim: Simulation
var lib: SpriteLibrary
var rows: Dictionary = {}
var _shown: Array[String] = []


func setup(p_sim: Simulation, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	lib = p_lib
	name = "InventoryView"
	add_theme_constant_override("separation", 12)


func known_items() -> Array[String]:
	var inv: InventorySystem = sim.system(&"inventory")
	var out: Array[String] = []
	var table: Dictionary = sim.data.table("items").get("items", {})
	for item: String in table:
		if inv.count(item) > 0 or int(inv.produced.get(item, 0)) > 0 or table[item].get("kind", "") == "crop":
			out.append(item)
	return out


func refresh() -> void:
	var inv: InventorySystem = sim.system(&"inventory")
	var items := known_items()
	if items != _shown:
		_shown = items
		PanelViews.clear(self)
		rows.clear()
		for item: String in items:
			rows[item] = _row(item)
	var economy: EconomySystem = sim.system(&"economy")
	for item: String in items:
		var r: Dictionary = rows[item]
		var have := inv.count(item)
		var cap := inv.capacity(item)
		var at_once := economy.sells_at_once(item)
		(r["count"] as Label).text = "" if at_once else "%d / %d" % [have, cap]
		(r["bar"] as Bar).visible = not at_once
		(r["bar"] as Bar).value = float(have) / maxf(cap, 1)
		var notes: Array[String] = []
		if at_once:
			notes.append(tr("panel.store.sold_at_once") % economy.unit_price(item))
		notes.append(tr("panel.store.made") % int(inv.produced.get(item, 0)))
		(r["note"] as Label).text = "  ·  ".join(notes)


func _row(item: String) -> Dictionary:
	var def := sim.data.item(item)
	var row := HBoxContainer.new()
	row.name = "Item_" + item
	row.add_theme_constant_override("separation", 12)
	row.add_child(PanelViews.icon(lib, String(def.get("icon", "ui_sprout")), 44.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	var n := PanelViews.label(tr(String(def.get("name", item))), 20)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	var count := PanelViews.label("", 20)
	count.name = "Count"
	head.add_child(count)
	col.add_child(head)
	var bar := Bar.new(Color("#9be15d") if def.get("kind", "") == "crop" else Color("#d9b48a"))
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(0, 10)
	col.add_child(bar)
	var note := PanelViews.label("", 15, true)
	note.name = "Note"
	col.add_child(note)
	row.add_child(col)
	add_child(row)
	return {"row": row, "count": count, "bar": bar, "note": note}
