class_name MomoMood
extends RefCounted

## Why a Momo is not at work right now, read from the real job rules -- the
## same questions JobSystem.dispatch asks -- and the one small mood that says
## it (Step 48). Pure: a function of the simulation, never saved, the same
## after a load.
##
##   reason    when                                                   mood
##   (none)    working, walking, asleep at night, or with a job it     --
##             could start this moment (the dispatcher is on it)
##   free      no building and no watched tiles: its free time        content
##   waiting   what it watches is growing, cooling down, being built,  thinking
##             worked by another Momo, or running by itself
##   no_work   it watches tiles with nothing on them                  confused
##   short     an input is missing from the store                     worried
##   full      the store has no room for what it would make           worried
##   crew      the building needs more hands than it has              worried
##   power     not enough power                                       worried

const MOODS := {"free": "content", "waiting": "thinking", "no_work": "confused",
	"short": "worried", "full": "worried", "crew": "worried", "power": "worried"}
## When the buildings a Momo watches disagree, the one most worth the
## player's attention wins.
const PRIORITY: PackedStringArray = ["power", "short", "full", "crew", "no_work", "waiting", "free"]


static func reason(sim: Simulation, id: int) -> String:
	var momos: MomoSystem = sim.system(&"momo")
	var jobs: JobSystem = sim.system(&"jobs")
	var m := momos.get_momo(id)
	if m.is_empty() or momos.is_moving(id) or jobs.resting() or jobs.is_working(id):
		return ""
	# A Momo not at work at night is drawn asleep: the z's say it.
	if _night(sim):
		return ""
	if (m.get("watch", []) as Array).is_empty() and int(m.get("assigned", 0)) == 0:
		return "free"
	var watched := jobs.watched_buildings(id)
	if watched.is_empty():
		return "no_work"
	var best := ""
	for b: int in watched:
		var r := _building_reason(sim, jobs, id, b)
		if r == "":
			return ""
		if best == "" or PRIORITY.find(r) < PRIORITY.find(best):
			best = r
	return best


static func mood(sim: Simulation, id: int) -> String:
	return String(MOODS.get(reason(sim, id), ""))


static var _cycle: DayCycle
static var _cycle_data: GameData


static func _night(sim: Simulation) -> bool:
	if _cycle == null or _cycle_data != sim.data:
		_cycle = DayCycle.new(sim.data)
		_cycle_data = sim.data
	return _cycle.is_night(sim.clock)


## What keeps one watched building from being this Momo's job now.
static func _building_reason(sim: Simulation, jobs: JobSystem, momo: int, building: int) -> String:
	if jobs.open_for(momo, building):
		return ""
	var r := (sim.system(&"buildings") as BuildingSystem).can_start(building)
	if r["ok"]:
		# It could start, but not by this Momo: no place left, or it runs by itself.
		return "waiting"
	match String(r["reason"]):
		"err.no_power":
			return "power"
		"err.missing_inputs":
			return "short"
		"err.storage_full":
			return "full"
		"err.needs_crew":
			return "crew"
	return "waiting"
