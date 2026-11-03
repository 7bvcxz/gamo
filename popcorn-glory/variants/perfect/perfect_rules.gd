extends PopRules

## B Perfect Pop: press to start heating, release to pop. The release time
## since the press decides the batch:
##   before the gold window  early    x mult.early
##   inside it               perfect  x mult.perfect
##   after it                late     x mult.late
##   held burn_after_ms past it: burnt by itself (x mult.burnt) -- holding on
##   never locks the game.
## Every batch pays at least $1. After a pop the machine cools for cooldown_ms;
## a press then is refused (err.cooling).

const EARLY := "early"
const PERFECT := "perfect"
const LATE := "late"
const BURNT := "burnt"

var heating := false
var heat_ms := 0
var cooldown_left := 0
var outcomes := {EARLY: 0, PERFECT: 0, LATE: 0, BURNT: 0}


func _init(p_economy: PopEconomy = null) -> void:
	super("perfect", p_economy)


func window_start() -> int:
	return int(economy.table(variant)["window_start_ms"])


func window_len() -> int:
	var t := economy.table(variant)
	return mini(int(t["window_ms"]) + int(t["window_step_ms"]) * level, int(t["window_max_ms"]))


func window_end() -> int:
	return window_start() + window_len()


func burn_at() -> int:
	return window_end() + int(economy.table(variant)["burn_after_ms"])


func _act(kind: String, _cmd: Dictionary) -> Dictionary:
	match kind:
		"press":
			if heating:
				return {"ok": false, "reason": "err.already_heating"}
			if cooldown_left > 0:
				return {"ok": false, "reason": "err.cooling"}
			presses += 1
			heating = true
			heat_ms = 0
			_emit("heat_start", {"window_start": window_start(), "window_end": window_end(), "burn_at": burn_at()})
			return {"ok": true}
		"release":
			if not heating:
				return {"ok": false, "reason": "err.not_heating"}
			return _resolve(_judge(heat_ms))
	return {"ok": false, "reason": "err.unknown_command"}


func _tick(ms: int) -> void:
	# The burn happens at its exact millisecond inside this step: events are
	# stamped there, and the clock is put back for advance() to add `ms`.
	var start := now_ms
	var done := 0
	while done < ms:
		var left := ms - done
		if heating:
			var to_burn := burn_at() - heat_ms
			if to_burn <= left:
				heat_ms += to_burn
				done += to_burn
				now_ms = start + done
				_resolve(BURNT)
				continue
			heat_ms += left
		else:
			cooldown_left = maxi(0, cooldown_left - left)
		done = ms
	now_ms = start


func _judge(ms: int) -> String:
	if ms < window_start():
		return EARLY
	if ms <= window_end():
		return PERFECT
	if ms < burn_at():
		return LATE
	return BURNT


func _resolve(kind: String) -> Dictionary:
	var t := economy.table(variant)
	var mult := float((t["mult"] as Dictionary)[kind])
	var batch := economy.at(variant, "batch", level)
	var n := maxi(1, int(floor(batch * mult)))
	var held := heat_ms
	heating = false
	heat_ms = 0
	cooldown_left = int(t["cooldown_ms"])
	outcomes[kind] = int(outcomes[kind]) + 1
	var centre := (window_start() + window_end()) / 2
	_emit("outcome", {"kind": kind, "held_ms": held, "from_centre_ms": held - centre})
	_emit("pop", {"count": n, "level": level, "outcome": kind})
	_earn(n, {"from": kind})
	return {"ok": true, "outcome": kind, "pops": n}


func state() -> Dictionary:
	var s := super()
	s["heating"] = heating
	s["heat_ms"] = heat_ms
	s["cooldown_left"] = cooldown_left
	s["window"] = [window_start(), window_end(), burn_at()]
	s["outcomes"] = outcomes.duplicate()
	return s
