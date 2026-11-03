extends PopRules

## A Click & Pop: every press pops pops[level] pieces at once, each $1.
## Nothing depends on time and nothing can fail.


func _init(p_economy: PopEconomy = null) -> void:
	super("click", p_economy)


func _act(kind: String, _cmd: Dictionary) -> Dictionary:
	if kind != "press":
		return {"ok": false, "reason": "err.unknown_command"}
	presses += 1
	var n := economy.at(variant, "pops", level)
	_emit("pop", {"count": n, "level": level})
	_earn(n, {"from": "pop"})
	return {"ok": true, "pops": n}
