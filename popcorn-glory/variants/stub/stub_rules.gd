extends PopRules

## The Step 03 stub: press the machine, it pops `pops[level]` pieces, each
## worth $1. The foundation the three experiments are built on.


func _init(p_economy: PopEconomy = null) -> void:
	super("stub", p_economy)


func _act(kind: String, _cmd: Dictionary) -> Dictionary:
	if kind != "press":
		return {"ok": false, "reason": "err.unknown_command"}
	presses += 1
	var n := economy.at(variant, "pops", level)
	_emit("pop", {"count": n, "level": level})
	_earn(n, {"from": "pop"})
	return {"ok": true, "pops": n}
