class_name EconomyView
extends VBoxContainer

## Money: what there is now, where today's money came from and went (one row
## per ledger category), the last seven closed days as bars, and the totals
## since the game began. Every figure is the economy's own ledger; the view
## adds nothing up beyond what it shows.

var sim: Simulation
var money_label: Label
var today_box: VBoxContainer
var days: DayBars
var totals_box: VBoxContainer


func setup(p_sim: Simulation, _lib: SpriteLibrary) -> void:
	sim = p_sim
	name = "EconomyView"
	add_theme_constant_override("separation", 8)
	money_label = PanelViews.label("", 34)
	money_label.name = "Money"
	add_child(money_label)
	add_child(_heading("panel.economy.today"))
	today_box = VBoxContainer.new()
	today_box.name = "Today"
	add_child(today_box)
	add_child(_heading("panel.economy.days"))
	days = DayBars.new()
	days.name = "Days"
	days.custom_minimum_size = Vector2(0, 86)
	add_child(days)
	totals_box = VBoxContainer.new()
	totals_box.name = "Totals"
	add_child(totals_box)


func _heading(key: String) -> Label:
	var l := PanelViews.label(tr(key), 17, true)
	l.set_meta("key", key)
	return l


static func category_name(category: String) -> String:
	var key := "econ.cat." + category
	var text := TranslationServer.translate(key)
	return category if text == key else text


func refresh() -> void:
	var eco: EconomySystem = sim.system(&"economy")
	money_label.text = PanelViews.money(eco.money)
	PanelViews.clear(today_box)
	var cats := eco.today.keys()
	cats.sort()
	if cats.is_empty():
		today_box.add_child(PanelViews.label(tr("panel.economy.none"), 17, true))
	for c: String in cats:
		var r := PanelViews.row(category_name(c), _signed(int(eco.today[c])))
		r.name = "Cat_" + c
		today_box.add_child(r)
	var recent: Array = eco.history.slice(maxi(eco.history.size() - 7, 0))
	days.days = recent
	days.queue_redraw()
	PanelViews.clear(totals_box)
	if not eco.history.is_empty():
		var y: Dictionary = eco.history.back()
		var r := PanelViews.row(tr("panel.economy.yesterday"), _signed(int(y.get("income", 0)) - int(y.get("expense", 0))))
		r.name = "Yesterday"
		totals_box.add_child(r)
	var tin := PanelViews.row(tr("panel.economy.total_in"), PanelViews.money(eco.lifetime_income()))
	tin.name = "TotalIn"
	totals_box.add_child(tin)
	var tout := PanelViews.row(tr("panel.economy.total_out"), PanelViews.money(eco.lifetime_expense()))
	tout.name = "TotalOut"
	totals_box.add_child(tout)
	for child: Node in get_children():
		if child.has_meta("key"):
			(child as Label).text = tr(String(child.get_meta("key")))


static func _signed(amount: int) -> String:
	return ("+" if amount > 0 else "") + PanelViews.money(amount)


## Seven closed days side by side: income up in green, spending down in red,
## scaled to the biggest of them.
class DayBars:
	extends Control

	var days: Array = []

	func _draw() -> void:
		var mid := size.y * 0.62
		draw_line(Vector2(0, mid), Vector2(size.x, mid), Color(1, 1, 1, 0.25), 1.0)
		if days.is_empty():
			return
		var biggest := 1.0
		for d: Dictionary in days:
			biggest = maxf(biggest, maxf(float(d.get("income", 0)), float(d.get("expense", 0))))
		var slot := size.x / 7.0
		for i in days.size():
			var d: Dictionary = days[i]
			var x := (i + 7 - days.size()) * slot + slot * 0.25
			var w := slot * 0.5
			var up := (mid - 4.0) * float(d.get("income", 0)) / biggest
			var down := (size.y - mid - 2.0) * float(d.get("expense", 0)) / biggest
			draw_rect(Rect2(x, mid - up, w, up), Color("#9be15d"))
			draw_rect(Rect2(x, mid, w, down), Color("#ff8a7a"))
