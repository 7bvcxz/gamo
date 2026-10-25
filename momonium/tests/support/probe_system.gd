extends SimSystem

## A test-only system that records every event and day it sees, so tests can
## compare whole histories rather than single values.

var history: Array[String] = []


func _init() -> void:
	key = &"probe"


func handled_events() -> PackedStringArray:
	return PackedStringArray(["probe.ping"])


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["probe.schedule"])


func handle_event(type: String, data: Dictionary) -> void:
	history.append("%d:%s:%s" % [sim.now_ms(), type, data.get("tag", "")])
	if int(data.get("repeat", 0)) > 0:
		sim.schedule_in(int(data["every"]), "probe.ping", {"tag": data["tag"], "repeat": int(data["repeat"]) - 1, "every": data["every"]})


func execute(command: Dictionary) -> Dictionary:
	sim.schedule_in(int(command["delay"]), "probe.ping", command.get("data", {}))
	return SimResult.ok()


func on_day_started(day: int) -> void:
	history.append("%d:day:%d" % [sim.now_ms(), day])


func save_state() -> Dictionary:
	return {"history": history.duplicate()}


func load_state(state: Dictionary) -> void:
	history.clear()
	for line: String in state.get("history", []):
		history.append(line)
