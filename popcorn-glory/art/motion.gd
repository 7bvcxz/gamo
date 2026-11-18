class_name PopMotion
extends RefCounted

## Step 42: the factory's motion director (design/MOTION.md). It decides HOW MUCH moves, never
## WHAT happens: the rules have already counted every batch, bag and coin when an effect asks to
## be shown, so a refused effect changes nothing in the game.
##
##   tiers     how many machines are running: 1 / 5 / 20 / 40 (solo, busy, crowded, swarm). Each
##             tier has a budget -- pieces per automatic lot, ambient pieces a second (steam,
##             glitter) shared by the whole factory, the size of sparkles. The busier the floor,
##             the smaller each machine's share: forty machines are a texture, one is a show.
##   buckets   a token bucket per kind of effect (lot pieces, ambient, sparkles). A bucket holds
##             at most one second of budget, so a hidden tab or a long frame never pours a
##             backlog of effects out at once.
##   low       ?fx=low, or automatic: frames slower than LOW_FPS for LOW_AFTER_S seconds drop to
##             the low budgets; FPS above HIGH_FPS for RECOVER_S brings them back.
##   light     a glow per floor (kitchen, packing, shop) that real batch events raise and that
##             fades, and a sweep up the glass tube for a celebration (upgrade, sign, contest
##             prize, a rush of customers). Nothing here moves the kettle or its ring.
##   defer     while the hand holds the kettle (B's timing) a celebration waits until the hand
##             lets go (at most DEFER_MAX_S): the gold is the only thing that asks for the eye.

const TIER_NAMES := ["solo", "busy", "crowded", "swarm"]
const TIER_UPTO := [2, 8, 24]          ## running machines: <= 2 solo, <= 8 busy, <= 24 crowded, else swarm
## Per tier: kernel pieces per automatic lot, ambient pieces per second (whole factory),
## sparkle count scale, lot pieces per second (whole factory).
const LOT_PIECES := [6, 4, 2, 1]
const AMBIENT_PER_S := [6.0, 10.0, 14.0, 14.0]
const SPARKLE_SCALE := [1.0, 0.85, 0.6, 0.4]
const LOT_PER_S := [30.0, 36.0, 40.0, 40.0]
## Low effects: the swarm's budgets, quieter still.
const LOW_AMBIENT_PER_S := 4.0
const LOW_SPARKLE := 0.3
const LOW_LOT_PER_S := 16.0

const LOW_FPS := 22.0
const LOW_AFTER_S := 4.0
const HIGH_FPS := 40.0
const RECOVER_S := 10.0

const GLOW_FADE_S := 0.9      ## a floor's glow falls from 1 to 0 in this time
const GLOW_MAX := 1.0
const SWEEP_S := 0.9          ## the celebration light runs up the tube in this time
const SWEEP_STAGGER := [0.0, 0.14, 0.28]   ## kitchen, packing, shop light up in turn (bottom to top)
const DEFER_MAX_S := 3.0

var running := 0
var forced_low := false       ## ?fx=low
var auto_low := false
var reduced := false          ## reduced motion: no ambient pieces, no sweep travel (a still glow)
var _slow_s := 0.0
var _fast_s := 0.0
var fps_avg := 60.0
var _buckets := {"lot": 0.0, "ambient": 0.0, "sparkle": 0.0}
var stats := {"asked": {}, "given": {}, "refused": {}, "celebrations": 0, "deferred": 0, "auto_low_on": 0, "auto_low_off": 0}

## Light: glows by floor index (0 shop, 1 packing, 2 kitchen -- the view's TOP/MID/LOW).
var glow := [0.0, 0.0, 0.0]
var glow_peak_at := [-1.0, -1.0, -1.0]   ## the clock when each floor was last lit (for the arc test)
var sweep := -1.0             ## seconds into the current sweep, -1 none
var sweep_kind := ""
var _lit := [true, true, true]   ## which floors this sweep has lit (glow index)
var _queued := ""             ## a celebration waiting for the hand to let go
var _queued_s := 0.0
var clock := 0.0


func tier() -> int:
	for i in TIER_UPTO.size():
		if running <= int(TIER_UPTO[i]):
			return i
	return TIER_UPTO.size()


func low() -> bool:
	return forced_low or auto_low


func lot_pieces() -> int:
	return 1 if low() else int(LOT_PIECES[tier()])


func ambient_per_s() -> float:
	if reduced:
		return 0.0
	return LOW_AMBIENT_PER_S if low() else float(AMBIENT_PER_S[tier()])


func sparkle_scale() -> float:
	return LOW_SPARKLE if low() else float(SPARKLE_SCALE[tier()])


## A sparkle's count under the current budget (at least one, so a real event is never silent).
func sparkles(n: int) -> int:
	return maxi(1, int(round(float(n) * sparkle_scale())))


func _rate(kind: String) -> float:
	match kind:
		"lot":
			return LOW_LOT_PER_S if low() else float(LOT_PER_S[tier()])
		"ambient":
			return ambient_per_s()
		"sparkle":
			return 40.0 * sparkle_scale()
	return 0.0


## Takes `n` from the bucket of `kind`; answers how many may be shown (0..n).
func allow(kind: String, n: int = 1) -> int:
	stats["asked"][kind] = int(stats["asked"].get(kind, 0)) + n
	var have := floori(float(_buckets.get(kind, 0.0)))
	var give := clampi(have, 0, n)
	_buckets[kind] = float(_buckets.get(kind, 0.0)) - float(give)
	stats["given"][kind] = int(stats["given"].get(kind, 0)) + give
	if give < n:
		stats["refused"][kind] = int(stats["refused"].get(kind, 0)) + (n - give)
	return give


## Every frame: `delta` the frame's seconds (as the view saw it), `holding` whether the hand
## is on the kettle (B). Returns a celebration that may start now ("" none).
func step(delta: float, holding: bool) -> String:
	var dt := clampf(delta, 0.0, 0.25)
	clock += dt
	for k: String in _buckets:
		var r := _rate(k)
		_buckets[k] = minf(maxf(r, 1.0), float(_buckets[k]) + r * dt)   # at most one second of budget
	# The frame rate, smoothed (a single hitch is not a slow device).
	if delta > 0.0:
		fps_avg = lerpf(fps_avg, 1.0 / maxf(delta, 0.001), clampf(dt * 2.0, 0.0, 1.0))
	if fps_avg < LOW_FPS:
		_slow_s += dt
		_fast_s = 0.0
	elif fps_avg > HIGH_FPS:
		_fast_s += dt
		_slow_s = 0.0
	else:
		_slow_s = 0.0
		_fast_s = 0.0
	if not auto_low and _slow_s >= LOW_AFTER_S:
		auto_low = true
		stats["auto_low_on"] = int(stats["auto_low_on"]) + 1
	elif auto_low and _fast_s >= RECOVER_S:
		auto_low = false
		stats["auto_low_off"] = int(stats["auto_low_off"]) + 1
	for i in 3:
		glow[i] = maxf(0.0, float(glow[i]) - dt / GLOW_FADE_S)
	if sweep >= 0.0:
		sweep += dt
		for i in 3:
			var at := float(SWEEP_STAGGER[2 - i])   # glow index 2 is the kitchen (first)
			if not bool(_lit[i]) and sweep >= at:
				_lit[i] = true
				light(i, 1.0)
		if sweep > SWEEP_S + float(SWEEP_STAGGER[2]):
			sweep = -1.0
	var start := ""
	if _queued != "":
		_queued_s += dt
		if not holding or _queued_s >= DEFER_MAX_S:
			start = _queued
			_queued = ""
	return start


## A real event lit a floor (glow index: 0 shop, 1 packing, 2 kitchen).
func light(i: int, amount: float = 0.6) -> void:
	glow[i] = clampf(maxf(float(glow[i]), amount), 0.0, GLOW_MAX)
	glow_peak_at[i] = clock


## A celebration: waits while the hand holds the kettle, then the light runs up the tube.
## Answers true when it starts now.
func celebrate(kind: String, holding: bool) -> bool:
	if holding:
		if _queued == "":
			stats["deferred"] = int(stats["deferred"]) + 1
		_queued = kind   # the latest wins; one sweep says it
		_queued_s = 0.0
		return false
	_start_sweep(kind)
	return true


func _start_sweep(kind: String) -> void:
	stats["celebrations"] = int(stats["celebrations"]) + 1
	sweep_kind = kind
	if reduced:
		# No travel: the three floors glow together and fade (the news is still seen).
		for i in 3:
			light(i, 0.8)
		sweep = -1.0
		return
	sweep = 0.0
	_lit = [false, false, false]


## The step's returned celebration starts through here (so stats count it once).
func begin(kind: String) -> void:
	_start_sweep(kind)


func queued() -> String:
	return _queued


## The sweep's light on the tube: 0..1 from the bottom to the top, -1 when none.
func sweep_progress() -> float:
	if sweep < 0.0:
		return -1.0
	return clampf(sweep / SWEEP_S, 0.0, 1.0)


func debug() -> Dictionary:
	return {"running": running, "tier": tier(), "tier_name": TIER_NAMES[tier()], "low": low(), "forced_low": forced_low,
		"auto_low": auto_low, "reduced": reduced, "fps_avg": snappedf(fps_avg, 0.1), "lot_pieces": lot_pieces(),
		"ambient_per_s": ambient_per_s(), "sparkle_scale": sparkle_scale(), "glow": glow.map(func(g: float) -> float: return snappedf(g, 0.001)),
		"glow_at": glow_peak_at.duplicate(), "sweep": sweep_progress(), "sweep_kind": sweep_kind, "queued": _queued, "stats": stats.duplicate(true)}
