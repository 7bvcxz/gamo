class_name PopRules
extends RefCounted

## One experiment's rules, with no picture and no frame clock in them.
##
## Time is an integer of milliseconds that only moves through advance(). The
## same commands at the same times give the same run however the frames cut
## the time up (tests/unit/test_rules.gd cuts it 16, 17, 1000 and 95000 ms at
## a time). Money is an integer and never goes below zero.
##
## execute() answers {ok, reason}; reason is a key, not a sentence. What
## happened is told through events, drained by the view and the session log:
##   {t, type: "pop"|"earn"|"upgrade"|..., data}

var variant := ""
var economy: PopEconomy
var now_ms: int = 0
var money: int = 0
var level: int = 0
var earned: int = 0
var presses: int = 0

var _events: Array[Dictionary] = []


func _init(p_variant: String = "", p_economy: PopEconomy = null) -> void:
	variant = p_variant
	economy = p_economy if p_economy != null else PopEconomy.load_default()


func execute(cmd: Dictionary) -> Dictionary:
	var kind := String(cmd.get("type", ""))
	match kind:
		"buy":
			return _buy()
		_:
			return _act(kind, cmd)


## Moves time forward by `ms` (never back).
func advance(ms: int) -> void:
	if ms <= 0:
		return
	_tick(ms)
	now_ms += ms


func cost() -> int:
	return economy.cost(variant, level)


func max_level() -> int:
	return economy.max_level(variant)


func can_buy() -> bool:
	var c := cost()
	return c >= 0 and money >= c


func drain_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


func state() -> Dictionary:
	return {"variant": variant, "now_ms": now_ms, "money": money, "level": level,
		"cost": cost(), "max_level": max_level(), "earned": earned, "presses": presses}


# -- for the experiments --------------------------------------------------

## The main action; each experiment answers its own command types.
func _act(_kind: String, _cmd: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "err.unknown_command"}


## Time-driven rules (a heat that rises, a show that ends) live here.
func _tick(_ms: int) -> void:
	pass


func _earn(amount: int, data: Dictionary = {}) -> void:
	if amount <= 0:
		return
	money += amount
	earned += amount
	var d := data.duplicate()
	d["amount"] = amount
	d["money"] = money
	_emit("earn", d)


func _emit(type: String, data: Dictionary = {}) -> void:
	_events.append({"t": now_ms, "type": type, "data": data})


func _buy() -> Dictionary:
	var c := cost()
	if c < 0:
		return {"ok": false, "reason": "err.max_level"}
	if money < c:
		return {"ok": false, "reason": "err.not_enough_money"}
	money -= c
	level += 1
	_emit("upgrade", {"level": level, "cost": c, "money": money})
	return {"ok": true, "level": level, "cost": c}
