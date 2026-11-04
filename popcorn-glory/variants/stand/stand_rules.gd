extends "res://variants/perfect/perfect_rules.gd"

## The Popcorn Stand (Step 10, the owner-approved vertical slice): B's hold
## and release is the heart -- heat, then judge the pop -- and the rest of a
## batch's seven moments are added around it a little at a time
## (design/SLICE.md):
##   1 load kernels, 2 dose oil   -- short animations of every batch (the view)
##   3 heat, 5 judge the pop      -- the hand: press, release in the gold (B)
##   4 shake                      -- from unlock.shake: while heating, slide the
##                                   finger side to side; `turns` direction
##                                   changes in one heat = an even pop (x mult)
##   6 season                     -- from unlock.recipes: a recipe, chosen once,
##                                   changes what a batch is worth and how hard
##                                   or slow it is (a tradeoff, not an upgrade)
##   7 pack and serve             -- an animation of every batch (the view)
## Automation, one station at a time (unlock.auto, the `auto` ladder): a motor
## that shakes every batch, then a helper kettle that heats and pops by itself
## every cycle_ms -- at a fixed share of the batch, so the hand's perfect pops
## stay worth more -- and gets faster with each rung.
## One money. Every number is in data/economy.json ("stand").

const RECIPE_DEFAULT := "butter"

var recipe := RECIPE_DEFAULT
var shakes := 0            ## direction changes in the current heat
var auto_level := 0        ## rungs of the automation ladder bought
var helper_ms := 0         ## progress of the helper's current batch
var helper_batches := 0
var manual_earned := 0
var helper_earned := 0
var even_pops := 0
var hand_even_pops := 0


func _init(p_economy: PopEconomy = null) -> void:
	super(p_economy)
	variant = "stand"


func _t() -> Dictionary:
	return economy.table(variant)


func unlocked(what: String) -> bool:
	return level >= int((_t()["unlock"] as Dictionary)[what])


func _recipe() -> Dictionary:
	return (_t()["recipes"] as Dictionary)[recipe]


## The gold, narrowed or not by the recipe, around the same middle.
func window_len() -> int:
	return int(round(super() * float(_recipe().get("window_scale", 1.0))))


func window_start() -> int:
	var base := int(_t()["window_start_ms"])
	var plain := super.window_len()
	return base + (plain - window_len()) / 2


func window_end() -> int:
	return window_start() + window_len()


func burn_at() -> int:
	return window_end() + int(round(int(_t()["burn_after_ms"]) * float(_recipe().get("burn_scale", 1.0))))


## The gold as judged is a little wider than the gold as drawn (edge_grace_ms
## each side): a release that looks inside the yellow pays as inside. Step 10's
## blind player let go 4 ms before a gold edge -- half a degree on the ring --
## and was paid a near miss. The drawn window is window_start..window_end.
func _judge(ms: int) -> String:
	var g := int(_t().get("edge_grace_ms", 0))
	if ms >= window_start() - g and ms <= window_end() + g:
		return PERFECT
	return super(ms)


func motor() -> bool:
	return auto_level >= 1


func helper_level() -> int:
	return maxi(0, auto_level - 1)


func _rung(i: int) -> Dictionary:
	var ladder: Array = _t()["auto"]
	return ladder[i] if i >= 0 and i < ladder.size() else {}


## The next automation to buy ({} when the ladder is done).
func auto_offer() -> Dictionary:
	return _rung(auto_level)


func auto_cost() -> int:
	var r := auto_offer()
	return int(r["cost"]) if not r.is_empty() else -1


func helper_cycle_ms() -> int:
	return int(_rung(auto_level - 1).get("cycle_ms", 0)) if helper_level() > 0 else 0


## What a helper batch pays at rung `r` of the ladder (r >= 2) at this level.
func helper_pays_for(r: int) -> int:
	var rg := _rung(r - 1)
	if r < 2 or rg.is_empty():
		return 0
	return maxi(1, int(floor(economy.at(variant, "batch", level) * float(rg["share"]))))


func helper_pays(at_level: int = -1) -> int:
	var hl := helper_level()
	if hl <= 0:
		return 0
	var lv := level if at_level < 0 else at_level
	return maxi(1, int(floor(economy.at(variant, "batch", lv) * float(_rung(auto_level - 1)["share"]))))


func _act(kind: String, cmd: Dictionary) -> Dictionary:
	match kind:
		"press":
			var r := super(kind, cmd)
			if bool(r["ok"]):
				shakes = 0
			return r
		"shake":
			if not unlocked("shake"):
				return {"ok": false, "reason": "err.locked"}
			if not heating:
				return {"ok": false, "reason": "err.not_heating"}
			shakes += 1
			_emit("shook", {"shakes": shakes, "even": shakes >= _turns()})
			return {"ok": true, "shakes": shakes}
		"recipe":
			if not unlocked("recipes"):
				return {"ok": false, "reason": "err.locked"}
			var id := String(cmd.get("id", ""))
			if not (_t()["recipes"] as Dictionary).has(id):
				return {"ok": false, "reason": "err.unknown_recipe"}
			if heating:
				return {"ok": false, "reason": "err.already_heating"}
			if id == recipe:
				return {"ok": true, "recipe": recipe}
			recipe = id
			_emit("recipe", {"id": recipe})
			return {"ok": true, "recipe": recipe}
		"buy_auto":
			return _buy_auto()
	return super(kind, cmd)


func _turns() -> int:
	return int((_t()["shake"] as Dictionary)["turns"])


func even_now() -> bool:
	return motor() or shakes >= _turns()


## The shake's factor for this batch: the hand's three swings x shake.mult, or
## else the motor's x motor_mult (Step 11: a blind player found the motor
## "quietly removed the crank skill, the most hands-on part" -- the hand now
## stays worth more than the machine, as the issue asks of every automation).
func _shake_mult() -> float:
	var sh: Dictionary = _t()["shake"]
	if not unlocked("shake"):
		return 1.0
	if shakes >= _turns():
		return float(sh["mult"])
	if motor():
		return float(sh.get("motor_mult", sh["mult"]))
	return 1.0


func _scale_batch(n: int, kind: String) -> int:
	var sm := _shake_mult()
	var by_hand := unlocked("shake") and shakes >= _turns()
	var out := maxi(1, int(floor(n * float(_recipe()["mult"]) * sm)))
	manual_earned += out
	if sm > 1.0:
		even_pops += 1
		if by_hand:
			hand_even_pops += 1
		_emit("even", {"kind": kind, "by": "hand" if by_hand else "motor"})
	return out


func _cooldown_ms() -> int:
	return super() + int(_recipe().get("cooldown_add_ms", 0))


func _buy_auto() -> Dictionary:
	if not unlocked("auto"):
		return {"ok": false, "reason": "err.locked"}
	var r := auto_offer()
	if r.is_empty():
		return {"ok": false, "reason": "err.max_level"}
	var c := int(r["cost"])
	if money < c:
		return {"ok": false, "reason": "err.not_enough_money"}
	money -= c
	auto_level += 1
	helper_ms = 0
	_emit("auto", {"rung": auto_level, "kind": String(r["kind"]), "cost": c, "money": money})
	return {"ok": true, "rung": auto_level, "cost": c}


## Time: the hand's heat (B, with its burn at the exact millisecond) and the
## helper's batches, each at its own exact millisecond, in time order.
func _tick(ms: int) -> void:
	var start := now_ms
	var done := 0
	while done < ms:
		var seg := ms - done
		var cycle := helper_cycle_ms()
		if cycle > 0 and cycle - helper_ms <= seg:
			seg = cycle - helper_ms
			now_ms = start + done
			super(seg)
			done += seg
			now_ms = start + done
			helper_ms = 0
			_helper_pop()
			continue
		now_ms = start + done
		super(seg)
		if cycle > 0:
			helper_ms += seg
		done += seg
	now_ms = start


func _helper_pop() -> void:
	var n := helper_pays()
	helper_batches += 1
	helper_earned += n
	_emit("helper_pop", {"count": n, "level": level, "rung": auto_level})
	_earn(n, {"from": "helper"})


## What one action pays now: a perfect batch with the recipe, and the even pop
## when it is automatic (the upgrade button's '+now > +next').
func payout(at_level: int) -> int:
	if at_level < 0 or at_level > max_level():
		return -1
	var t := _t()
	var n := maxi(1, int(floor(economy.at(variant, "batch", at_level) * float((t["mult"] as Dictionary)[PERFECT]))))
	var m := float(_recipe()["mult"])
	if motor() and at_level >= int((t["unlock"] as Dictionary)["shake"]):
		m *= float((t["shake"] as Dictionary).get("motor_mult", (t["shake"] as Dictionary)["mult"]))
	return maxi(1, int(floor(n * m)))


func state() -> Dictionary:
	var s := super()
	s["recipe"] = recipe
	s["recipes"] = (_t()["recipes"] as Dictionary).keys()
	s["shakes"] = shakes
	s["even"] = unlocked("shake") and shakes >= _turns()   # the hand's own even pop (the crank's gold)
	s["unlocked"] = {"shake": unlocked("shake"), "auto": unlocked("auto"), "recipes": unlocked("recipes")}
	s["auto_level"] = auto_level
	s["auto_next"] = auto_offer().get("kind", "")
	s["auto_cost"] = auto_cost()
	s["motor"] = motor()
	s["helper_level"] = helper_level()
	s["helper_ms"] = helper_ms
	s["helper_cycle_ms"] = helper_cycle_ms()
	s["helper_pays"] = helper_pays()
	s["helper_batches"] = helper_batches
	s["manual_earned"] = manual_earned
	s["helper_earned"] = helper_earned
	s["even_pops"] = even_pops
	s["hand_even_pops"] = hand_even_pops
	return s
