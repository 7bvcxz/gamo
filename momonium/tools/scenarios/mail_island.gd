extends RefCounted

## Capture scenario: Momo's first letter after an unattended harvest (island).

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var farm := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(250000)
	(sim.system(&"progression") as ProgressionSystem).add_mastery("farm", 100)
	sim.time_scale = 0.0
	match "island":
		"list":
			main.call("_on_hud_action", &"mailbox")
		"letter":
			main.call("_on_hud_action", &"mailbox")
			(main.get("mailbox_view") as MailboxView).open_letter(1)
