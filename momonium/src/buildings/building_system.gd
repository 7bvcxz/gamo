class_name BuildingSystem
extends SimSystem

## Buildings on the island and the work they do.
##
## Every building type has a work cycle in data (buildings.json): stages done
## in order, each taking `seconds` of active work, each optionally followed by
## a `cooldown` that must pass before the next stage can start. A building is
## idle (ready for its next stage), working (a stage is in progress) or cooling
## down. Tapping a ready building starts its stage at once; the stage finishes
## by itself at its end time, whatever the player does next -- selecting
## another building, panning away or closing the game (Step 24 replays it).
##
## Ends of work are scheduled events carrying a token. Anything that changes a
## building's plans bumps its token, so a stale event finds a mismatch and does
## nothing: cancellation without searching the queue.

const TASK_DONE := "building.task_done"
const COOLDOWN_DONE := "building.cooldown_done"

const IDLE := "idle"
const WORKING := "working"
const COOLDOWN := "cooldown"

## id -> record (plain data, saved as-is):
##   id, type, anchor [x, y], state, stage (index of the stage being done or next),
##   task_start, task_end, ready_at (ms), token, completed (stages finished)
var buildings: Dictionary = {}
var next_id := 1


func _init() -> void:
	key = &"buildings"


func handled_events() -> PackedStringArray:
	return PackedStringArray([TASK_DONE, COOLDOWN_DONE])


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["building.tap"])


func on_new_game() -> void:
	buildings.clear()
	next_id = 1


# --- queries ----------------------------------------------------------------------

func get_building(id: int) -> Dictionary:
	return buildings.get(id, {})


func type_def(b: Dictionary) -> Dictionary:
	return sim.data.building_type(b.get("type", ""))


func stages(b: Dictionary) -> Array:
	return type_def(b).get("cycle", {}).get("stages", [])


func current_stage(b: Dictionary) -> Dictionary:
	var list := stages(b)
	return list[int(b["stage"]) % list.size()] if not list.is_empty() else {}


func building_at(cell: Vector2i) -> int:
	var world: WorldSystem = sim.system(&"world")
	var id := world.occupant(cell)
	return id if buildings.has(id) else 0


func cells_of(b: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var anchor := Vector2i(int(b["anchor"][0]), int(b["anchor"][1]))
	var size := _size(b["type"])
	for y in size.y:
		for x in size.x:
			out.append(anchor + Vector2i(x, y))
	return out


func is_ready(b: Dictionary) -> bool:
	return b["state"] == IDLE


## Fraction of the current stage done (0..1) while working; 0 otherwise.
func progress(b: Dictionary) -> float:
	if b["state"] != WORKING:
		return 0.0
	var span := maxi(int(b["task_end"]) - int(b["task_start"]), 1)
	return clampf(float(sim.now_ms() - int(b["task_start"])) / span, 0.0, 1.0)


## Milliseconds until the building can be tapped again (0 when ready).
func remaining_ms(b: Dictionary) -> int:
	match b["state"]:
		WORKING:
			return maxi(int(b["task_end"]) - sim.now_ms(), 0)
		COOLDOWN:
			return maxi(int(b["ready_at"]) - sim.now_ms(), 0)
	return 0


func ids() -> Array[int]:
	var out: Array[int] = []
	for id: int in buildings:
		out.append(id)
	out.sort()
	return out


# --- changes ----------------------------------------------------------------------

## Puts a finished building on the map with no cost or construction time.
## Construction (Step 13) builds on this; tests and the browser bridge use it
## directly. Returns the new id, or 0 if the cells are not free.
func place_instant(type: String, anchor: Vector2i) -> int:
	if sim.data.building_type(type).is_empty():
		return 0
	var world: WorldSystem = sim.system(&"world")
	var b := {"id": next_id, "type": type, "anchor": [anchor.x, anchor.y], "state": IDLE, "stage": 0,
		"task_start": 0, "task_end": 0, "ready_at": 0, "token": 0, "completed": 0}
	if not world.occupy(cells_of(b), next_id):
		return 0
	buildings[next_id] = b
	next_id += 1
	sim.bus.emit(&"building_added", {"id": b["id"], "type": type})
	return b["id"]


func execute(command: Dictionary) -> Dictionary:
	match String(command.get("type", "")):
		"building.tap":
			return tap(Cmd.integer(command, "id"))
	return SimResult.fail("err.unknown_command")


## Starts the building's current stage if it is ready.
func tap(id: int) -> Dictionary:
	if not buildings.has(id):
		return SimResult.fail("err.no_building")
	var b: Dictionary = buildings[id]
	if b["state"] == WORKING:
		return SimResult.fail("err.busy", {"remaining_ms": remaining_ms(b)})
	if b["state"] == COOLDOWN:
		return SimResult.fail("err.cooldown", {"remaining_ms": remaining_ms(b)})
	var stage := current_stage(b)
	var duration := int(round(float(stage.get("seconds", 1.0)) * 1000.0))
	b["state"] = WORKING
	b["task_start"] = sim.now_ms()
	b["task_end"] = sim.now_ms() + duration
	b["token"] = int(b["token"]) + 1
	sim.scheduler.schedule(int(b["task_end"]), TASK_DONE, {"id": id, "token": b["token"]})
	sim.bus.emit(&"task_started", {"id": id, "stage": stage.get("id", ""), "ends_ms": b["task_end"]})
	return SimResult.ok({"stage": stage.get("id", ""), "ends_ms": b["task_end"]})


func handle_event(type: String, data: Dictionary) -> void:
	var id := int(data.get("id", 0))
	if not buildings.has(id):
		return
	var b: Dictionary = buildings[id]
	if int(data.get("token", -1)) != int(b["token"]):
		return
	match type:
		TASK_DONE:
			_complete_stage(b)
		COOLDOWN_DONE:
			b["state"] = IDLE
			sim.bus.emit(&"building_ready", {"id": id})


func _complete_stage(b: Dictionary) -> void:
	var stage := current_stage(b)
	b["completed"] = int(b["completed"]) + 1
	b["stage"] = (int(b["stage"]) + 1) % maxi(stages(b).size(), 1)
	var cooldown := int(round(float(stage.get("cooldown", 0.0)) * 1000.0))
	if cooldown > 0:
		b["state"] = COOLDOWN
		b["ready_at"] = sim.now_ms() + cooldown
		b["token"] = int(b["token"]) + 1
		sim.scheduler.schedule(int(b["ready_at"]), COOLDOWN_DONE, {"id": b["id"], "token": b["token"]})
	else:
		b["state"] = IDLE
	sim.bus.emit(&"task_completed", {"id": b["id"], "stage": stage.get("id", ""), "type": b["type"]})


func _size(type: String) -> Vector2i:
	var s: Array = sim.data.building_type(type).get("size", [1, 1])
	return Vector2i(int(s[0]), int(s[1]))


# --- persistence --------------------------------------------------------------------

func save_state() -> Dictionary:
	var list: Array = []
	for id: int in ids():
		list.append(buildings[id].duplicate(true))
	return {"next_id": next_id, "buildings": list}


func load_state(state: Dictionary) -> void:
	buildings.clear()
	next_id = int(state.get("next_id", 1))
	for raw: Dictionary in state.get("buildings", []):
		var b := raw.duplicate(true)
		for k: String in ["id", "stage", "task_start", "task_end", "ready_at", "token", "completed"]:
			b[k] = int(b.get(k, 0))
		buildings[b["id"]] = b
