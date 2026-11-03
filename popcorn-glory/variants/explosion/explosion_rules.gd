extends PopRules

## C Pop Explosion: each press drops a kernel into the chamber (`slots` of
## them). A full chamber erupts: burst[level] pieces, paid at once, and a show
## of show_ms(level). Presses during the show fill the next chamber; if it is
## full when the show ends, it erupts then. Nothing can fail and no press is
## ever refused (a press into a full chamber during a show is just counted).

var loaded := 0
var showing_left := 0
var eruptions := 0
var biggest := 0


func _init(p_economy: PopEconomy = null) -> void:
	super("explosion", p_economy)


func slots() -> int:
	return int(economy.table(variant)["slots"])


func show_len() -> int:
	var t := economy.table(variant)
	return mini(int(t["show_ms"]) + int(t["show_step_ms"]) * level, int(t["show_max_ms"]))


func _act(kind: String, _cmd: Dictionary) -> Dictionary:
	if kind != "press":
		return {"ok": false, "reason": "err.unknown_command"}
	presses += 1
	if loaded < slots():
		loaded += 1
		_emit("load", {"loaded": loaded, "slots": slots()})
	if loaded >= slots() and showing_left <= 0:
		_erupt()
	return {"ok": true, "loaded": loaded}


func _tick(ms: int) -> void:
	# A show that ends inside this step ends at its exact millisecond, and a
	# full chamber erupts right then (a new show, which may itself end later in
	# the step). The clock is put back for advance() to add `ms`.
	var start := now_ms
	var done := 0
	while done < ms and showing_left > 0:
		var left := ms - done
		if left < showing_left:
			showing_left -= left
			break
		done += showing_left
		showing_left = 0
		now_ms = start + done
		_emit("show_end", {})
		if loaded >= slots():
			_erupt()
	now_ms = start


func _erupt() -> void:
	loaded = 0
	eruptions += 1
	var n := economy.at(variant, "burst", level)
	biggest = maxi(biggest, n)
	showing_left = show_len()
	_emit("erupt", {"count": n, "level": level, "show_ms": showing_left})
	_emit("pop", {"count": n, "level": level})
	_earn(n, {"from": "erupt"})


func state() -> Dictionary:
	var s := super()
	s["loaded"] = loaded
	s["slots"] = slots()
	s["showing_left"] = showing_left
	s["eruptions"] = eruptions
	return s
