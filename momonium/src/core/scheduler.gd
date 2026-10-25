class_name Scheduler
extends RefCounted

## Future simulation events, ordered by (time, sequence).
##
## An event is plain data -- {at, seq, type, data} -- so the queue saves and
## loads as-is and nothing in it refers to a node or a callable. Equal times run
## in the order they were scheduled, which keeps a run reproducible.
##
## Events are never removed early. Their owner keeps a token and ignores an
## event whose token no longer matches (cancelled, replaced). That keeps
## cancellation O(1) and the heap simple.

var _heap: Array[Dictionary] = []
var _next_seq: int = 0


func schedule(at_ms: int, type: StringName, data: Dictionary = {}) -> int:
	var event := {"at": at_ms, "seq": _next_seq, "type": String(type), "data": data}
	_next_seq += 1
	_heap.append(event)
	_sift_up(_heap.size() - 1)
	return event["seq"]


func is_empty() -> bool:
	return _heap.is_empty()


func size() -> int:
	return _heap.size()


## Time of the earliest event, or -1 when there is none.
func peek_time() -> int:
	return -1 if _heap.is_empty() else int(_heap[0]["at"])


func pop() -> Dictionary:
	var top: Dictionary = _heap[0]
	var last: Dictionary = _heap.pop_back()
	if not _heap.is_empty():
		_heap[0] = last
		_sift_down(0)
	return top


## Every pending event of one type, in no particular order. For inspection only.
func events_of(type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in _heap:
		if event["type"] == String(type):
			out.append(event)
	return out


func save_state() -> Dictionary:
	var events: Array = []
	for event: Dictionary in _heap:
		events.append(event.duplicate(true))
	events.sort_custom(_before)
	return {"next_seq": _next_seq, "events": events}


func load_state(state: Dictionary) -> void:
	_heap.clear()
	_next_seq = int(state.get("next_seq", 0))
	for raw: Dictionary in state.get("events", []):
		var event := {"at": int(raw["at"]), "seq": int(raw["seq"]), "type": String(raw["type"]), "data": raw.get("data", {})}
		_heap.append(event)
		_sift_up(_heap.size() - 1)


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["at"] != b["at"]:
		return a["at"] < b["at"]
	return a["seq"] < b["seq"]


func _sift_up(index: int) -> void:
	var i := index
	while i > 0:
		var parent := (i - 1) / 2
		if not _before(_heap[i], _heap[parent]):
			break
		var tmp: Dictionary = _heap[i]
		_heap[i] = _heap[parent]
		_heap[parent] = tmp
		i = parent


func _sift_down(index: int) -> void:
	var i := index
	var n := _heap.size()
	while true:
		var left := i * 2 + 1
		var right := left + 1
		var best := i
		if left < n and _before(_heap[left], _heap[best]):
			best = left
		if right < n and _before(_heap[right], _heap[best]):
			best = right
		if best == i:
			return
		var tmp: Dictionary = _heap[i]
		_heap[i] = _heap[best]
		_heap[best] = tmp
		i = best
