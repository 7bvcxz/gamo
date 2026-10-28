class_name TierView
extends VBoxContainer

## The settlement's tier on the Status tab: what it is and how many special
## structures it may have, then each milestone of the next tier with what the
## island has and needs (a tick when met), and -- once all are met -- the
## button that promotes it. Read from TierSystem whenever shown.
##
## Step 72: this is the one place for the one goal (GoalSystem.current) --
## the island's next tier, then the civilization milestones -- with the road
## from Village to Civilization drawn above it (GoalLadder). Money conditions
## carry an estimate at today's pace, labelled as one.

signal promoted(tier: int)

var sim: Simulation
var tiers: TierSystem
var goals: GoalSystem
var head: Label
var ladder: GoalLadder
var next_label: Label
var list: VBoxContainer
var promote_button: Button
var last_result: Dictionary = {}


func setup(p_sim: Simulation) -> void:
	sim = p_sim
	tiers = sim.system(&"tiers")
	goals = sim.system(&"goals")
	name = "TierView"
	add_theme_constant_override("separation", 4)
	head = PanelViews.label("", 22)
	head.name = "Head"
	add_child(head)
	ladder = GoalLadder.new()
	ladder.setup(goals)
	add_child(ladder)
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
	ladder.refresh()
	PanelViews.clear(list)
	var cur := goals.current()
	var kind := String(cur["kind"])
	promote_button.visible = kind == "tier"
	if kind == "done":
		next_label.text = tr("goal.done")
		return
	var goal_name := tr(GoalLadder._name_key(String(cur["id"])))
	next_label.text = tr("tier.next").format({"name": goal_name})
	for p: Dictionary in cur["progress"]:
		var key := String(p["key"])
		var value := "%s / %s" % [AnalyticsView.n(float(p["have"])), AnalyticsView.n(float(p["need"]))]
		if key == "produced":
			value = "$" + value.replace(" / ", " / $")
		elif key == "tier":
			value = tr("tier." + tiers.tier_name(int(p["have"]))) + " / " + tr("tier." + tiers.tier_name(int(p["need"])))
		var label_key := "goal.need." + key if kind == "civ" and key != "momos" else "tier.need." + key
		var r := PanelViews.row(("✓ " if p["met"] else "") + tr(label_key), value)
		r.name = "Need_" + key
		if p["met"]:
			for l: Label in r.get_children():
				l.theme_type_variation = &"GoodLabel"
		list.add_child(r)
		var est := estimate(p)
		if est != "":
			var e := PanelViews.label(est, 13, true)
			e.name = "Estimate_" + key
			list.add_child(e)
	if kind == "tier":
		promote_button.disabled = not tiers.can_promote()
		promote_button.text = tr("tier.promote").format({"name": goal_name})


## Step 72: how long a money condition still takes at the income of the last
## minute, labelled as an estimate -- "" when met, or when nothing is coming in.
func estimate(p: Dictionary) -> String:
	if String(p["key"]) != "produced" or bool(p["met"]):
		return ""
	var per_min := (sim.system(&"economy") as EconomySystem).income_per_minute()
	if per_min <= 0:
		return ""
	var minutes := ceili(float(int(p["need"]) - int(p["have"])) / per_min)
	var t := tr("time.m").format({"m": minutes}) if minutes < 60 else tr("time.hm").format({"h": minutes / 60, "m": minutes % 60})
	return tr("goal.estimate").format({"t": t})
