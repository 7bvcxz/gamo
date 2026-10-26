extends "res://tests/framework/test_case.gd"

## Momo Letters: written by an assigned Momo at real milestones, once each,
## no more than one a day, research letters at least the data's gap apart
## (Step 57), kept with their read state across saves. A letter's research is
## discovered when it arrives -- there is nothing to accept.

var sim: Simulation
var mail: MailSystem
var buildings: BuildingSystem
var prog: ProgressionSystem
var farm := 0


func before_each() -> void:
	sim = with_starter_momo(Simulation.new_game())
	mail = sim.system(&"mail")
	buildings = sim.system(&"buildings")
	prog = sim.system(&"progression")
	farm = buildings.place_instant("farm", Vector2i(1, 0))


func _harvest_by_hand(times: int) -> void:
	for i in times:
		for st in buildings.stages(buildings.get_building(farm)).size():
			var b := buildings.get_building(farm)
			if b["state"] != BuildingSystem.IDLE:
				sim.advance_ms(buildings.remaining_ms(b))
			sim.execute({"type": "building.tap", "id": farm})
			sim.advance_ms(buildings.remaining_ms(b))


func test_enough_unattended_farm_work_brings_one_letter() -> void:
	# The letter's milestone: this many farm stages done by Momo (Step 57: 10).
	var need := int(GameData.load_default().table("letters")["letters"][0]["trigger"]["work"]["farm"])
	assert_true(need >= 10, "a real stretch of work, not the first harvest (%d)" % need)
	var reached := [0]
	var done := [0]
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"task_completed" and int(p.get("worker", 0)) > 0 and String(p.get("type", "")) == "farm":
			done[0] += 1
			if done[0] == need:
				reached[0] = clock.now_ms)
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	var waited := 0
	while mail.letters.is_empty() and waited < 250000:
		sim.advance_ms(100)
		waited += 100
	assert_eq(mail.letters.size(), 1, "one letter")
	var l: Dictionary = mail.letters[0]
	assert_eq(l["template"], "farm_first_harvest", "about the harvests Momo brought in alone")
	assert_eq(l["sender"], 1, "from the Momo who did it")
	assert_eq(l["sender_name"], "momo.name.0", "signed with its name")
	assert_eq(l["industry"], "farm", "the farm industry")
	assert_eq(l["research"], "farm_expansion", "proposing field expansion")
	assert_eq(l["title"], "letter.farm_first_harvest.title", "title key")
	assert_eq(l["body"], "letter.farm_first_harvest.body", "explanation key")
	assert_eq(l["written_ms"], reached[0], "written the moment the %dth Momo stage was done" % need)
	assert_eq(l["day"], 1 + reached[0] / sim.clock.day_ms, "dated with the day it was written")
	assert_eq(l["read_ms"], -1, "unread")
	assert_eq(mail.unread_count(), 1, "one unread")
	assert_eq(mail.discovered_research(), ["farm_expansion"] as Array[String], "its research discovered on arrival, unread")
	sim.advance_ms(30000 * 20)
	assert_eq(mail.letters.filter(func(x: Dictionary) -> bool: return x["template"] == "farm_first_harvest").size(), 1, "never written twice")


func test_the_players_own_work_does_not_count() -> void:
	_harvest_by_hand(12)
	assert_true(int(prog.mastery_of("farm")["level"]) >= 2, "farm mastery reached Lv 2 by hand")
	assert_eq(mail.letters.size(), 0, "but nobody works the farm: no letter")
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	assert_eq(mail.letters.size(), 1, "assigning a Momo there brings the letter that was waiting")
	assert_eq(mail.letters[0]["template"], "farm_watering", "the mastery letter -- Momo has done no work yet")
	assert_eq(int(mail.work.get("farm", 0)), 0, "the player's stages are not Momo experience")


func test_research_letters_keep_their_gap() -> void:
	var gap_ms := int(sim.data.get_float("balance", "mail.research_gap_seconds", 0.0) * 1000.0)
	assert_true(gap_ms >= sim.clock.day_ms * 3, "the gap is days of play, not a moment (%d ms)" % gap_ms)
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	prog.add_mastery("farm", 100000)
	assert_true(int(prog.mastery_of("farm")["level"]) >= 3, "mastery jumped past two milestones at once")
	assert_eq(mail.letters.size(), 1, "only one letter now")
	assert_eq(mail.letters[0]["template"], "farm_watering", "the first of them in data order")
	var first_ms: int = mail.letters[0]["written_ms"]
	sim.advance_to(sim.clock.next_day_start_ms() + 1)
	assert_eq(mail.letters.size(), 1, "not tomorrow: the gap has not passed")
	assert_true(mail.research_gap_left_ms() > 0, "and it says how long is left")
	sim.advance_to(first_ms + gap_ms + sim.clock.day_ms)
	assert_eq(mail.letters.size(), 2, "the next one once the gap is over")
	assert_true(int(mail.letters[1]["written_ms"]) >= first_ms + gap_ms, "not before it")
	sim.advance_ms(gap_ms * 3)
	# The Momo's own farm work is a milestone too: three letters in all, each
	# once, each at least the gap after the one before.
	var templates: Array = mail.letters.map(func(l: Dictionary) -> String: return String(l["template"]))
	templates.sort()
	assert_eq(templates, ["farm_first_harvest", "farm_soil", "farm_watering"], "each farm letter once")
	for i in range(1, mail.letters.size()):
		assert_true(int(mail.letters[i]["written_ms"]) - int(mail.letters[i - 1]["written_ms"]) >= gap_ms, "each the gap apart")


func test_at_most_one_letter_a_day_without_a_gap() -> void:
	var b: Dictionary = GameData.load_default().table("balance").duplicate(true)
	b["mail"]["research_gap_seconds"] = 0
	sim = with_starter_momo(Simulation.new_game(GameData.from_tables({"balance": b})))
	mail = sim.system(&"mail")
	prog = sim.system(&"progression")
	farm = (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	prog.add_mastery("farm", 100000)
	assert_eq(mail.letters.size(), 1, "only one letter today")
	var first_day: int = mail.letters[0]["day"]
	sim.advance_to(sim.clock.next_day_start_ms() + 1)
	assert_eq(mail.letters.size(), 2, "the next one tomorrow: the gap is data")
	assert_eq(mail.letters[1]["day"], first_day + 1, "on the following day")


func test_the_most_experienced_assigned_momo_writes() -> void:
	var b: Dictionary = GameData.load_default().table("buildings").duplicate(true)
	b["types"]["farm"]["workers"] = 2
	sim = with_starter_momo(Simulation.new_game(GameData.from_tables({"buildings": b})))
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


func test_reading_is_only_reading() -> void:
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	prog.add_mastery("farm", 100)
	var id: int = mail.letters[0]["id"]
	assert_eq(mail.discovered_research(), ["watering_efficiency"] as Array[String], "discovered before it is read")
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
	assert_false(sim.execute({"type": "mail.claim", "id": id})["ok"], "there is no accepting any more")
	assert_eq(mail.discovered_research(), ["watering_efficiency"] as Array[String], "and nothing changed by reading")


func test_a_letter_without_research_is_just_a_letter() -> void:
	var l: Dictionary = GameData.load_default().table("letters").duplicate(true)
	l["letters"] = [{"id": "hello", "industry": "farm", "trigger": {"work": {"farm": 1}}, "title": "t", "body": "b"}]
	var data := GameData.from_tables({"letters": l})
	assert_false("\n".join(data.errors).contains("letters:"), "valid data (%s)" % [data.errors])


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
	var gap_ms := int(copy.data.get_float("balance", "mail.research_gap_seconds", 0.0) * 1000.0)
	copy.advance_ms(gap_ms + 30000 * 3)
	var days := m2.letters.map(func(l: Dictionary) -> int: return int(l["day"]))
	assert_true(days.size() >= 2, "the passed milestones arrive (%s)" % [days])
	for i in range(1, days.size()):
		assert_ne(days[i], days[i - 1], "but on different days, not as a pile")


func test_same_letters_whatever_the_step_size() -> void:
	var out: Array = []
	for chunk: int in [16, 1000, 9999]:
		var s := with_starter_momo(Simulation.new_game())
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
			var keys: Array[String] = [String(l["title"]), String(l["body"])]
			if String(l.get("research", "")) != "":
				keys.append("research.%s.name" % l["research"])
			for k: String in keys:
				assert_ne(TranslationServer.translate(k), k, "%s has %s" % [code, k])
			var body := TranslationServer.translate(String(l["body"]))
			assert_between(float(body.split("\n").size()), 2.0, 4.0, "%s %s: a few short lines" % [code, l["id"]])
			assert_true(body.length() <= 200, "%s %s: concise (%d chars)" % [code, l["id"], body.length()])
	TranslationServer.set_locale("en")
