class_name JourneySystem
extends SimSystem

## The island's journey: when each first happened -- the first farm built,
## harvest, sale (the first income), a Momo's first earnings, Momo at work, land, hire,
## research started and done, letter, the levels in
## `balance.journey.levels`, each tier -- kept three ways, because a player
## counts time three ways: played (the game open), offline (time away the
## island caught up on), and wall time since the island began (both, plus
## time away beyond what a catch-up counts).
##
## The simulation clock already holds played + offline; the journey keeps how
## much of it was offline (`offline_ms`) and how much time away went uncounted
## (`lost_ms`), told by OfflineProgress. Firsts reached while catching up are
## dated inside the absence. It reads the bus only and changes nothing.

const MOMO_WORK_MIN := 1

## [{"key", "at_ms", "offline_ms", "lost_ms"}] in the order they happened.
var marks: Array[Dictionary] = []
var offline_ms := 0
var lost_ms := 0
## Sim time the current catch-up began at, or -1 while playing.
var _away_from := -1


func _init() -> void:
	key = &"journey"


func setup(p_sim: Simulation) -> void:
	super.setup(p_sim)
	p_sim.bus.emitted.connect(_on_event)


func on_new_game() -> void:
	marks.clear()
	offline_ms = 0
	lost_ms = 0
	_away_from = -1


## OfflineProgress: time away is about to be caught up on.
func begin_away() -> void:
	_away_from = sim.now_ms()


## OfflineProgress: `away_ms` were away, of which `counted_ms` the island ran.
func end_away(away_ms: int, counted_ms: int) -> void:
	offline_ms += maxi(counted_ms, 0)
	lost_ms += maxi(away_ms - counted_ms, 0)
	_away_from = -1


func _on_event(type: StringName, p: Dictionary) -> void:
	match type:
		&"building_built":
			var bs: BuildingSystem = sim.system(&"buildings")
			var t := String(p.get("type", ""))
			_mark("built:" + ("special" if bs.is_special(t) else bs.family_of(t)))
		&"task_completed":
			if String(p.get("stage", "")) == "harvest":
				_mark("harvest")
			if int(p.get("worker", 0)) >= MOMO_WORK_MIN:
				_mark("momo_work")
		&"sold", &"released":
			# Every sale is finished work paying at once (Step 50): the first
			# sale is the first income; a Momo's own first earnings too.
			_mark("sale")
			if int(p.get("worker", 0)) >= MOMO_WORK_MIN and int(p.get("money", 0)) > 0:
				_mark("momo_income")
		&"research_started":
			_mark("research_start")
		&"land_bought":
			_mark("land")
		&"momo_hired":
			_mark("hire")
		&"research_completed":
			_mark("research")
		&"letter_written":
			_mark("letter")
		&"level_up":
			var lv := int(p.get("level", 0))
			for n: Variant in sim.data.get_value("balance", "journey.levels", []):
				if int(n) == lv:
					_mark("level:%d" % lv)
		&"tier_promoted":
			_mark("tier:%d" % int(p.get("tier", 0)))


func _mark(k: String) -> void:
	for m: Dictionary in marks:
		if m["key"] == k:
			return
	var now := sim.now_ms()
	var off := offline_ms + (now - _away_from if _away_from >= 0 else 0)
	marks.append({"key": k, "at_ms": now, "offline_ms": off, "lost_ms": lost_ms})
	sim.bus.emit(&"journey_marked", {"key": k})


# --- reading -----------------------------------------------------------------------------

## Time on this island: {"played_ms", "offline_ms", "wall_ms"}.
func totals() -> Dictionary:
	var now := sim.now_ms()
	return {"played_ms": now - offline_ms, "offline_ms": offline_ms, "wall_ms": now + lost_ms}


## A first, with its three times: {"key", "played_ms", "offline_ms", "wall_ms"}.
func timeline() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in marks:
		var at := int(m["at_ms"])
		out.append({"key": m["key"], "played_ms": at - int(m["offline_ms"]), "offline_ms": int(m["offline_ms"]), "wall_ms": at + int(m["lost_ms"])})
	return out


func when(k: String) -> Dictionary:
	for e: Dictionary in timeline():
		if e["key"] == k:
			return e
	return {}


func save_state() -> Dictionary:
	return {"marks": marks.duplicate(true), "offline_ms": offline_ms, "lost_ms": lost_ms}


## Saves from before the journey start with an empty one: firsts are kept
## from the moment it is loaded.
func load_state(state: Dictionary) -> void:
	on_new_game()
	offline_ms = maxi(int(state.get("offline_ms", 0)), 0)
	lost_ms = maxi(int(state.get("lost_ms", 0)), 0)
	for raw: Variant in state.get("marks", []):
		if typeof(raw) != TYPE_DICTIONARY or not (raw as Dictionary).has("key"):
			continue
		marks.append({"key": String(raw["key"]), "at_ms": int(raw.get("at_ms", 0)), "offline_ms": int(raw.get("offline_ms", 0)), "lost_ms": int(raw.get("lost_ms", 0))})
