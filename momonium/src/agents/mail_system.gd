class_name MailSystem
extends SimSystem

## Momo Letters: an assigned Momo writes the player an improvement proposal
## when its industry reaches a real milestone (data/letters.json).
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
## title, body, research, written_ms, day, read_ms (-1 unread), claimed_ms (-1)}.
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


func _init() -> void:
	key = &"mail"


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["mail.read", "mail.claim"])


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


func _on_event(type: StringName, payload: Dictionary) -> void:
	match type:
		&"task_completed":
			var worker := int(payload.get("worker", 0))
			if worker == 0:
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
## assigned Momo, if today still has room. Returns the new letter id or 0.
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


func _write(l: Dictionary, sender: int) -> int:
	var id := next_id
	next_id += 1
	var momo := (sim.system(&"momo") as MomoSystem).get_momo(sender)
	letters.append({
		"id": id, "template": String(l["id"]), "sender": sender, "sender_name": String(momo.get("name", "")),
		"industry": String(l["industry"]), "title": String(l["title"]), "body": String(l["body"]),
		"research": String(l["research"]), "written_ms": sim.now_ms(), "day": sim.clock.day_number(),
		"read_ms": -1, "claimed_ms": -1,
	})
	written[String(l["id"])] = id
	today_count += 1
	sim.bus.emit(&"letter_written", {"id": id, "sender": sender, "template": String(l["id"])})
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


## Research the player said yes to, in the order accepted (Step 22 reads this).
func accepted_research() -> Array[String]:
	var out: Array[String] = []
	var claimed := letters.filter(func(l: Dictionary) -> bool: return int(l["claimed_ms"]) >= 0)
	claimed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["claimed_ms"]) < int(b["claimed_ms"]) or (int(a["claimed_ms"]) == int(b["claimed_ms"]) and int(a["id"]) < int(b["id"])))
	for l: Dictionary in claimed:
		if not out.has(String(l["research"])):
			out.append(String(l["research"]))
	return out


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
		"mail.claim":
			if int(l["claimed_ms"]) >= 0:
				return SimResult.fail("err.already_claimed")
			if int(l["read_ms"]) < 0:
				l["read_ms"] = sim.now_ms()
				sim.bus.emit(&"letter_read", {"id": l["id"]})
			l["claimed_ms"] = sim.now_ms()
			sim.bus.emit(&"letter_claimed", {"id": l["id"], "research": l["research"]})
			return SimResult.ok({"research": l["research"]})
	return SimResult.fail("err.unknown_command")


func save_state() -> Dictionary:
	var by_momo := {}
	for id: int in work_by_momo:
		by_momo[str(id)] = (work_by_momo[id] as Dictionary).duplicate()
	return {"letters": letters.duplicate(true), "next_id": next_id, "written": written.duplicate(),
		"work": work.duplicate(), "work_by_momo": by_momo, "last_day": last_day, "today_count": today_count}


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
