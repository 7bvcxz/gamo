extends "res://tests/framework/test_case.gd"

## The mailbox on screen: the red dot and the envelope over the sender while a
## letter is unread, the list, the letter on paper, accepting its proposal,
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
	# Until the first letter arrives (the Momo's first harvest), not longer:
	# five-second cycles reach the next milestones within minutes.
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


func test_a_new_letter_shows_on_the_island_and_the_button() -> void:
	await _first_letter()
	assert_eq(mail.unread_count(), 1, "a letter came")
	assert_true((main.get("hud") as Hud).buttons[&"mailbox"].badge, "the mailbox button has a red dot")
	var actor := (main.get("momo_views") as MomoViews).actor(1)
	assert_true(actor.envelope.visible, "the sender holds up an envelope")


func test_read_accept_and_back_with_taps() -> void:
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
	assert_eq(view.proposal_label.text, "Proposal  ·  Field expansion", "the research it proposes")
	assert_true(int(mail.get_letter(1)["read_ms"]) >= 0, "opening marks it read in the simulation")
	await tree.process_frame
	assert_false((main.get("hud") as Hud).buttons[&"mailbox"].badge, "the red dot goes")
	assert_false((main.get("momo_views") as MomoViews).actor(1).envelope.visible, "and so does the envelope")
	assert_true(view.claim_button.size.y >= 52.0, "accept is easy to hit")
	_tap(view.claim_button)
	assert_eq(mail.accepted_research(), ["farm_expansion"] as Array[String], "accepted")
	assert_true(view.claim_button.disabled, "only once")
	assert_eq(view.claim_button.text, "On the research list", "and says where it went")
	assert_true(view.back_button.size.x >= 48.0, "back is a finger's size")
	_tap(view.back_button)
	assert_eq(view.open_id, 0, "back to the list")
	assert_false(view.list_box.get_child(0).get_meta("unread"), "the row is read now")


func test_newest_first_and_closing_returns_to_the_list() -> void:
	await _first_letter()
	(sim.system(&"progression") as ProgressionSystem).add_mastery("farm", 100)
	sim.advance_to(sim.clock.next_day_start_ms() + 1)
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
	assert_eq(view.claim_button.text, "연구해 볼게", "Korean button")
	LocaleService.apply("en")
