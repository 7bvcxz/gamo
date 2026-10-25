extends "res://tests/framework/test_case.gd"

## Momo Letters: written by an assigned Momo at real milestones, once each,
## no more than one a day, kept with their read/accepted state across saves.

var sim: Simulation
var mail: MailSystem
var buildings: BuildingSystem
var prog: ProgressionSystem
var farm := 0


func before_each() -> void:
	sim = Simulation.new_game()
	mail = sim.system(&"mail")
	buildings = sim.system(&"buildings")
	prog = sim.system(&"progression")
	farm = buildings.place_instant("farm", Vector2i(1, 0))


func _harvest_by_hand(times: int) -> void:
	for i in times:
		for wait: int in [5000, 35000, 35000, 35000, 5000]:
			sim.execute({"type": "building.tap", "id": farm})
			sim.advance_ms(wait)


func test_the_first_unattended_harvest_brings_one_letter() -> void:
	var harvested := [0]
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_completed" and p["stage"] == "harvest" and harvested[0] == 0:
			harvested[0] = clock.now_ms)
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(250000)
	assert_eq(mail.letters.size(), 1, "one letter")
	var l: Dictionary = mail.letters[0]
	assert_eq(l["template"], "farm_first_harvest", "about the first harvest Momo brought in alone")
	assert_eq(l["sender"], 1, "from the Momo who did it")
	assert_eq(l["sender_name"], "momo.name.0", "signed with its name")
	assert_eq(l["industry"], "farm", "the farm industry")
	assert_eq(l["research"], "farm_expansion", "proposing field expansion")
	assert_eq(l["title"], "letter.farm_first_harvest.title", "title key")
	assert_eq(l["body"], "letter.farm_first_harvest.body", "explanation key")
	assert_eq(l["written_ms"], harvested[0], "written the moment the harvest was done")
	assert_eq(l["day"], 1 + harvested[0] / sim.clock.day_ms, "dated with the day it was written")
	assert_eq(l["read_ms"], -1, "unread")
	assert_eq(l["claimed_ms"], -1, "not accepted")
	assert_eq(mail.unread_count(), 1, "one unread")
	assert_true(mail.has_unread_from(1), "Momo 1 is waiting for an answer")
	sim.advance_ms(30000 * 20)
	assert_eq(mail.letters.filter(func(x: Dictionary) -> bool: return x["template"] == "farm_first_harvest").size(), 1, "never written twice")


func test_the_players_own_work_does_not_count() -> void:
	_harvest_by_hand(4)
	assert_true(int(prog.mastery_of("farm")["level"]) >= 2, "farm mastery reached Lv 2 by hand")
	assert_eq(mail.letters.size(), 0, "but nobody works the farm: no letter")
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	assert_eq(mail.letters.size(), 1, "assigning a Momo there brings the letter that was waiting")
	assert_eq(mail.letters[0]["template"], "farm_watering", "the mastery letter -- Momo has done no work yet")
	assert_eq(int(mail.work.get("farm", 0)), 0, "the player's stages are not Momo experience")


func test_at_most_one_letter_a_day() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	prog.add_mastery("farm", 100000)
	assert_true(int(prog.mastery_of("farm")["level"]) >= 3, "mastery jumped past two milestones at once")
	assert_eq(mail.letters.size(), 1, "only one letter today")
	var first_day: int = mail.letters[0]["day"]
	sim.advance_to(sim.clock.next_day_start_ms() + 1)
	assert_eq(mail.letters.size(), 2, "the next one tomorrow")
	assert_eq(mail.letters[1]["day"], first_day + 1, "on the following day")
	assert_eq([mail.letters[0]["template"], mail.letters[1]["template"]], ["farm_watering", "farm_soil"], "in data order")
	sim.advance_ms(30000 * 5)
	assert_eq(mail.letters.size(), 2, "and nothing more until a new milestone")


func test_the_most_experienced_assigned_momo_writes() -> void:
	var b: Dictionary = GameData.load_default().table("buildings").duplicate(true)
	b["types"]["farm"]["workers"] = 2
	sim = Simulation.new_game(GameData.from_tables({"buildings": b}))
	mail = sim.system(&"mail")
	buildings = sim.system(&"buildings")
	(sim.system(&"economy") as EconomySystem).earn(100, "test")
	sim.execute({"type": "momo.hire"})
	farm = buildings.place_instant("farm", Vector2i(1, 0))
	mail.work_by_momo[2] = {"farm": 9}
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.execute({"type": "momo.assign", "momo": 2, "building": farm})
	assert_eq(mail.sender_for("farm"), 2, "the one with more farm work")
	mail.work_by_momo[1] = {"farm": 9}
	assert_eq(mail.sender_for("farm"), 1, "ties go to the lowest id")
	assert_eq(mail.sender_for("mine"), 0, "nobody works a mine")


func test_read_and_accept() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	prog.add_mastery("farm", 100)
	var id: int = mail.letters[0]["id"]
	assert_eq(sim.execute({"type": "mail.read", "id": 99})["reason"], "err.no_letter", "unknown letter")
	sim.advance_ms(1234)
	assert_true(sim.execute({"type": "mail.read", "id": id})["ok"], "read")
	var read_at: int = mail.get_letter(id)["read_ms"]
	assert_eq(read_at, sim.now_ms(), "with the time it was read")
	assert_eq(mail.unread_count(), 0, "nothing unread")
	assert_false(mail.has_unread_from(1), "Momo 1 got its answer")
	sim.advance_ms(1000)
	sim.execute({"type": "mail.read", "id": id})
	assert_eq(mail.get_letter(id)["read_ms"], read_at, "reading again keeps the first time")
	var r := sim.execute({"type": "mail.claim", "id": id})
	assert_true(r["ok"], "accepted")
	assert_eq(r["research"], "watering_efficiency", "the proposal")
	assert_eq(mail.accepted_research(), ["watering_efficiency"] as Array[String], "now on the research list")
	assert_eq(sim.execute({"type": "mail.claim", "id": id})["reason"], "err.already_claimed", "only once")


func test_claiming_unread_marks_it_read() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	prog.add_mastery("farm", 100)
	sim.execute({"type": "mail.claim", "id": mail.letters[0]["id"]})
	assert_true(int(mail.letters[0]["read_ms"]) >= 0, "accepting means it was read")


func test_letters_survive_a_save_and_are_not_sent_again() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	sim.advance_ms(250000)
	sim.execute({"type": "mail.read", "id": 1})
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var m2: MailSystem = copy.system(&"mail")
	assert_eq(JSON.stringify(m2.letters), JSON.stringify(mail.letters), "letters with their state")
	assert_eq(m2.work, mail.work, "Momo experience")
	assert_eq(typeof(m2.letters[0]["id"]), TYPE_INT, "ids come back as integers")
	for s: Simulation in [sim, copy]:
		s.advance_ms(30000 * 30)
	assert_eq(JSON.stringify(m2.letters), JSON.stringify(mail.letters), "and the same letters afterwards, none repeated")


func test_an_old_save_without_mail_loads_and_does_not_flood() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	prog.add_mastery("farm", 100000)
	var state := sim.save_state()
	(state["systems"] as Dictionary).erase("mail")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(state)))
	var m2: MailSystem = copy.system(&"mail")
	assert_eq(m2.letters.size(), 0, "no mail in the old save")
	copy.advance_ms(30000 * 3)
	var days := m2.letters.map(func(l: Dictionary) -> int: return int(l["day"]))
	assert_eq(days.size(), 2, "both passed milestones arrive (%s)" % [days])
	assert_ne(days[0], days[1], "but on different days, not as a pile")


func test_same_letters_whatever_the_step_size() -> void:
	var out: Array = []
	for chunk: int in [16, 1000, 9999]:
		var s := Simulation.new_game()
		var f := (s.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
		s.execute({"type": "momo.assign", "momo": 1, "building": f})
		var t := 0
		while t < 30000 * 40:
			var step := mini(chunk, 30000 * 40 - t)
			s.advance_ms(step)
			t += step
		out.append(JSON.stringify((s.system(&"mail") as MailSystem).letters))
	assert_eq(out[1], out[0], "1 s steps")
	assert_eq(out[2], out[0], "10 s steps")
	assert_true(out[0].contains("farm_watering"), "a long unattended run reaches the mastery letters too")


func test_bad_letter_data_is_refused() -> void:
	var data := GameData.from_tables({"letters": {"letters": [
		{"id": "a", "industry": "farm", "trigger": {"work": {"farm": 5}}, "title": "t", "body": "b", "research": "r"},
		{"id": "a", "industry": "spaceport", "trigger": {"magic": {}}, "title": "", "body": "b", "research": "r"},
	]}})
	var text := "\n".join(data.errors)
	assert_true(text.contains("unique id"), "duplicate ids")
	assert_true(text.contains("not a building type"), "unknown industry")
	assert_true(text.contains("exactly one of"), "unknown trigger")
	assert_true(text.contains("title missing"), "missing text")


func test_every_letter_is_short_and_in_every_language() -> void:
	var letters: Array = GameData.load_default().table("letters")["letters"]
	assert_true(letters.size() >= 3, "farm letters")
	for code: String in ["en", "ko", "ja", "zh_CN"]:
		TranslationServer.set_locale(code)
		for l: Dictionary in letters:
			for k: String in [String(l["title"]), String(l["body"]), "research.%s.name" % l["research"]]:
				assert_ne(TranslationServer.translate(k), k, "%s has %s" % [code, k])
			var body := TranslationServer.translate(String(l["body"]))
			assert_between(float(body.split("\n").size()), 2.0, 4.0, "%s %s: a few short lines" % [code, l["id"]])
			assert_true(body.length() <= 200, "%s %s: concise (%d chars)" % [code, l["id"], body.length()])
	TranslationServer.set_locale("en")
