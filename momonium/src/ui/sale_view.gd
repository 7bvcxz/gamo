class_name SaleView
extends VBoxContainer

## Selling the island: what it is worth, line by line; what selling gives
## (legacy points, research points, the next island's head start); what goes
## and what stays. Selling takes two taps -- Sell, then the confirm that
## replaces it (Cancel puts it back).

signal sell_confirmed

var sim: Simulation
var lines_box: VBoxContainer
var reward_box: VBoxContainer
var reset_label: Label
var keep_label: Label
var sell_button: Button
var cancel_button: Button
var confirming := false


func setup(p_sim: Simulation, _lib: SpriteLibrary) -> void:
	sim = p_sim
	name = "SaleView"
	add_theme_constant_override("separation", 6)
	add_child(_heading("sale.worth"))
	lines_box = VBoxContainer.new()
	lines_box.name = "Lines"
	add_child(lines_box)
	add_child(_heading("sale.gives"))
	reward_box = VBoxContainer.new()
	reward_box.name = "Rewards"
	add_child(reward_box)
	add_child(_heading("sale.resets"))
	reset_label = PanelViews.label("", 15)
	reset_label.name = "Resets"
	reset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(reset_label)
	add_child(_heading("sale.keeps"))
	keep_label = PanelViews.label("", 15)
	keep_label.name = "Keeps"
	keep_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(keep_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	sell_button = Button.new()
	sell_button.name = "Sell"
	sell_button.custom_minimum_size = Vector2(0, 56)
	sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_button.focus_mode = Control.FOCUS_NONE
	sell_button.add_theme_font_size_override("font_size", 20)
	sell_button.pressed.connect(func() -> void:
		if confirming:
			confirming = false
			sell_confirmed.emit()
		else:
			confirming = true
		refresh())
	row.add_child(sell_button)
	cancel_button = Button.new()
	cancel_button.name = "Cancel"
	cancel_button.custom_minimum_size = Vector2(110, 56)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(func() -> void:
		confirming = false
		refresh())
	row.add_child(cancel_button)
	add_child(row)


func _heading(key: String) -> Label:
	var l := PanelViews.label(tr(key), 17, true)
	l.set_meta("key", key)
	return l


func _line(box: VBoxContainer, key: String, value: String, node_name: String) -> void:
	var r := PanelViews.row(key, value)
	r.name = node_name
	box.add_child(r)


func refresh() -> void:
	var p: PrestigeSystem = sim.system(&"prestige")
	var a := p.appraise()
	PanelViews.clear(lines_box)
	for fam: String in ["farm", "mine", "lumberyard", "research"]:
		_line(lines_box, tr(String(sim.data.building_type(fam).get("name", fam))), PanelViews.money(int(a["families"][fam])), "Fam_" + fam)
	if int(a["families"]["special"]) > 0:
		_line(lines_box, tr("sale.special"), PanelViews.money(int(a["families"]["special"])), "Fam_special")
	_line(lines_box, tr("sale.land"), PanelViews.money(int(a["land"])), "Land")
	_line(lines_box, tr("sale.productivity"), PanelViews.money(int(a["productivity"])), "Productivity")
	_line(lines_box, tr("sale.momo"), PanelViews.money(int(a["momo"])), "Momo")
	_line(lines_box, tr("sale.research"), PanelViews.money(int(a["research"])), "Research")
	_line(lines_box, tr("sale.experience"), PanelViews.money(int(a["experience"])), "Experience")
	if int(a["seed"]) > 0:
		_line(lines_box, tr("sale.seed"), "-" + PanelViews.money(int(a["seed"])), "Seed")
	_line(lines_box, tr("sale.net"), PanelViews.money(int(a["net"])), "Net")
	PanelViews.clear(reward_box)
	var gained := int(a["points"])
	var after := p.points + gained
	_line(reward_box, tr("sale.legacy"), "+%d ★ (%d)" % [gained, after], "Legacy")
	if int(a.get("monument", 0)) > 0:
		_line(reward_box, tr("sale.monument"), tr("sale.monument_line").format({"base": int(a["points_base"]), "bonus": int(a["monument"])}), "Monument")
	_line(reward_box, tr("sale.rp"), "+%d (%d)" % [int(a["rp_new"]), int(a["rp_after"])], "RP")
	_line(reward_box, tr("sale.next"), tr("sale.next_line").format({"money": p.start_money_bonus(after) + 10, "momo": 1 + p.start_momo_bonus(after),
		"work": int(round((1.0 - p.work_factor(after)) * 100.0))}), "Next")
	reset_label.text = tr("sale.resets_text")
	keep_label.text = tr("sale.keeps_text")
	sell_button.disabled = not a["can_sell"]
	if not a["can_sell"]:
		confirming = false
		sell_button.text = tr(String(a["reason"])) % int(a["min_level"])
	else:
		sell_button.text = tr("sale.confirm") if confirming else tr("sale.sell")
	sell_button.modulate = Color(1.0, 0.8, 0.75) if confirming else Color.WHITE
	cancel_button.visible = confirming
	cancel_button.text = tr("sale.cancel")
	for child: Node in get_children():
		if child.has_meta("key"):
			(child as Label).text = tr(String(child.get_meta("key")))
