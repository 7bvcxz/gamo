class_name MailSystem
extends SimSystem

## Momo Letters: an assigned Momo writes the player an improvement proposal
## when its industry reaches a real milestone (data/letters.json).
##
## Step 57: a letter's research is discovered the moment the letter arrives --
## reading it is for the story, never a gate. Research letters come slower: a
## letter's own milestone, at most `balance.mail.letters_per_day` a day, and
## at least `balance.mail.research_gap_seconds` of game time after the last
## research letter. A letter without `research` is just a letter.
##
## Milestones are counted, not timed: Momo-done work stages per building type
## (the player's own taps do not count -- these are the Momo's experience) and
## building mastery levels. Each letter is written once, ever; at most
## `balance.mail.letters_per_day` arrive on one day, so milestones reached
## together come on the following days rather than as a pile. A milestone met
## with nobody assigned to that industry waits until someone is.
##
## Considered on the events that can change the answer -- a Momo finishing a
## stage, a mastery level, an assignment, a new day -- never polled.

## Letters in the order written: {id, template, sender, sender_name, industry,
## title, body, research ("" for a plain letter), written_ms, day, read_ms (-1
## unread), claimed_ms (-1; saves before Step 57 recorded an acceptance here)}.
var letters: Array = []
var next_id := 1
## template id -> letter id, so nothing is ever written twice.
var written: Dictionary = {}
## building type -> work stages Momo have finished there.
var work: Dictionary = {}
## momo id -> {building type -> stages}, to pick the most experienced sender.
var work_by_momo: Dictionary = {}
var last_day := 0
var today_count := 0
## When the last research letter was written (-1: none yet).
var last_research_ms := -1


func _init() -> void:
	key = &"mail"


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["mail.read"])


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	p_sim.bus.emitted.connect(_on_event)


func on_new_game() -> void:
	letters.clear()
	next_id = 1
	written.clear()
	work.clear()
	work_by_momo.clear()
	last_day = 0
	today_count = 0
	last_research_ms = -1


func _on_event(type: StringName, payload: Dictionary) -> void:
	match type:
		&"task_completed":
			var worker := int(payload.get("worker", 0))
			if worker <= 0:
				return
			var t := String(payload.get("type", ""))
			work[t] = int(work.get(t, 0)) + 1
			var mine: Dictionary = work_by_momo.get(worker, {})
			mine[t] = int(mine.get(t, 0)) + 1
			work_by_momo[worker] = mine
			consider()
		&"mastery_up", &"momo_assigned":
			consider()


func on_day_started(_day: int) -> void:
	consider()


## Writes the first letter whose milestone is met and whose industry has an
## assigned Momo, if today still has room (and, for a research letter, the
## gap since the last one has passed). Returns the new letter id or 0.
func consider() -> int:
	var day := sim.clock.day_number()
	if day != last_day:
		last_day = day
		today_count = 0
	if today_count >= sim.data.get_int("balance", "mail.letters_per_day", 1):
		return 0
	for l: Dictionary in sim.data.table("letters").get("letters", []):
		if written.has(String(l["id"])) or not milestone_met(l):
			continue
		if String(l.get("research", "")) != "" and research_gap_left_ms() > 0:
			continue
		var sender := sender_for(String(l["industry"]))
		if sender == 0:
			continue
		return _write(l, sender)
	return 0


func milestone_met(l: Dictionary) -> bool:
	var trigger: Dictionary = l.get("trigger", {})
	for t: String in trigger.get("work", {}):
		if int(work.get(t, 0)) < int(trigger["work"][t]):
			return false
	var prog: ProgressionSystem = sim.system(&"progression")
	for t: String in trigger.get("mastery", {}):
		if int(prog.mastery_of(t)["level"]) < int(trigger["mastery"][t]):
			return false
	return not trigger.is_empty()


## The Momo assigned to a building of this type who has worked it most (ties
## to the lowest id), or 0 when nobody works that industry.
func sender_for(industry: String) -> int:
	var momos: MomoSystem = sim.system(&"momo")
	var buildings: BuildingSystem = sim.system(&"buildings")
	var best := 0
	var best_work := -1
	for id: int in momos.ids():
		var b := buildings.get_building(int(momos.get_momo(id)["assigned"]))
		if b.is_empty() or String(b["type"]) != industry:
			continue
		var done := int((work_by_momo.get(id, {}) as Dictionary).get(industry, 0))
		if done > best_work:
			best = id
			best_work = done
	return best


## Game time until the next research letter may come (0: it may now).
func research_gap_left_ms() -> int:
	if last_research_ms < 0:
		return 0
	var gap := int(sim.data.get_float("balance", "mail.research_gap_seconds", 0.0) * 1000.0)
	return maxi(last_research_ms + gap - sim.now_ms(), 0)


## Every research the letters have brought, in the order they came (Step 57:
## arriving is enough -- ResearchSystem reads this for `unlock.proposal`).
func discovered_research() -> Array[String]:
	var out: Array[String] = []
	for l: Dictionary in letters:
		var r := String(l.get("research", ""))
		if r != "" and not out.has(r):
			out.append(r)
	return out


func _write(l: Dictionary, sender: int) -> int:
	var id := next_id
	next_id += 1
	var momo := (sim.system(&"momo") as MomoSystem).get_momo(sender)
	letters.append({
		"id": id, "template": String(l["id"]), "sender": sender, "sender_name": String(momo.get("name", "")),
		"industry": String(l["industry"]), "title": String(l["title"]), "body": String(l["body"]),
		"research": String(l.get("research", "")), "written_ms": sim.now_ms(), "day": sim.clock.day_number(),
		"read_ms": -1, "claimed_ms": -1,
	})
	written[String(l["id"])] = id
	today_count += 1
	if String(l.get("research", "")) != "":
		last_research_ms = sim.now_ms()
	sim.bus.emit(&"letter_written", {"id": id, "sender": sender, "template": String(l["id"]), "research": String(l.get("research", ""))})
	return id


func get_letter(id: int) -> Dictionary:
	for l: Dictionary in letters:
		if int(l["id"]) == id:
			return l
	return {}


func unread_count() -> int:
	return letters.filter(func(l: Dictionary) -> bool: return int(l["read_ms"]) < 0).size()


func has_unread_from(momo: int) -> bool:
	return letters.any(func(l: Dictionary) -> bool: return int(l["sender"]) == momo and int(l["read_ms"]) < 0)


## Reading a letter only marks it read: what it proposes is already
## discovered (Step 57 removed the "accept" step it used to need).
func execute(command: Dictionary) -> Dictionary:
	var l := get_letter(int(command.get("id", 0)))
	if l.is_empty():
		return SimResult.fail("err.no_letter")
	match String(command.get("type", "")):
		"mail.read":
			if int(l["read_ms"]) < 0:
				l["read_ms"] = sim.now_ms()
				sim.bus.emit(&"letter_read", {"id": l["id"]})
			return SimResult.ok()
	return SimResult.fail("err.unknown_command")


func save_state() -> Dictionary:
	var by_momo := {}
	for id: int in work_by_momo:
		by_momo[str(id)] = (work_by_momo[id] as Dictionary).duplicate()
	return {"letters": letters.duplicate(true), "next_id": next_id, "written": written.duplicate(),
		"work": work.duplicate(), "work_by_momo": by_momo, "last_day": last_day, "today_count": today_count,
		"last_research_ms": last_research_ms}


func load_state(state: Dictionary) -> void:
	on_new_game()
	for l: Dictionary in state.get("letters", []):
		var c := l.duplicate()
		for k: String in ["id", "sender", "written_ms", "day", "read_ms", "claimed_ms"]:
			c[k] = int(c.get(k, -1))
		letters.append(c)
	next_id = int(state.get("next_id", 1))
	var w: Dictionary = state.get("written", {})
	for k: String in w:
		written[k] = int(w[k])
	var wk: Dictionary = state.get("work", {})
	for k: String in wk:
		work[k] = int(wk[k])
	var bm: Dictionary = state.get("work_by_momo", {})
	for k: String in bm:
		var per := {}
		for t: String in bm[k]:
			per[t] = int(bm[k][t])
		work_by_momo[int(k)] = per
	last_day = int(state.get("last_day", 0))
	today_count = int(state.get("today_count", 0))
	# Saves before Step 57: the last research letter written, if any.
	last_research_ms = int(state.get("last_research_ms", -1))
	if not state.has("last_research_ms"):
		for l: Dictionary in letters:
			if String(l.get("research", "")) != "":
				last_research_ms = maxi(last_research_ms, int(l["written_ms"]))
