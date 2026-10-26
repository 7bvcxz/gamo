class_name Simulation
extends RefCounted

## The whole game world as rules and data, with no knowledge of the screen.
##
## Composition root: owns the data tables, the clock, the event queue, the bus
## and the systems. Everything that changes the world goes through `execute`
## (player intent) or the scheduler (time). Everything the world reports goes
## out through `bus`. A view may read state freely but never writes it.
##
## Time moves only through `advance_*`, which runs due events in (time, seq)
## order. Because nothing depends on frame boundaries, advancing 60 s in one
## call or in 3,600 small calls produces the same world.

## Version of the save format (SaveService wraps it; SaveMigration upgrades
## older ones). 2: the envelope with time saved and checksum (Step 24).
const SAVE_SCHEMA := 2
## Events handled since this Simulation was made (not saved; for budgets).
var events_processed := 0
const DAY_EVENT := "sim.day"

var data: GameData
var clock: SimClock
var scheduler: Scheduler
var bus: EventBus
## Real seconds -> simulated seconds. 1.0 in play; tests and E2E speed it up.
var time_scale: float = 1.0
## True while catching up on time away (OfflineProgress): the same rules run,
## but views do not celebrate each replayed event -- the welcome-back card
## sums them up instead. A presentation hint only; no rule reads it.
var replaying := false

var _systems: Array[SimSystem] = []
var _by_key: Dictionary = {}
var _event_handlers: Dictionary = {}
var _command_handlers: Dictionary = {}
var _remainder_ms: float = 0.0
## Scheduled events whose type no system claimed. Always a bug; tests read it.
var unhandled_events: Array[String] = []


func _init(p_data: GameData = null, systems: Array[SimSystem] = []) -> void:
	data = p_data if p_data != null else GameData.load_default()
	clock = SimClock.new(data.get_int("balance", "clock.day_seconds", 30) * 1000)
	scheduler = Scheduler.new()
	bus = EventBus.new()
	var list: Array[SimSystem] = systems if not systems.is_empty() else SystemRegistry.create_default()
	for s: SimSystem in list:
		register(s)


## A fresh world at Day 1, 00 s, with the starting rules from data.
static func new_game(p_data: GameData = null, systems: Array[SimSystem] = []) -> Simulation:
	var sim := Simulation.new(p_data, systems)
	sim.clock.now_ms = 0
	sim.scheduler.schedule(sim.clock.next_day_start_ms(), DAY_EVENT)
	for s: SimSystem in sim._systems:
		s.on_new_game()
	sim.bus.emit(&"game_started", {})
	return sim


## A player's new island: the fresh world above, plus what `balance.start`
## puts on it for a new player. Tests that want the bare rules use new_game.
static func new_island(p_data: GameData = null) -> Simulation:
	return new_game(p_data)


static func from_save(state: Dictionary, p_data: GameData = null, systems: Array[SimSystem] = []) -> Simulation:
	var sim := Simulation.new(p_data, systems)
	sim.load_state(state)
	sim.bus.emit(&"game_loaded", {})
	return sim


func register(s: SimSystem) -> void:
	assert(s.key != &"" and not _by_key.has(s.key), "system key must be unique")
	s.setup(self)
	_systems.append(s)
	_by_key[s.key] = s
	for type: String in s.handled_events():
		assert(not _event_handlers.has(type), "event %s claimed twice" % type)
		_event_handlers[type] = s
	for type: String in s.handled_commands():
		assert(not _command_handlers.has(type), "command %s claimed twice" % type)
		_command_handlers[type] = s


func system(key: StringName) -> SimSystem:
	return _by_key.get(key)


func systems() -> Array[SimSystem]:
	return _systems


func now_ms() -> int:
	return clock.now_ms


# --- time -------------------------------------------------------------------

## Advance by real elapsed seconds (the frame loop). Fractions of a millisecond
## are carried to the next call rather than dropped.
func advance_seconds(real_delta: float) -> void:
	_remainder_ms += real_delta * 1000.0 * time_scale
	var whole := int(floor(_remainder_ms))
	if whole <= 0:
		return
	_remainder_ms -= whole
	advance_to(clock.now_ms + whole)


func advance_ms(delta_ms: int) -> void:
	advance_to(clock.now_ms + delta_ms)


func advance_to(target_ms: int) -> void:
	while not scheduler.is_empty() and scheduler.peek_time() <= target_ms:
		var event: Dictionary = scheduler.pop()
		clock.now_ms = maxi(clock.now_ms, int(event["at"]))
		_dispatch(event)
		events_processed += 1
	clock.now_ms = maxi(clock.now_ms, target_ms)


## advance_to with a ceiling on how much work it may do: stops after
## `max_events` events, with the clock at the last event handled (not at the
## target), so a capped catch-up never claims time it did not simulate. The
## cap is a count, not wall-clock time, so the same save always reaches the
## same moment. Returns the time reached.
func advance_to_budget(target_ms: int, max_events: int) -> int:
	var handled := 0
	while not scheduler.is_empty() and scheduler.peek_time() <= target_ms:
		if handled >= max_events:
			# Everything due at this same instant still runs, so the world is
			# never left half-way through one moment.
			if scheduler.peek_time() > clock.now_ms:
				return clock.now_ms
		var event: Dictionary = scheduler.pop()
		clock.now_ms = maxi(clock.now_ms, int(event["at"]))
		_dispatch(event)
		events_processed += 1
		handled += 1
	clock.now_ms = maxi(clock.now_ms, target_ms)
	return clock.now_ms


func schedule_in(delay_ms: int, type: String, data_payload: Dictionary = {}) -> int:
	return scheduler.schedule(clock.now_ms + maxi(delay_ms, 0), type, data_payload)


func _dispatch(event: Dictionary) -> void:
	var type: String = event["type"]
	if type == DAY_EVENT:
		_on_day()
		return
	var handler: SimSystem = _event_handlers.get(type)
	if handler == null:
		unhandled_events.append(type)
		push_error("Simulation: no system handles event '%s'" % type)
		return
	handler.handle_event(type, event["data"])


func _on_day() -> void:
	var day := clock.day_number()
	scheduler.schedule(clock.next_day_start_ms(), DAY_EVENT)
	for s: SimSystem in _systems:
		s.on_day_started(day)
	bus.emit(&"day_started", {"day": day})


# --- intent -----------------------------------------------------------------

## The only way the player (or a test, or the browser bridge) changes the
## world. Returns SimResult: {"ok": bool, "reason": key, ...}.
func execute(command: Dictionary) -> Dictionary:
	var type := String(command.get("type", ""))
	var handler: SimSystem = _command_handlers.get(type)
	if handler == null:
		return SimResult.fail("err.unknown_command", {"type": type})
	return handler.execute(command)


func handles_command(type: String) -> bool:
	return _command_handlers.has(type)


# --- inspection ---------------------------------------------------------------

## A JSON-friendly picture of the world for tests, the browser bridge and
## debugging. Read-only; built from each system's saved state.
func snapshot() -> Dictionary:
	var out := {
		"now_ms": clock.now_ms,
		"day": clock.day_number(),
		"time_in_day_ms": clock.time_in_day_ms(),
		"day_ms": clock.day_ms,
		"pending_events": scheduler.size(),
	}
	for s: SimSystem in _systems:
		out[String(s.key)] = s.save_state()
	return out


# --- persistence --------------------------------------------------------------

func save_state() -> Dictionary:
	var systems_state := {}
	for s: SimSystem in _systems:
		systems_state[String(s.key)] = s.save_state()
	return {
		"schema": SAVE_SCHEMA,
		"clock": clock.save_state(),
		"scheduler": scheduler.save_state(),
		"systems": systems_state,
	}


func load_state(state: Dictionary) -> void:
	clock.load_state(state.get("clock", {}))
	scheduler.load_state(state.get("scheduler", {}))
	var systems_state: Dictionary = state.get("systems", {})
	for s: SimSystem in _systems:
		s.load_state(systems_state.get(String(s.key), {}))
	if scheduler.events_of(DAY_EVENT).is_empty():
		scheduler.schedule(clock.next_day_start_ms(), DAY_EVENT)
