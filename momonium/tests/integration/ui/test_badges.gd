extends "res://tests/framework/test_case.gd"

## Step 64: numbers, not dots, on the HUD's buttons. 0 hides it, 1-99 the
## number, 100 or more "99+". The mailbox counts unread letters, Research the
## topics not yet shown; Status (a promotion ready) and Hire (a hire worth
## it) have no count of their own and show 1; the Premium Shop none. Reading
## a letter takes one off the mailbox only; opening Research clears its own.
## A save, a load and time away keep the numbers; a screen reader hears them.
## The capsule sits on the button's corner: digits never clipped, the icon
## and the label not covered, on screen.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var hud: Hud
var mail: MailSystem
var research: ResearchSystem


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	with_starter_momo(sim)
	hud = main.get("hud")
	mail = sim.system(&"mail")
	research = sim.system(&"research")
	LocaleService.apply("en")
	await tree.process_frame


func after_each() -> void:
	LocaleService.apply("en")
	main.queue_free()
	await tree.process_frame


## `letters` unread letters and exactly `topics` topics not yet shown.
func _news_direct(letters: int, topics: int) -> void:
	var templates: Array = sim.data.table("letters").get("letters", [])
	for i in letters:
		mail._write(templates[i % templates.size()], 1)
	# More of the tree open, when a new island has too few topics to show.
	var prog: ProgressionSystem = sim.system(&"progression")
	var available := func() -> int: return research.nodes().filter(func(n: Dictionary) -> bool: return research.state_of(String(n["id"])) == "available").size()
	while int(available.call()) < topics and prog.level < 30:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	var fresh := research.new_topics()
	for n: Dictionary in research.nodes():
		var id := String(n["id"])
		if research.state_of(id) == "available" and not fresh.has(id) and fresh.size() < topics:
			research.seen.erase(id)
			fresh.append(id)
	research.acknowledge(fresh.slice(topics))
	hud.refresh(true)


func _b(name: StringName) -> HudButton:
	return hud.buttons[name] as HudButton


func test_what_a_badge_says() -> void:
	for pair: Array in [[0, ""], [1, "1"], [9, "9"], [10, "10"], [99, "99"], [100, "99+"], [123, "99+"], [-3, ""]]:
		assert_eq(HudButton.badge_text(int(pair[0])), String(pair[1]), "%d -> '%s'" % pair)
	var b := _b(&"mailbox")
	b.count = 0
	assert_eq(b.badge_rect(), Rect2(), "0: nothing drawn")
	for n: int in [1, 9, 10, 99, 100, 123]:
		b.count = n
		var r := b.badge_rect()
		var tw := b.get_theme_default_font().get_string_size(HudButton.badge_text(n), HORIZONTAL_ALIGNMENT_LEFT, -1, HudButton.BADGE_FONT).x
		assert_true(r.size.x >= tw + 8.0, "%d: the digits fit (%.0f in %.0f)" % [n, tw, r.size.x])
		assert_true(r.size.x >= r.size.y, "%d: a capsule, never narrower than round" % n)
		var icon := b.icon_drawn_rect()
		var label := b._label.get_rect()
		var over_icon := r.intersection(icon).get_area()
		assert_true(over_icon <= icon.get_area() * 0.12, "%d: the icon stays seen (%.0f of %.0f px covered)" % [n, over_icon, icon.get_area()])
		assert_false(r.intersects(label), "%d: the label is not covered" % n)


func test_the_numbers_come_from_the_island() -> void:
	_news_direct(3, 2)
	assert_eq(mail.unread_count(), 3, "three unread letters")
	assert_eq(research.new_topics().size(), 2, "two topics not yet shown")
	assert_eq(_b(&"mailbox").count, 3, "Mailbox 3")
	assert_eq(_b(&"research").count, 2, "Research 2")
	assert_eq(_b(&"shop").count, 0, "the Premium Shop: never")
	# Reading one letter: the mailbox only.
	sim.execute({"type": "mail.read", "id": int(mail.letters[0]["id"])})
	hud.refresh()
	assert_eq(_b(&"mailbox").count, 2, "a letter read: 2")
	assert_eq(_b(&"research").count, 2, "Research untouched")
	# Opening Research: its own, not the mail's.
	main.call("_on_hud_action", &"research")
	await tree.process_frame
	hud.refresh()
	assert_eq(_b(&"research").count, 0, "opened: shown, gone")
	assert_eq(_b(&"mailbox").count, 2, "the letters still unread")


func test_yes_or_no_news_is_one() -> void:
	var tiers: TierSystem = sim.system(&"tiers")
	assert_eq(_b(&"status").count, 0, "nothing to promote: none")
	var bs: BuildingSystem = sim.system(&"buildings")
	bs.place_instant("farm", Vector2i(1, 0))
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	hud.refresh(true)
	assert_eq(hud.hire_button.count, 1, "a hire worth it: 1, not a made-up number")
	assert_eq(_b(&"shop").count, 0, "and the Premium Shop has none")
	assert_true(tiers != null, "")


func test_a_save_a_load_and_time_away_keep_them() -> void:
	_news_direct(4, 1)
	var state: Dictionary = JSON.parse_string(JSON.stringify(sim.save_state()))
	var copy := Simulation.from_save(state)
	assert_eq((copy.system(&"mail") as MailSystem).unread_count(), 4, "unread letters saved")
	assert_eq((copy.system(&"research") as ResearchSystem).new_topics().size(), 1, "topics not yet shown saved")
	sim.replaying = true
	sim.advance_ms(60000)
	sim.replaying = false
	hud.refresh(true)
	assert_eq(_b(&"mailbox").count, mail.unread_count(), "after time away: the real count")
	assert_true(_b(&"mailbox").count >= 4, "")


func test_screen_readers_hear_the_number() -> void:
	_news_direct(3, 2)
	assert_eq(_b(&"mailbox").accessibility_name, "Mailbox, 3 unread", "")
	assert_eq(_b(&"research").accessibility_name, "Research, 2 new topics", "")
	assert_eq(_b(&"mailbox").tooltip_text, "Mailbox, 3 unread", "the tooltip too")
	LocaleService.apply("ko")
	await tree.process_frame
	assert_eq(_b(&"mailbox").accessibility_name, "편지함, 읽지 않은 편지 3통", "in Korean")
	hud.count_override[&"mailbox"] = 123
	hud.refresh(true)
	assert_eq(_b(&"mailbox").accessibility_name, "편지함, 읽지 않은 편지 99+통", "99+ said as shown")
	hud.count_override.clear()
	main.call("_on_hud_action", &"research")
	await tree.process_frame
	hud.refresh(true)
	assert_eq(_b(&"research").accessibility_name, "연구", "no news: the name alone")


func test_badges_stay_on_screen_and_off_each_other() -> void:
	for n: StringName in hud.buttons:
		hud.count_override[n] = 123
	hud.refresh(true)
	var screen := Rect2(Vector2.ZERO, hud.size)
	var rects: Array[Rect2] = []
	for n: StringName in hud.buttons:
		var b := _b(n)
		var r := Rect2(b.get_global_rect().position + b.badge_rect().position, b.badge_rect().size)
		assert_true(screen.encloses(r), "%s: on screen %s" % [n, r])
		rects.append(r)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			assert_false(rects[i].intersects(rects[j]), "badges apart")
	for n: StringName in hud.buttons:
		var b := _b(n)
		var r := Rect2(b.get_global_rect().position + b.badge_rect().position, b.badge_rect().size)
		for other: StringName in hud.buttons:
			if other != n:
				assert_false(r.intersects(_b(other).get_global_rect()), "%s's badge off %s" % [n, other])
	hud.count_override.clear()
