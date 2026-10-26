class_name TierView
extends VBoxContainer

## The settlement's tier on the Status tab: what it is and how many special
## structures it may have, then each milestone of the next tier with what the
## island has and needs (a tick when met), and -- once all are met -- the
## button that promotes it. Read from TierSystem whenever shown.

signal promoted(tier: int)

var sim: Simulation
var tiers: TierSystem
var head: Label
var next_label: Label
var list: VBoxContainer
var promote_button: Button
var last_result: Dictionary = {}


func setup(p_sim: Simulation) -> void:
	sim = p_sim
	tiers = sim.system(&"tiers")
	name = "TierView"
	add_theme_constant_override("separation", 4)
	head = PanelViews.label("", 22)
	head.name = "Head"
	add_child(head)
	next_label = PanelViews.label("", 16, true)
	next_label.name = "Next"
	add_child(next_label)
	list = VBoxContainer.new()
	list.name = "Milestones"
	add_child(list)
	promote_button = Button.new()
	promote_button.name = "Promote"
	promote_button.custom_minimum_size = Vector2(0, 56)
	promote_button.focus_mode = Control.FOCUS_NONE
	promote_button.add_theme_font_size_override("font_size", 20)
	promote_button.pressed.connect(func() -> void:
		last_result = sim.execute({"type": "tier.promote"})
		if last_result["ok"]:
			promoted.emit(int(last_result["tier"]))
		refresh())
	add_child(promote_button)


func refresh() -> void:
	head.text = "%s · %s" % [tr("tier." + tiers.tier_name()), tr("tier.slots").format({"n": tiers.special_slots()})]
	PanelViews.clear(list)
	if tiers.is_top():
		next_label.text = tr("tier.top")
		promote_button.visible = false
		return
	var next := tiers.tier_name(tiers.tier + 1)
	next_label.text = tr("tier.next").format({"name": tr("tier." + next)})
	for p: Dictionary in tiers.progress():
		var value := "%s / %s" % [AnalyticsView.n(float(p["have"])), AnalyticsView.n(float(p["need"]))]
		if p["key"] == "produced":
			value = "$" + value.replace(" / ", " / $")
		var r := PanelViews.row(("✓ " if p["met"] else "") + tr("tier.need." + String(p["key"])), value)
		r.name = "Need_" + String(p["key"])
		if p["met"]:
			for l: Label in r.get_children():
				l.theme_type_variation = &"GoodLabel"
		list.add_child(r)
	promote_button.visible = true
	promote_button.disabled = not tiers.can_promote()
	promote_button.text = tr("tier.promote").format({"name": tr("tier." + next)})
