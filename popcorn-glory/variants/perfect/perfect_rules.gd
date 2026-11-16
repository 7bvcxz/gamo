extends PopRules

## B Perfect Pop: press to start heating, release to pop. The release time
## since the press decides the batch:
##   before the gold window  early    x mult.early x (held / gold start): only
##                                    the kernels the heat reached pop, so a
##                                    quick tap pays little (it out-earned
##                                    aiming at the gold when it paid a flat
##                                    x0.3 -- Step 04's tap-only player)
##   within near_ms of it    near     x mult.near  (a near miss: fair, not a fail)
##   inside it               perfect  x mult.perfect
##   after it                late     x mult.late
##   held burn_after_ms past it: burnt by itself (x mult.burnt) -- holding on
##   never locks the game.
## Every batch pays at least $1. After a pop the machine cools for cooldown_ms;
## a press then is refused (err.cooling).

const EARLY := "early"
const NEAR := "near"
const PERFECT := "perfect"
const LATE := "late"
const BURNT := "burnt"

var heating := false
var heat_ms := 0
var cooldown_left := 0
var outcomes := {EARLY: 0, NEAR: 0, PERFECT: 0, LATE: 0, BURNT: 0}
## Step 14, the crescendo (Step 19: shared by every kettle that has a
## `crescendo` table): successful pops fill it, and the pop that fills it is a
## burst worth more. Off unless a variant turns it on (the stand from ?burst=1,
## the factory always); B as compared in Step 09 never has it.
var burst_mode := false
var crescendo := 0
var bursts := 0


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


func near_ms() -> int:
	return int(economy.table(variant).get("near_ms", 0))


## The judge (Step 19, design/DECISIONS.md D-02: one judge for every kettle):
## a release this close outside the drawn gold still counts as perfect
## (`edge_grace_ms` of the variant's table -- 0 for B as compared in Step 09,
## 40 for the stand and the factory).
func edge_grace() -> int:
	return int(economy.table(variant).get("edge_grace_ms", 0))


func _judge(ms: int) -> String:
	var g := edge_grace()
	if g > 0 and ms >= window_start() - g and ms <= window_end() + g:
		return PERFECT
	if ms < window_start():
		return NEAR if window_start() - ms <= near_ms() else EARLY
	if ms <= window_end():
		return PERFECT
	if ms < burn_at():
		return NEAR if ms - window_end() <= near_ms() else LATE
	return BURNT


func payout(at_level: int) -> int:
	if at_level < 0 or at_level > max_level():
		return -1
	var mult := float((economy.table(variant)["mult"] as Dictionary)[PERFECT])
	return maxi(1, int(floor(economy.at(variant, "batch", at_level) * mult)))


func _resolve(kind: String) -> Dictionary:
	var t := economy.table(variant)
	var held := heat_ms
	var mult := float((t["mult"] as Dictionary)[kind])
	if kind == EARLY:
		mult *= clampf(float(held) / float(window_start()), 0.0, 1.0)
	var batch := economy.at(variant, "batch", level)
	var n := _scale_batch(maxi(1, int(floor(batch * mult))), kind)
	heating = false
	heat_ms = 0
	cooldown_left = _cooldown_ms()
	outcomes[kind] = int(outcomes[kind]) + 1
	var centre := (window_start() + window_end()) / 2
	_emit("outcome", {"kind": kind, "held_ms": held, "from_centre_ms": held - centre})
	_emit("pop", {"count": n, "level": level, "outcome": kind})
	_earn(n, {"from": kind})
	return {"ok": true, "outcome": kind, "pops": n}


## Hooks for the Step 10 shop (variants/stand): what a batch is worth after
## the pop and how long the machine cools. B itself changes nothing here.
func _scale_batch(n: int, _kind: String) -> int:
	return n


func _cooldown_ms() -> int:
	return int(economy.table(variant)["cooldown_ms"])


func state() -> Dictionary:
	var s := super()
	s["heating"] = heating
	s["heat_ms"] = heat_ms
	s["cooldown_left"] = cooldown_left
	s["window"] = [window_start(), window_end(), burn_at()]
	s["near_ms"] = near_ms()
	s["outcomes"] = outcomes.duplicate()
	s["burst_mode"] = burst_mode
	if burst_mode:
		s["crescendo"] = crescendo
		s["crescendo_full"] = crescendo_full()
		s["bursts"] = bursts
		s["burst_tier"] = burst_tier()
	return s


func _burst_table() -> Dictionary:
	return economy.table(variant).get("crescendo", {})


func crescendo_full() -> int:
	return int(_burst_table().get("full", 8))


## The burst's look grows with the stand: 0 a big pop, 1 a chain, 2 a fountain.
func burst_tier(at_level: int = -1) -> int:
	var lv := level if at_level < 0 else at_level
	var tier := 0
	for t: Variant in _burst_table().get("tiers", []):
		if lv >= int(t):
			tier += 1
	return tier


## A hand pop's batch after the crescendo: fills the meter by the outcome, and
## the pop that fills it pays (1 + bonus) x. Misses add nothing and take nothing.
func _crescendo(n: int, kind: String) -> int:
	if not burst_mode:
		return n
	var bt := _burst_table()
	var add := int(bt.get(kind, 0)) if kind == PERFECT or kind == NEAR else 0
	if add <= 0:
		return n
	crescendo += add
	if crescendo < crescendo_full():
		_emit("crescendo", {"kernels": crescendo, "full": crescendo_full()})
		return n
	crescendo = 0
	bursts += 1
	var out := int(floor(n * (1.0 + float(bt.get("bonus", 0.5)))))
	_emit("burst", {"tier": burst_tier(), "count": out, "extra": out - n, "outcome": kind})
	return out
