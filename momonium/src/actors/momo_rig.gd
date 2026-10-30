class_name MomoRig
extends Node2D

## Momo, drawn from the 5x5 sprite sheet (Step 51, design/MOMO_SPRITES.md).
##
## Every cell is the approved character in one pose, the feet of each on the
## same pivot -- so the node's origin is where Momo's feet touch the ground,
## the same origin convention as every other world sprite, and depth sorting
## works. Before Step 51 Momo was a puppet of SVG parts turned by code; it
## looked nothing like the character sheet.
##
## States pick an animation from the sheet's map:
##   idle   the standing cell of the view; blinks now and then (front), or a
##          mood's pose while a mood shows (`mood_pose`)
##   walk   four frames (A B C B) of the view, faster with `walk_speed`
##   sit    sitting with a clover, sleep  lying down with the ears spread
##   work   the job's animation from the work atlas (`work_pose`, Step 66:
##          Momo with the tool of the job -- design/MOMO_TOOLS.md), else a
##          sheet pose of that name, else working with the back turned
## `face` picks the view -- front, back (moving up the screen), side (moving
## across it) -- and mirrors for the left. A light breath and a bob in the
## step keep the still cells alive.

## World pixels from the feet to the fur curl of a standing Momo: a bit over
## half a tile, as before Step 51 (hit areas and the HUD's anchors assume it).
const HEIGHT := 72.0
const STATES: PackedStringArray = ["idle", "walk", "sit", "sleep", "work"]
## Job poses with their own cells; anything else works back turned.
const WORK_POSES: PackedStringArray = ["harvest", "water", "dig", "study", "carry"]
const MOOD_POSES: PackedStringArray = ["happy", "waiting", "confused"]

var state := "idle"
var facing := Vector2(1, 1)
var walk_speed := 1.0
var time := 0.0
var blinking := false
## Kept for callers of the old rig: the sheet has no glance.
var looking := 0.0
## The work cell while working ("" works back turned).
var work_pose := ""
## The idle cell while a mood shows ("" none).
var mood_pose := ""

var sheet: MomoSheet
var body: Sprite2D
var _view := "front"
var _rng := RandomNumberGenerator.new()
var _next_blink := 2.0
var _blink_until := -1.0
var _cell := ""
## A job's loop (Step 67): the animation playing, the seconds into this pass
## of it, and the pause this pass ends with (varied each pass, so a Momo at a
## long stage does not swing like a metronome).
var _loop_anim := ""
var _loop_t := 0.0
var _loop_rest := 0.0
## Reduced motion slows a job's loop to this share of its speed.
const REDUCED_PACE := 0.6
## Step 68: the tool lands -- the loop entered its animation's `contact` frame
## (the strike, the pour, the drop into the basket). Once per pass; the sound
## of it is the listener's (MomoViews -> AudioService.tap), quiet and rare.
signal struck(pose: String)
var _loop_index := -1
## Step 76: holds the animation on its frame `held` (-1 plays on) -- how the
## browser tests look at one frame exactly (main.gd `dev_hold_momo`).
var held := -1


func setup(_lib: SpriteLibrary = null, seed_value: int = 0) -> void:
	sheet = MomoSheet.shared()
	_rng.seed = seed_value
	_next_blink = _rng.randf_range(1.5, 4.0)
	body = Sprite2D.new()
	body.name = "Body"
	body.texture = sheet.texture
	body.region_enabled = true
	body.centered = false
	body.offset = -sheet.pivot
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(body)
	tick(0.0)


func set_state(p_state: String) -> void:
	if STATES.has(p_state):
		state = p_state


## Screen-space direction Momo looks or walks towards. Up the screen shows
## the back, straight across the side; left is the right mirrored.
func face(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	facing = direction
	var ax := absf(direction.x)
	var ay := absf(direction.y)
	if direction.y < -0.15 and ay > ax * 0.35:
		_view = "back"
	elif ax > ay * 2.5:
		_view = "side"
	else:
		_view = "front"
	scale.x = -1.0 if direction.x < 0.0 else 1.0


func is_back_view() -> bool:
	return _view == "back"


## "front", "back" or "side".
func view() -> String:
	return _view


## The animation the state, view, job and mood pick now.
func animation() -> String:
	match state:
		"walk":
			return "walk_" + _view
		"work":
			if work_pose != "" and sheet.animations.has("work_" + work_pose):
				return "work_" + work_pose
			return work_pose if WORK_POSES.has(work_pose) else "work_back"
		"sit", "sleep":
			return state
	if MOOD_POSES.has(mood_pose):
		return mood_pose
	return "idle_" + _view


## The sheet cell on show.
func cell_name() -> String:
	return _cell


## Zoomed far out the body poses every `lod_step` frames (with the time that
## passed), which nobody can tell at that size.
var lod_step := 1
var _lod_frame := 0
var _lod_delta := 0.0


func _process(delta: float) -> void:
	if lod_step <= 1:
		tick(delta)
		return
	_lod_delta += delta
	_lod_frame += 1
	if _lod_frame % lod_step == 0:
		tick(_lod_delta)
		_lod_delta = 0.0


## Advances the animation by `delta` seconds and shows its cell. Pure
## presentation: it never touches the simulation.
func tick(delta: float) -> void:
	time += delta
	_update_blink()
	var anim := animation()
	var frames := sheet.frames(anim)
	var name := String(frames[0]) if not frames.is_empty() else "front_idle"
	var phase := 0.0
	var timed: Array = sheet.animations.get(anim, {}).get("durations", [])
	var looped := frames.size() > 1 and timed.size() == frames.size()
	if not looped:
		# Out of the loop: going back to work starts at the wind-up.
		_loop_anim = ""
		_loop_index = -1
	if held >= 0 and not frames.is_empty():
		name = String(frames[held % frames.size()])
	elif looped:
		var index := _loop_frame(anim, timed, delta)
		name = String(frames[index])
		if index != _loop_index:
			_loop_index = index
			if index == int(sheet.animations[anim].get("contact", -1)):
				struck.emit(work_pose)
	elif frames.size() > 1:
		phase = time * sheet.fps(anim) * walk_speed
		name = String(frames[int(phase) % frames.size()])
	elif anim == "idle_front" and blinking:
		name = String(sheet.animations[anim].get("blink", name))
	if name != _cell:
		_cell = name
		body.texture = sheet.texture_of(name)
		body.region_rect = sheet.region(name)
		body.offset = -sheet.pivot_of(name)
	var s := HEIGHT / sheet.stand_height_of(name)
	var breathe := 0.0 if state == "walk" else sin(time * TAU * (0.22 if state == "sleep" else 0.45))
	body.scale = Vector2(s * (1.0 - 0.006 * breathe), s * (1.0 + 0.012 * breathe))
	# A bob in each step: highest as the feet pass (frames B).
	body.position = Vector2(0, -absf(sin(phase * PI / 2.0)) * 1.6) if state == "walk" else Vector2.ZERO
	queue_redraw()


## The frame of a timed loop (a job's: wind-up, swing, strike, recover --
## each frame held its own `durations` seconds, then the loop's `rest` on the
## last, varied 0.6-1.6x every pass). A new animation starts at its first
## frame. Presentation only: it reads the real seconds that passed, never the
## simulation's clock, so a stage's length (or a time multiplier) does not
## change how fast Momo swings -- and a frame never finishes any work.
func _loop_frame(anim: String, timed: Array, delta: float) -> int:
	var pace := REDUCED_PACE if FxPrefs.reduced_motion else 1.0
	if anim != _loop_anim:
		_loop_anim = anim
		_loop_t = 0.0
		_loop_rest = _next_rest(anim)
	else:
		_loop_t += delta * pace
	var total := 0.0
	for d: Variant in timed:
		total += float(d)
	if _loop_t >= total + _loop_rest:
		_loop_t = fmod(_loop_t - total - _loop_rest, maxf(total, 0.001))
		_loop_rest = _next_rest(anim)
	var t := 0.0
	for i in timed.size():
		t += float(timed[i])
		if _loop_t < t:
			return i
	return timed.size() - 1


func _next_rest(anim: String) -> float:
	return float(sheet.animations.get(anim, {}).get("rest", 0.0)) * _rng.randf_range(0.6, 1.6)


## The job loop's frame index now (-1 when no timed loop plays), for tests.
func loop_index() -> int:
	var timed: Array = sheet.animations.get(_loop_anim, {}).get("durations", [])
	if timed.is_empty() or animation() != _loop_anim:
		return -1
	var t := 0.0
	for i in timed.size():
		t += float(timed[i])
		if _loop_t < t:
			return i
	return timed.size() - 1


func _update_blink() -> void:
	if time >= _blink_until and blinking:
		blinking = false
	if time >= _next_blink:
		blinking = true
		_blink_until = time + 0.13
		_next_blink = time + _rng.randf_range(2.2, 5.0)


## Where a held tool goes (front view, in this node's space).
func hand_point() -> Vector2:
	return Vector2(13, -26) + body.position


func _draw() -> void:
	# A soft shadow on the ground under the feet.
	var w := 22.0 if state != "sleep" else 30.0
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, w, Color(0.05, 0.15, 0.1, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state == "sleep":
		for i in 3:
			var k := fposmod(time * 0.35 + i / 3.0, 1.0)
			# From the head (the sleeping cell lies head left, tail right).
			var p := Vector2(-28.0 + k * 10.0, -30.0 - k * 26.0)
			var sz := 3.0 + i
			var c := Color(0.55, 0.75, 1.0, 1.0 - k)
			draw_line(p, p + Vector2(sz, 0), c, 1.6, true)
			draw_line(p + Vector2(sz, 0), p + Vector2(0, sz), c, 1.6, true)
			draw_line(p + Vector2(0, sz), p + Vector2(sz, sz), c, 1.6, true)
