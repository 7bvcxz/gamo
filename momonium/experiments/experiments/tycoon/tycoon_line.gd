class_name TycoonLine
extends RefCounted

## Experiment E's production line as a simulation, item by item: raw items
## enter each lane at the hopper (every `spawn` s, when there is room), ride
## the belt (`speed` tiles a second, never closer than SPACING), stop at the
## machine until one of its `arms` is free, are worked for `process` s, ride
## on and are delivered at the end -- `value` coins each, once. The
## experiment draws it and the tests run it; nothing here is random.

const LENGTH := 6.0
const MACHINE_AT := 3.0
const SPACING := 0.45
const STEP := 0.05

var lanes := 1
var speed := 0.6
var spawn := 3.0
var process := 2.4
var arms := 1
var value := 3

## {id, lane, x, done, in, wait}: `in` while the machine works it (`wait` s left).
var items: Array[Dictionary] = []
var spawned := 0
var delivered := 0
var coins_made := 0
var belt_phase := 0.0
## Ids delivered (a test checks none twice).
var delivered_ids: Array[int] = []
## What happened in the last advance (the experiment shows it).
var just_delivered: Array[Dictionary] = []
var _spawn_t: Array[float] = []
var _next_id := 1


func configure(row: Dictionary) -> void:
	lanes = int(row["lanes"])
	speed = float(row["speed"])
	spawn = float(row["spawn"])
	process = float(row["process"])
	arms = int(row["arms"])
	value = int(row["value"])
	while _spawn_t.size() < lanes:
		# A new lane starts its hopper straight away.
		_spawn_t.append(spawn)


func advance(dt: float) -> void:
	just_delivered.clear()
	var left := dt
	while left > 0.0:
		var d := minf(left, STEP)
		_step(d)
		left -= d


func _step(d: float) -> void:
	belt_phase = fmod(belt_phase + speed * d, 1.0)
	for lane in lanes:
		_spawn_t[lane] += d
		if _spawn_t[lane] >= spawn and _room_at_start(lane):
			_spawn_t[lane] = 0.0
			items.append({"id": _next_id, "lane": lane, "x": 0.0, "done": false, "in": false, "wait": 0.0})
			_next_id += 1
			spawned += 1
	for lane in lanes:
		var row := items.filter(func(it: Dictionary) -> bool: return int(it["lane"]) == lane)
		row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["x"]) > float(b["x"]))
		var busy := 0
		for it: Dictionary in row:
			if bool(it["in"]):
				busy += 1
		var ahead := INF
		for it: Dictionary in row:
			# Inside the machine: worked, out of the belt's way.
			if bool(it["in"]):
				it["wait"] = float(it["wait"]) - d
				if float(it["wait"]) <= 0.0:
					it["wait"] = 0.0
					it["in"] = false
					it["done"] = true
					# Out at the machine's far side: the next one waits at its near side.
					it["x"] = MACHINE_AT + SPACING * 0.5
					busy -= 1
				continue
			var x := float(it["x"])
			var to := minf(x + speed * d, ahead - SPACING)
			if not bool(it["done"]) and x < MACHINE_AT and to >= MACHINE_AT - SPACING * 0.5:
				if busy < arms:
					it["x"] = MACHINE_AT
					it["in"] = true
					it["wait"] = process
					busy += 1
					continue
				to = minf(to, MACHINE_AT - SPACING * 0.5)
			it["x"] = maxf(x, to)
			ahead = float(it["x"])
	var kept: Array[Dictionary] = []
	for it: Dictionary in items:
		if float(it["x"]) >= LENGTH:
			delivered += 1
			coins_made += value
			delivered_ids.append(int(it["id"]))
			just_delivered.append(it)
		else:
			kept.append(it)
	items = kept


func _room_at_start(lane: int) -> bool:
	for it: Dictionary in items:
		if int(it["lane"]) == lane and float(it["x"]) < SPACING:
			return false
	return true
