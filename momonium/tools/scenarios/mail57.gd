extends RefCounted

## Capture scenario (Step 57): a Momo works the farm until its first letter
## comes. MOMONIUM_MAIL57 picks the moment: arrive (the mailbox button's news
## under way, nothing over the Momo), letter (the letter and what its research
## needs), research (Research opened on the news, never having read it).

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	(main.get("tips") as Tips).allowed = false
	var momos: MomoSystem = sim.system(&"momo")
	var id := momos.add_momo(Vector2(0.55, 1.35))
	var farm := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.replaying = true
	sim.execute({"type": "momo.assign", "momo": id, "building": farm})
	var mail: MailSystem = sim.system(&"mail")
	var t := 0
	while mail.letters.is_empty() and t < 300000:
		sim.advance_ms(500)
		t += 500
	sim.replaying = false
	sim.time_scale = 0.0
	match OS.get_environment("MOMONIUM_MAIL57"):
		"letter":
			main.call("_on_hud_action", &"mailbox")
			(main.get("mailbox_view") as MailboxView).open_letter(int(mail.letters[0]["id"]))
		"research":
			main.call("_on_hud_action", &"research")
		_:
			(main.get("hud") as Hud).letter_news()
