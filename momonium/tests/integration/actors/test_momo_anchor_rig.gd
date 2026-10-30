extends "res://tests/framework/test_case.gd"

## Step 76: the real MomoRig draws every frame with Momo's feet on the node's
## origin -- where the simulation stands a Momo, its shadow, its tap area and
## its depth sort -- in every state, view, job and mood, facing either way,
## at any size, through a whole working loop, across every change of state,
## and for many Momos at once (design/MOMO_ANCHORS.md).
##
## Where the feet are is measured from the pictures themselves (the two
## feet's contacts, tools/art/gen/momo_anchor.gd), not taken from the pivot
## the rig offsets by; a frame whose root was written down (a hidden foot,
## kneeling) is held to that root.

const Anchor := preload("res://tools/art/gen/momo_anchor.gd")
const Report := preload("res://tools/art/gen/momo_anchor_report.gd")

## Island pixels (at the rig's scale 1) the feet may be off the origin: the
## half texel a pivot is rounded to, drawn at 72 px per 160-200 texels.
const TOL := 0.5
## A walk bobs (MomoRig: 1.6 px at the passing frames) -- on purpose.
const BOB := 1.7

var sheet: MomoSheet
var cal: MomoCalibration
var rigs: Array[MomoRig] = []
## name -> the measured point between the feet (both planted), from the
## frame's top-left.
static var _measured: Dictionary = {}
## The frames whose root is written in the source maps.
static var _written: Dictionary = {}


func before_each() -> void:
	sheet = MomoSheet.shared()
	if _measured.is_empty():
		var frames: Dictionary = Report.load_frames("res://assets/momo/momo_work", "res://assets/momo/momo_sheet")
		for n: String in frames["frames"]:
			var f: Dictionary = frames["frames"][n]
			var m := Anchor.measure(f["img"], float(f["h"]))
			if (m["contacts"] as Array).size() == 2 and not (m["lifted"] as Array).has(true):
				_measured[n] = Anchor._between(m["contacts"])
		for pair: Array in [["res://assets/src/png/momo/cells.json", "cells"], ["res://assets/src/png/momo_work/frames.json", "frames"]]:
			var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(pair[0])))
			for e: Dictionary in cfg[pair[1]]:
				if e.has("root"):
					_written[String(e["name"])] = true
	cal = MomoCalibration.new()
	cal.sheet = sheet
	for path: String in [MomoSheet.MAP, MomoSheet.WORK_MAP]:
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for e: Dictionary in m.get("cells", []) + m.get("frames", []):
			cal.maps[String(e["name"])] = e
	cal.specs.clear()
	for s: Array in MomoCalibration.STATES:
		cal.specs.append(s)
	for job: String in MomoCalibration.JOBS:
		cal.specs.append([job, "work", Vector2(-1, -0.4), job, ""])


func after_each() -> void:
	for r in rigs:
		r.queue_free()
	rigs.clear()
	cal.free()
	await tree.process_frame


func _rig(at := Vector2.ZERO, seed_value := 7) -> MomoRig:
	var r := MomoRig.new()
	tree.root.add_child(r)
	r.setup(null, seed_value)
	r.set_process(false)
	r.position = at
	rigs.append(r)
	return r


## Where the frame on show puts Momo's feet, in the rig's parent's space: the
## middle of the two measured feet, or the written root.
func _feet(r: MomoRig) -> Vector2:
	var n := r.cell_name()
	var p: Vector2 = sheet.pivot_of(n) if _written.has(n) or not _measured.has(n) else _measured[n]
	if r.state == "walk" and _measured.has(n):
		# A walk stands by its head over its feet's line: only the line is
		# the feet's.
		p = Vector2(sheet.pivot_of(n).x, (_measured[n] as Vector2).y)
	return MomoCalibration.to_parent(r, p)


func _check(r: MomoRig, what: String) -> void:
	var d := _feet(r) - r.position
	var s := absf(r.scale.y)
	var y_tol := (BOB + TOL) * s if r.state == "walk" else TOL * s
	assert_true(absf(d.x) <= TOL * s and absf(d.y) <= y_tol, "%s %s: the feet on the spot (%s)" % [what, r.cell_name(), d])


func test_every_frame_stands_on_the_spot_either_way_at_any_size() -> void:
	var n := 0
	for left: bool in [true, false]:
		cal.facing_left = left
		for size: float in [1.0, 2.2, 0.6]:
			for spec: Array in cal.specs:
				var r := _rig(Vector2(300, 400))
				var frames := cal.frames_of(spec, r)
				for i in frames.size():
					cal.hold(r, spec, i)
					r.scale = Vector2(r.scale.x * size, size)
					_check(r, "%s %s x%.1f" % [spec[0], "left" if left else "right", size])
					r.scale = Vector2(signf(r.scale.x), 1.0)
					n += 1
				r.queue_free()
				rigs.erase(r)
	assert_true(n >= 6 * 60, "every frame of every animation, both ways, three sizes (%d)" % n)


func test_a_working_loop_stays_on_the_spot() -> void:
	for job: String in MomoCalibration.JOBS:
		var r := _rig()
		r.set_state("work")
		r.work_pose = job
		r.face(Vector2(-1, -0.4))
		var seen := {}
		for i in 60 * 4:
			r.tick(1.0 / 60.0)
			seen[r.cell_name()] = true
			_check(r, job)
		assert_true(seen.size() >= 4, "%s: its four frames played (%s)" % [job, seen.keys()])


func test_changing_what_momo_does_keeps_its_feet_on_the_spot() -> void:
	var r := _rig(Vector2(120, 80))
	# A day: walk in, wait at the job (its back), work, a mood, sit, sleep,
	# wake and walk away -- the rig's own clock between them.
	var day := [["walk", Vector2(0.5, 1), "", ""], ["idle", Vector2(-1, -0.4), "", ""], ["work", Vector2(-1, -0.4), "dig", ""],
		["idle", Vector2(-1, -0.4), "", ""], ["work", Vector2(-1, -0.4), "water", ""], ["walk", Vector2(1, 0), "", ""],
		["idle", Vector2(1, 0), "", ""], ["idle", Vector2(0.5, 1), "", "happy"], ["idle", Vector2(0.5, 1), "", ""],
		["sit", Vector2(0.5, 1), "", ""], ["sleep", Vector2(0.5, 1), "", ""], ["idle", Vector2(0.3, -1), "", ""],
		["walk", Vector2(0.3, -1), "", ""], ["work", Vector2(-1, -0.4), "chop", ""], ["walk", Vector2(-1, 0.5), "", ""]]
	var before := ""
	for step: Array in day:
		r.set_state(String(step[0]))
		r.face(step[1])
		r.work_pose = String(step[2])
		r.mood_pose = String(step[3])
		r.tick(0.0)
		_check(r, "%s -> %s" % [before, r.cell_name()])
		for i in 20:
			r.tick(1.0 / 30.0)
			_check(r, String(step[0]))
		before = r.cell_name()


func test_many_momos_each_on_its_own_spot() -> void:
	var jobs := ["dig", "water", "chop", "hammer", "replant", "harvest", "sow", "stoke"]
	var all: Array[MomoRig] = []
	for i in jobs.size():
		var r := _rig(Vector2(60 + i * 40, 200 + (i % 3) * 30), i + 1)
		r.set_state("work")
		r.work_pose = jobs[i]
		r.face(Vector2(-1, -0.4) if i % 2 == 0 else Vector2(1, -0.4))
		all.append(r)
	for t in 90:
		for r in all:
			r.tick(1.0 / 30.0)
			_check(r, r.work_pose)
