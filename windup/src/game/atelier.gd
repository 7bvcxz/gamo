class_name Atelier
extends RefCounted

## The rules, and nothing else: one currency (wind-up energy), one action
## (a quarter turn of the key), and the dolls that wake in a fixed order when
## the energy covers the next one's cost (design/CORE_LOOP.md).
##
## No nodes, no drawing, no real time: `tick(dt)` is the only clock, so the
## game, the tests and the balance simulator run exactly the same rules.
##
## Energy accounting, one source of truth:
##   energy == manual_energy + auto_energy - spent        (always)

signal awakening(index: int)        ## the cost is paid, the doll starts to wake
signal awake_changed(index: int)    ## that doll is fully awake and working
signal stage_changed(stage: int, name: String)

var b: Balance
var energy: float = 0.0
## Fully awake dolls (they contribute energy).
var awake: int = 0
## The doll waking right now, -1 if none.
var waking: int = -1
var wake_left: float = 0.0
var manual_energy: float = 0.0
var auto_energy: float = 0.0
var spent: float = 0.0
var turns: int = 0
## Presses refused because they came faster than the cap.
var blocked: int = 0
var stage: int = 0
var time: float = 0.0

var _last_turn: float = -INF


func _init(balance: Balance) -> void:
	b = balance


func doll_count() -> int:
	return b.doll_count()


## The doll the energy is filling now (the one being woken counts as done);
## doll_count() when every doll is awake or waking.
func target() -> int:
	return awake + (1 if waking >= 0 else 0)


func target_cost() -> float:
	return b.costs[target()] if target() < doll_count() else INF


## 0..1: how much of the target's cost the energy covers.
func target_fill() -> float:
	if target() >= doll_count():
		return 1.0
	return clampf(energy / target_cost(), 0.0, 1.0)


## Energy one quarter turn adds now (grows with the gear train: one gear per awake doll).
func wind_power() -> float:
	return b.energy_per_turn * (1.0 + b.gear_bonus_per_doll * awake)


## Energy per second the awake dolls add.
func auto_rate() -> float:
	var r := 0.0
	for i in awake:
		r += b.rates[i]
	return r


func can_turn() -> bool:
	return time - _last_turn >= 1.0 / b.max_turns_per_second - 1e-6


## One quarter turn. Answers the energy added (0 when refused by the cap).
func wind() -> float:
	if not can_turn():
		blocked += 1
		return 0.0
	_last_turn = time
	var e := wind_power()
	energy += e
	manual_energy += e
	turns += 1
	_check()
	return e


func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	time += dt
	var a := auto_rate() * dt
	energy += a
	auto_energy += a
	if waking >= 0:
		wake_left -= dt
		if wake_left <= 0.0:
			var done := waking
			waking = -1
			awake += 1
			awake_changed.emit(done)
			_update_stage()
	_check()


func _check() -> void:
	if waking >= 0 or target() >= doll_count():
		return
	var cost := target_cost()
	if energy + 1e-9 >= cost:
		energy -= cost
		spent += cost
		waking = target()
		wake_left = b.awaken_seconds
		awakening.emit(waking)


func _update_stage() -> void:
	var s := stage_for(awake)
	if s != stage:
		stage = s
		stage_changed.emit(stage, String(b.stages[stage][1]))


func stage_for(dolls: int) -> int:
	var s := 0
	for i in b.stages.size():
		if dolls >= int(b.stages[i][0]):
			s = i
	return s


func stage_name() -> String:
	return String(b.stages[stage][1])


## Where the accounting says energy should be (tests compare it to `energy`).
func accounted_energy() -> float:
	return manual_energy + auto_energy - spent


func to_dict() -> Dictionary:
	return {"energy": energy, "awake": awake, "waking": waking, "wake_left": wake_left,
		"manual_energy": manual_energy, "auto_energy": auto_energy, "spent": spent,
		"turns": turns, "blocked": blocked, "time": time}


## Restores a saved atelier. Anything that does not fit the current data
## (more dolls than exist, negative energy) is clamped, never trusted.
func from_dict(d: Dictionary) -> void:
	awake = clampi(int(d.get("awake", 0)), 0, doll_count())
	waking = int(d.get("waking", -1))
	if waking != awake or waking >= doll_count():
		waking = -1
	wake_left = clampf(float(d.get("wake_left", 0.0)), 0.0, b.awaken_seconds)
	manual_energy = maxf(0.0, float(d.get("manual_energy", 0.0)))
	auto_energy = maxf(0.0, float(d.get("auto_energy", 0.0)))
	spent = maxf(0.0, float(d.get("spent", 0.0)))
	energy = maxf(0.0, float(d.get("energy", 0.0)))
	turns = maxi(0, int(d.get("turns", 0)))
	blocked = maxi(0, int(d.get("blocked", 0)))
	time = maxf(0.0, float(d.get("time", 0.0)))
	_last_turn = -INF
	stage = stage_for(awake)
	# A save whose numbers disagree is repaired to the energy it shows.
	if absf(accounted_energy() - energy) > 0.01:
		spent = manual_energy + auto_energy - energy
