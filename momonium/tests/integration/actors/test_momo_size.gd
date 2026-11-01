extends "res://tests/framework/test_case.gd"

## Step 77: every Momo is drawn at `art.momo_size.scale` (0.8) of its size
## from Step 51 to Step 76 -- one number, applied once, as the rig's scale
## about the root between its feet -- in every state, view, job and mood,
## either way it faces. The feet stay on the map point the simulation gives;
## the tap box, the ring, the hop, the mood bubble's place and the Schedule
## button's room follow the smaller body; the depth sort, walking and work do
## not change.
##
## The drawn size is measured from the pictures (each frame's opaque pixels,
## through the transforms the island draws it with), and the feet from the
## two feet in them (tools/art/gen/momo_anchor.gd) -- not from the scale the
## rig was given.

const MainScene := preload("res://scenes/main.tscn")
const Anchor := preload("res://tools/art/gen/momo_anchor.gd")
const Report := preload("res://tools/art/gen/momo_anchor_report.gd")

## Island pixels at size 1 the feet may be off the spot (test_momo_anchor_rig).
const TOL := 0.5
const BOB := 1.7

var main: Node
var sim: Simulation
var momos: MomoSystem
var bs: BuildingSystem
var views: MomoViews
var layer: EntityLayer
var size := 0.0
var cal: MomoCalibration
## name -> the frame's opaque pixels (its rect's top-left at 0).
static var _used: Dictionary = {}
## name -> the measured point between the two planted feet.
static var _feet: Dictionary = {}
static var _written: Dictionary = {}


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	momos = sim.system(&"momo")
	bs = sim.system(&"buildings")
	views = main.get("momo_views")
	layer = main.get("entities")
	size = sim.data.get_float("art", "momo_size.scale", 0.0)
	var world: WorldSystem = sim.system(&"world")
	for x in 4:
		for y in 4:
			world.add_land(Vector2i(x, y))
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	if _used.is_empty():
		var frames: Dictionary = Report.load_frames("res://assets/momo/momo_work", "res://assets/momo/momo_sheet")
		for n: String in frames["frames"]:
			var f: Dictionary = frames["frames"][n]
			_used[n] = (f["img"] as Image).get_used_rect()
			var m := Anchor.measure(f["img"], float(f["h"]))
			if (m["contacts"] as Array).size() == 2 and not (m["lifted"] as Array).has(true):
				_feet[n] = Anchor._between(m["contacts"])
		for pair: Array in [["res://assets/src/png/momo/cells.json", "cells"], ["res://assets/src/png/momo_work/frames.json", "frames"]]:
			var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(pair[0])))
			for e: Dictionary in cfg[pair[1]]:
				if e.has("root"):
					_written[String(e["name"])] = true
	cal = MomoCalibration.new()
	cal.sheet = MomoSheet.shared()
	for s: Array in MomoCalibration.STATES:
		cal.specs.append(s)
	for job: String in MomoCalibration.JOBS:
		cal.specs.append([job, "work", Vector2(-1, -0.4), job, ""])


func after_each() -> void:
	cal.free()
	main.queue_free()
	await tree.process_frame


func _momo_at(at: Vector2) -> MomoActor:
	var id := momos.add_momo(at)
	views.sync()
	views._process(0.0)
	var a := views.actor(id)
	a.set_process(false)
	a.rig.set_process(false)
	a._process(0.0)
	return a


## The frame on show as drawn on the island (layer space): its opaque box.
func _drawn(a: MomoActor) -> Rect2:
	var r := a.rig
	var u: Rect2i = _used[r.cell_name()]
	var p0 := a.position + MomoCalibration.to_parent(r, Vector2(u.position))
	var p1 := a.position + MomoCalibration.to_parent(r, Vector2(u.end))
	return Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), (p1 - p0).abs())


## Where the frame on show puts the feet (layer space): the two measured
## feet's middle, or the written root (a walk: its head over the feet's line).
func _feet_at(a: MomoActor) -> Vector2:
	var r := a.rig
	var n := r.cell_name()
	var p: Vector2 = r.sheet.pivot_of(n) if _written.has(n) or not _feet.has(n) else _feet[n]
	if r.state == "walk" and _feet.has(n):
		p = Vector2(r.sheet.pivot_of(n).x, (_feet[n] as Vector2).y)
	return a.position + MomoCalibration.to_parent(r, p)


func test_one_size_in_the_data_given_to_every_momo_once() -> void:
	assert_near(size, 0.8, 0.0001, "80% of the Step 76 Momo")
	var a := _momo_at(Vector2(1.5, 1.5))
	var hired := sim.execute({"type": "momo.hire"})
	views.sync()
	var b := views.actor(int(hired.get("id", 0))) if hired.get("ok", false) else _momo_at(Vector2(2.5, 1.5))
	for m: MomoActor in [a, b]:
		assert_eq(m.size, size, "%s: the data's size" % m.name)
		assert_eq(m.rig.size, size, "%s: handed to the rig" % m.name)
		assert_eq(m.mood_bubble.size, size, "%s: and to its bubble" % m.name)
		assert_near(absf(m.rig.scale.x), size, 0.0001, "%s: the rig's scale" % m.name)
		assert_near(m.rig.scale.y, size, 0.0001, "%s: both ways" % m.name)
	# Not twice: the body's own scale is still the sheet's (HEIGHT per stand
	# height), so a standing Momo is 72 x 0.8 tall, not 72 x 0.8 x 0.8.
	a.rig.set_state("idle")
	a.rig.face(Vector2(0.5, 1))
	a.rig.tick(0.0)
	assert_near(a.rig.body.scale.y, MomoRig.HEIGHT / a.rig.sheet.stand_height_of(a.rig.cell_name()), 0.02, "the body itself unscaled")
	var top := _drawn(a).position.y
	assert_near(a.ground().y - top, MomoRig.HEIGHT * size, 1.0, "front, standing: %.1f px tall on the island (was 72)" % (a.ground().y - top))


func test_every_frame_is_drawn_at_the_size_with_its_feet_on_the_spot() -> void:
	var a := _momo_at(Vector2(1.6, 1.4))
	var n := 0
	for left: bool in [true, false]:
		cal.facing_left = left
		for spec: Array in cal.specs:
			var frames := cal.frames_of(spec, a.rig)
			for i in frames.size():
				cal.hold(a.rig, spec, i)
				var what := "%s %s %s" % [spec[0], "left" if left else "right", a.rig.cell_name()]
				var small := _drawn(a)
				var feet := _feet_at(a)
				a.rig.size = 1.0
				var big := _drawn(a)
				var feet1 := _feet_at(a)
				a.rig.size = size
				assert_near(small.size.y / big.size.y, size, 0.01, "%s: as tall x%.2f" % [what, small.size.y / big.size.y])
				assert_near(small.size.x / big.size.x, size, 0.01, "%s: as wide" % what)
				var d := feet - a.ground()
				var y_tol := (BOB + TOL) * size if a.rig.state == "walk" else TOL * size
				assert_true(absf(d.x) <= TOL * size and absf(d.y) <= y_tol, "%s: the feet on its spot (%s)" % [what, d])
				var d1 := feet1 - a.ground()
				assert_true(absf(d1.x) <= TOL and absf(d1.y) <= (BOB + TOL if a.rig.state == "walk" else TOL), "%s: as at size 1 (%s)" % [what, d1])
				n += 1
	assert_true(n >= 2 * 60, "every frame of every animation, both ways (%d)" % n)


func test_the_tap_box_is_the_smaller_body_and_buildings_stay_tappable() -> void:
	var lab := bs.place_instant("research", Vector2i(1, 1))
	await tree.process_frame
	var a := _momo_at(Vector2(2.1, 2.1))
	var id := int(a.name.trim_prefix("Momo_"))
	var g := a.ground()
	var slack: float = sim.data.get_float("art", "momo_size.hit_slack", -1.0)
	assert_between(slack, 2.0, 8.0, "a little room for a finger (%.1f island px)" % slack)
	var body := Rect2(g + MomoActor.BODY.position * size, MomoActor.BODY.size * size)
	assert_eq(a.hit_rect(), body.grow_individual(slack, slack, slack, 0.0), "the body at its size, a little wider and taller")
	assert_near(a.hit_rect().end.y - g.y, MomoActor.BODY.end.y * size, 0.001, "not reaching further under the feet than the body")
	# Its marks (torso, eyes) and its drawn standing body are in the box.
	a.rig.set_state("idle")
	a.rig.face(Vector2(0.5, 1))
	a.rig.tick(0.0)
	var drawn := _drawn(a)
	var marks := a.rig.sheet.marks(a.rig.cell_name())
	for k: String in ["torso", "eyes"]:
		var p := a.position + MomoCalibration.to_parent(a.rig, marks[k])
		assert_true(a.hit_rect().has_point(p), "its %s are where a tap finds it" % k)
		assert_eq(views.hit(p), id, "and the views find it by its %s" % k)
	assert_true(a.hit_rect().has_point(Vector2(g.x, drawn.position.y + 2.0)), "the top of its head")
	assert_true(drawn.position.y - a.hit_rect().position.y <= slack + 4.0 * size + 1.0, "the box ends just over the head drawn (%.1f)" % (drawn.position.y - a.hit_rect().position.y))
	# Where the Step 76 box reached and the smaller Momo does not: the lab
	# behind it, as a tap there now gets.
	var over := g + Vector2(0, -74)
	assert_false(a.hit_rect().has_point(over), "over its head, where the old box reached: not the Momo")
	var selection: SelectionController = main.get("selection")
	selection.on_tap(Vector2.ZERO, over)
	assert_eq(selection.kind, "building", "a tap there selects the lab behind it")
	assert_eq(selection.selected_id, lab, "that lab")
	selection.deselect()
	selection.on_tap(Vector2.ZERO, g + Vector2(0, -MomoRig.HEIGHT * size * 0.5))
	assert_eq(selection.kind, "momo", "its middle selects the Momo")
	assert_eq(selection.selected_id, id, "that Momo")


func test_the_mood_bubble_rides_the_smaller_head() -> void:
	var a := _momo_at(Vector2(1.5, 1.5))
	a.rig.set_state("idle")
	a.rig.face(Vector2(0.5, 1))
	a.rig.tick(0.0)
	var head := _drawn(a).position.y
	var b := a.mood_bubble
	for i in 60:
		b.step(0.05, "free", false, a.rig.position)
	assert_true(b.mood != "", "a mood shows (%s)" % b.mood)
	var gap := head - (a.position.y + b.position.y)
	a.rig.size = 1.0
	b.size = 1.0
	b.step(0.05, "free", false, a.rig.position)
	var gap1 := _drawn(a).position.y - (a.position.y + b.position.y)
	assert_near(gap, gap1, 1.0, "the same gap over the head at 0.8 (%.1f) as at 1 (%.1f)" % [gap, gap1])
	assert_true(gap > 0.0, "over the head, not on it")
	b.size = size
	b.step(0.05, "free", false, a.rig.position)
	assert_near(b.position.x - a.rig.position.x, MoodBubble.ANCHOR.x * size, 1.5, "beside the head as it is now (a little right)")


func test_the_schedule_button_makes_room_for_the_drawn_body() -> void:
	var a := _momo_at(Vector2(1.5, 1.5))
	a.rig.set_state("idle")
	a.rig.face(Vector2(0.5, 1))
	a.rig.tick(0.0)
	var drawn := _drawn(a)
	var zoom := 1.4
	var feet := Vector2(400, 500)
	var safe := Rect2(0, 0, 800, 1000)
	var to_screen := func(p: Vector2) -> Vector2: return feet + (p - a.ground()) * zoom
	var momo := Rect2(to_screen.call(drawn.position), drawn.size * zoom)
	var below: Array = WatchEditor.spot(feet, zoom, safe, [], "below", a.body())
	assert_eq(below[1], "below", "under the feet")
	assert_near(below[0].y - feet.y, (a.body().end.y) * zoom + WatchEditor.GAP, 1.0, "just under them")
	assert_false(Rect2(below[0], WatchEditor.BUTTON).intersects(momo), "not on the Momo")
	# The room under the feet taken (a HUD bar): over the head -- of the
	# smaller Momo, not where the Step 76 head was.
	var bar: Array[Rect2] = [Rect2(0, feet.y + 2.0, 800, 200)]
	var above: Array = WatchEditor.spot(feet, zoom, safe, bar, "below", a.body())
	assert_eq(above[1], "above", "over the head")
	var bottom: float = above[0].y + WatchEditor.BUTTON.y
	assert_true(bottom <= momo.position.y, "clear of the head drawn")
	assert_true(momo.position.y - bottom <= (4.0 * size + 1.0) * zoom + WatchEditor.GAP + 1.0, "close over it (%.1f px)" % (momo.position.y - bottom))
	var old: Array = WatchEditor.spot(feet, zoom, safe, bar, "below")
	assert_true(above[0].y > old[0].y + 10.0, "lower than over a Step 76 Momo (%.0f vs %.0f)" % [above[0].y, old[0].y])
	var side: Array = WatchEditor.spot(feet, zoom, Rect2(0, feet.y - 90.0, 800, 130), [], "below", a.body())
	assert_true(side[1] in ["right", "left"], "no room over or under: beside it (%s)" % side[1])
	var b := Rect2(side[0], WatchEditor.BUTTON)
	assert_false(b.intersects(Rect2(feet + a.body().position * zoom, a.body().size * zoom)), "beside its body, not on it")
	# The ears reach past the body box (68 of 52 px at size 1, as before Step
	# 77): beside the Momo the button may touch an ear's tip, no more.
	assert_true(b.intersection(momo).size.x <= 1.5, "an ear's tip at most (%.1f px)" % b.intersection(momo).size.x)


func test_depth_sort_ring_and_hop_follow_the_feet() -> void:
	var a := _momo_at(Vector2(2.3, 1.8))
	var feet := layer.ground_point(Vector2(2.3, 1.8))
	assert_eq(a.ground(), feet, "its feet where the simulation says")
	assert_near(a.position.y - feet.y, views.depth_lift, 0.001, "sorted by the same lift as before (Step 55)")
	assert_near(a.position.y + a.rig.position.y, feet.y, 0.001, "the drawing lifted back onto the feet")
	a.appear()
	a._process(0.25)
	var hop := feet.y - (a.position.y + a.rig.position.y)
	assert_between(hop, 1.0, 18.0 * size + 0.01, "a hop at its size (%.1f, at most %.1f)" % [hop, 18.0 * size])


func test_old_saves_and_new_hires_are_the_new_size_and_nothing_is_saved() -> void:
	momos.add_momo(Vector2(1.5, 1.5))
	var loaded := SaveService.decode(SaveService.encode(sim))
	assert_eq(loaded["status"], "ok", "the save opens")
	assert_false(JSON.stringify(SaveService.encode(sim)).contains("momo_size"), "the size is not in the save")
	var again := Simulation.from_save(loaded["state"])
	var a := MomoActor.new()
	a.setup(int((again.system(&"momo") as MomoSystem).ids()[0]), again, null, IsoProjection.new())
	assert_eq(a.size, size, "a Momo from a save is drawn at the size")
	assert_eq(a.rig.size, size, "its rig too")
	a.free()


func test_walking_and_work_do_not_read_the_size() -> void:
	var runs: Array[String] = []
	for s: float in [1.0, 0.8, 0.5]:
		var art: Dictionary = GameData.load_default().table("art").duplicate(true)
		art["momo_size"]["scale"] = s
		var run := with_starter_momo(Simulation.new_game(GameData.from_tables({"art": art})))
		var b := (run.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(2, 1))
		run.execute({"type": "momo.assign", "momo": 1, "building": b})
		for i in 240:
			run.advance_ms(250)
		runs.append(JSON.stringify(run.save_state()))
	assert_eq(runs[1], runs[0], "the same island after a minute at 0.8 as at 1")
	assert_eq(runs[2], runs[0], "and at 0.5")
