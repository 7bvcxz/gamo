extends "res://tests/framework/test_case.gd"

## The mailbox on screen: the red dot while a letter is unread (Step 57: the
## button alone tells it -- a short pulse, nothing over the Momo), the list,
## the letter on paper with what its research needs, the way to that research
## and the way back -- all with real taps.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var mail: MailSystem
var frame: PanelFrame
var view: MailboxView
var vp: Viewport


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	# The Momo these cases are about (Step 53: a new island has none).
	with_starter_momo(sim)
	await tree.process_frame
	mail = sim.system(&"mail")
	frame = main.get("mail_frame")
	view = main.get("mailbox_view")
	vp = main.get_viewport()
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _tap(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = p
		m.pressed = pressed
		vp.push_input(m, true)


func _first_letter() -> void:
	var farm := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	# Until the first letter arrives (ten farm stages by the Momo), not
	# longer: five-second cycles reach the next milestones within minutes.
	var waited := 0
	while mail.letters.is_empty() and waited < 250000:
		sim.advance_ms(500)
		waited += 500
	await tree.process_frame


func test_an_empty_mailbox() -> void:
	main.call("_on_hud_action", &"mailbox")
	assert_true(frame.visible, "the mailbox opens")
	assert_true(view.empty_label.visible, "and says there is nothing yet")
	assert_eq(view.list_box.get_child_count(), 0, "no rows")
	assert_false((main.get("hud") as Hud).buttons[&"mailbox"].badge, "no red dot")


func test_a_new_letter_is_news_on_the_button_alone() -> void:
	var button: HudButton = (main.get("hud") as Hud).buttons[&"mailbox"]
	await _first_letter()
	assert_eq(mail.unread_count(), 1, "a letter came")
	assert_true(button.badge, "the mailbox button has a red dot")
	assert_eq(button.pulse_count, 1, "and plays its news once")
	assert_true(button.pulsing(), "a short pulse")
	assert_true(button.dot_scale() >= 1.0, "")
	var swell := 0.0
	for i in 30:
		button._process(HudButton.PULSE_SECONDS / 30.0)
		swell = maxf(swell, button.dot_scale())
	assert_true(swell > 1.3, "the dot swells (%.2f)" % swell)
	assert_false(button.pulsing(), "then it is still")
	assert_true(button.badge, "the dot stays while the letter is unread")
	var actor := (main.get("momo_views") as MomoViews).actor(1)
	assert_false("envelope" in actor, "nothing floats over the Momo who wrote it")
	assert_eq(actor.get_children().map(func(c: Node) -> String: return c.get_class() if c.get_script() == null else String((c.get_script() as Script).get_global_name())), ["MomoRig", "MoodBubble"], "its body and its mood -- no letter")
	assert_true((main.get("hud") as Hud).buttons[&"research"].badge, "its research is news on the Research button")


func test_letters_close_together_pulse_once_and_a_catch_up_not_at_all() -> void:
	var hud: Hud = main.get("hud")
	var button: HudButton = hud.buttons[&"mailbox"]
	hud.letter_news()
	hud.letter_news()
	hud.letter_news()
	assert_eq(button.pulse_count, 1, "three letters in a row: one pulse, not a storm")
	var before := button.pulse_count
	sim.replaying = true
	var farm := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(250000)
	sim.replaying = false
	assert_true(mail.letters.size() >= 1, "letters came during the catch-up")
	assert_eq(button.pulse_count, before, "no pulse for them")
	hud.refresh(true)
	assert_true(button.badge, "the dot shows")


func test_reduced_motion_and_no_effects_only_show_the_dot() -> void:
	var hud: Hud = main.get("hud")
	var button: HudButton = hud.buttons[&"mailbox"]
	for setting: String in ["reduced", "off"]:
		FxPrefs.reset()
		if setting == "reduced":
			FxPrefs.reduced_motion = true
		else:
			FxPrefs.enabled = false
		hud._news_at = -HudButton.PULSE_SECONDS * 100000
		var was := button.pulse_count
		hud.letter_news()
		assert_eq(button.pulse_count, was, "%s: no movement" % setting)
		assert_true(button.badge, "%s: the dot" % setting)
	FxPrefs.reset()


func test_read_see_what_it_needs_go_there_and_back_with_taps() -> void:
	await _first_letter()
	main.call("_on_hud_action", &"mailbox")
	await tree.process_frame
	assert_eq(view.list_box.get_child_count(), 1, "one row")
	var row: Button = view.list_box.get_child(0)
	assert_true(row.size.y >= 72.0, "a row is a finger's height")
	assert_true(row.get_meta("unread"), "marked unread")
	_tap(row)
	assert_eq(view.open_id, 1, "tapping the row opens the letter")
	assert_true(view.letter_box.visible and not view.list_box.visible, "the letter replaces the list")
	assert_eq(view.card.title_label.text, "What if we widened the field?", "its title")
	assert_true(view.card.body_label.text.begins_with("Guess what"), "its words")
	assert_eq(view.card.from_label.text, "From Momo", "from the sender")
	assert_true(int(mail.get_letter(1)["read_ms"]) >= 0, "opening marks it read in the simulation")
	await tree.process_frame
	assert_false((main.get("hud") as Hud).buttons[&"mailbox"].badge, "the red dot goes")
	# Under the letter: what its research needs, from the research rules.
	assert_true(view.footer.visible, "a footer under a research letter")
	assert_eq(view.footer_title.text, "To research Field expansion", "")
	var lines: Array = view.footer_lines.get_children().map(func(c: Node) -> String: return (c as Label).text)
	assert_true(lines.has("✓ Now on the Research list"), "the letter opened it (%s)" % [lines])
	assert_true(lines.has("· A research lab"), "there is no lab yet")
	var notes := int((sim.system(&"research") as ResearchSystem).cost_of("farm_expansion")["items"].get("notes", 0))
	assert_true(lines.has("· Research notes 0 / %d" % notes), "its notes, with progress")
	assert_false(lines.any(func(l: String) -> bool: return l.contains("Ready")), "not ready yet")
	var bs: BuildingSystem = sim.system(&"buildings")
	bs.place_instant("research", Vector2i(0, 1))
	(sim.system(&"inventory") as InventorySystem).add("notes", notes, "test")
	(sim.system(&"economy") as EconomySystem).earn(1000, "test")
	view.refresh()
	lines = view.footer_lines.get_children().map(func(c: Node) -> String: return (c as Label).text)
	assert_eq(lines[0], "✓ Ready to research now", "all met: ready (%s)" % [lines])
	assert_true(lines.has("✓ A research lab"), "the lab is ticked")
	# The way to it.
	assert_true(view.research_button.size.y >= 48.0, "a finger's height")
	assert_eq(view.research_button.text, "See it in Research", "")
	_tap(view.research_button)
	await tree.process_frame
	var rframe: PanelFrame = main.get("research_frame")
	assert_false(frame.visible, "the mailbox closes")
	assert_true(rframe.visible, "Research opens")
	var rv := rframe.current_view() as ResearchView
	assert_eq(rv.industry, "farm", "on the farm branch")
	assert_eq(rv.selected, "farm_expansion", "at that topic")
	assert_true(rv.fresh.has("farm_expansion"), "with its news dot")
	assert_false((main.get("hud") as Hud).buttons[&"research"].badge, "shown: the Research button's dot goes")
	rframe.close()
	assert_true(rv.fresh.is_empty(), "closed: the panel's dots go too")
	main.call("_on_hud_action", &"mailbox")
	view.open_letter(1)
	assert_true(view.back_button.size.x >= 48.0, "back is a finger's size")
	_tap(view.back_button)
	assert_eq(view.open_id, 0, "back to the list")
	assert_false(view.list_box.get_child(0).get_meta("unread"), "the row is read now")


func test_a_letter_without_research_has_no_footer() -> void:
	mail.letters.append({"id": 7, "template": "hello", "sender": 1, "sender_name": "momo.name.0", "industry": "farm",
		"title": "letter.farm_first_harvest.title", "body": "letter.farm_first_harvest.body", "research": "",
		"written_ms": 0, "day": 1, "read_ms": -1, "claimed_ms": -1})
	main.call("_on_hud_action", &"mailbox")
	view.open_letter(7)
	assert_true(view.letter_box.visible, "it opens")
	assert_false(view.footer.visible, "but has nothing to research: no footer, no made-up conditions")


func test_newest_first_and_closing_returns_to_the_list() -> void:
	await _first_letter()
	(sim.system(&"progression") as ProgressionSystem).add_mastery("farm", 100)
	sim.advance_ms(mail.research_gap_left_ms() + sim.clock.day_ms)
	assert_true(mail.letters.size() >= 2, "two letters")
	main.call("_on_hud_action", &"mailbox")
	assert_eq(String(view.list_box.get_child(0).name), "Row_%d" % mail.letters.back()["id"], "the newest on top")
	view.open_letter(1)
	frame.close()
	main.call("_on_hud_action", &"mailbox")
	assert_eq(view.open_id, 0, "opening again starts at the list")


func test_one_panel_at_a_time() -> void:
	main.call("_on_hud_action", &"status")
	main.call("_on_hud_action", &"mailbox")
	assert_false((main.get("status_frame") as PanelFrame).visible, "the mailbox replaces Status")
	main.call("_on_hud_action", &"mailbox")
	assert_false(frame.visible, "and its button closes it again")


func test_the_letter_speaks_the_players_language() -> void:
	await _first_letter()
	main.call("_on_hud_action", &"mailbox")
	view.open_letter(1)
	LocaleService.apply("ko")
	view.refresh()
	assert_eq(view.card.title_label.text, "밭을 조금 넓혀 보면 어때?", "Korean title")
	assert_eq(view.card.from_label.text, "모모의 편지", "Korean header")
	assert_eq(view.footer_title.text, "밭 넓히기 연구 조건", "Korean conditions")
	assert_eq(view.research_button.text, "연구에서 보기", "Korean button")
	for code: String in ["ja", "zh_CN"]:
		LocaleService.apply(code)
		view.refresh()
		for c: Node in view.footer_lines.get_children():
			assert_false((c as Label).text.contains("mail.") or (c as Label).text.contains("research.req"), "%s: every condition translated (%s)" % [code, (c as Label).text])
	LocaleService.apply("en")
