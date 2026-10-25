class_name MomoSystem
extends SimSystem

## The Momo who live on the island, as simulation state.
##
## Each Momo is a record (id, name, where it stands) that saves with the
## game; what it looks like is the view's business. The game starts with one
## (balance.start.momos), as in the reference: Day 1, a 2x2 island, $10 and a
## friend. Hiring, roaming and work assignment build on this in Steps 18-19.

## id -> {id, name (translation key), pos [x, y] logical, assigned (building id or 0)}
var momos: Dictionary = {}
var next_id := 1


func _init() -> void:
	key = &"momo"


func on_new_game() -> void:
	momos.clear()
	next_id = 1
	var spots: Array[Vector2] = [Vector2(0.55, 1.35), Vector2(1.4, 0.6), Vector2(0.5, 0.5), Vector2(1.5, 1.5)]
	for i in sim.data.get_int("balance", "start.momos", 1):
		add_momo(spots[i % spots.size()])


func add_momo(pos: Vector2) -> int:
	var id := next_id
	next_id += 1
	var names := maxi(sim.data.get_int("balance", "momo.names", 10), 1)
	momos[id] = {"id": id, "name": "momo.name.%d" % ((id - 1) % names), "pos": [pos.x, pos.y], "assigned": 0}
	sim.bus.emit(&"momo_added", {"id": id})
	return id


func ids() -> Array[int]:
	var out: Array[int] = []
	for id: int in momos:
		out.append(id)
	out.sort()
	return out


func get_momo(id: int) -> Dictionary:
	return momos.get(id, {})


func position_of(id: int) -> Vector2:
	var p: Array = momos[id]["pos"]
	return Vector2(float(p[0]), float(p[1]))


func save_state() -> Dictionary:
	var list: Array = []
	for id: int in ids():
		list.append(momos[id].duplicate(true))
	return {"next_id": next_id, "momos": list}


func load_state(state: Dictionary) -> void:
	momos.clear()
	next_id = int(state.get("next_id", 1))
	for raw: Dictionary in state.get("momos", []):
		var m := raw.duplicate(true)
		m["id"] = int(m["id"])
		m["assigned"] = int(m.get("assigned", 0))
		momos[m["id"]] = m
