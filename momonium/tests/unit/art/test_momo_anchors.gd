extends "res://tests/framework/test_case.gd"

## Step 76: every Momo picture stands on its root (design/MOMO_ANCHORS.md) --
## the point on the ground between its feet, measured from the drawing
## (tools/art/gen/momo_anchor.gd), never its box. Every frame the rig can
## show exists, inside its texture, with a pivot that is its measured root;
## a frame whose feet do not say has a written root and a reason; no
## animation moves Momo as a whole between frames; and the Step 66 measure
## (the lowest cream pixels) fails these checks -- they catch the jumps the
## owner saw.

const Anchor := preload("res://tools/art/gen/momo_anchor.gd")
const Report := preload("res://tools/art/gen/momo_anchor_report.gd")
## A pivot this close to the measured root, in texels (packing rounds a
## pivot to half a texel, a sheet cell's placement to a whole one).
const ON_ROOT := 0.75
## Island pixels at zoom 1 (MomoRig.HEIGHT for a stand height):
## the steadier foot of a two-footed pair moves at most this much (the hop
## at the end of sowing and the throw's step are the most, 6) ...
const MAX_SLIDE := 6.5
## ... the torso at most this much (bending to the tomato is the most, 14;
## Step 66's measure moved it 56 at the pickaxe's strike) ...
const MAX_TORSO := 16.0
## ... and the line the drawing meets the ground on not at all.
const MAX_FLOAT := 0.5

var frames: Dictionary


func before_each() -> void:
	if frames.is_empty():
		frames = Report.load_frames("res://assets/momo/momo_work", "res://assets/momo/momo_sheet")


func _maps() -> Array:
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/momo/momo_sheet.json"))
	var work: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/momo/momo_work.json"))
	return [sheet, work]


func _sources() -> Dictionary:
	var out := {}
	for pair: Array in [["res://assets/src/png/momo/cells.json", "cells"], ["res://assets/src/png/momo_work/frames.json", "frames"]]:
		var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(pair[0])))
		for e: Dictionary in cfg[pair[1]]:
			out[String(e["name"])] = e
	return out


## Each animation's frames, their measures and their roots -- the sheet's
## standing poses per view (a hidden foot placed from the view's two-footed
## poses), its walks by the head (as the view's standing pose has it), the
## atlas's jobs per animation -- as the builders find them.
func _groups() -> Array:
	var sheet: Dictionary = _maps()[0]
	var work: Dictionary = _maps()[1]
	var src := _sources()
	var out: Array = []
	var h := float(sheet["stand_height"])
	for view: String in ["front", "back", "side"]:
		var names: Array = []
		for c: Dictionary in sheet["cells"]:
			if String(c["view"]) == view and String(c["state"]) != "walk":
				names.append(String(c["name"]))
		var ms: Array = names.map(func(n: String) -> Dictionary: return Anchor.measure(frames["frames"][n]["img"], h))
		var roots := Anchor.roots(ms, h, names.map(func(n: String) -> Dictionary: return (src[n] as Dictionary).get("root", {})))
		out.append({"name": view, "names": names, "ms": ms, "roots": roots, "h": h})
		var anchor := "%s_idle" % view
		var a := names.find(anchor)
		var dx := (roots[a]["root"] as Vector2).x - float(ms[a]["head_x"])
		var walk: Array = []
		for n: String in sheet["animations"]["walk_" + view]["cells"]:
			if not walk.has(n):
				walk.append(n)
		var wms: Array = walk.map(func(n: String) -> Dictionary: return Anchor.measure(frames["frames"][n]["img"], h))
		out.append({"name": "walk_" + view, "names": walk, "ms": wms, "roots": Anchor.roots(wms, h, walk.map(func(_n: String) -> Dictionary: return {"head": dx})), "h": h})
	var wh := float(work["stand_height"])
	for anim: String in work["animations"]:
		var names: Array = work["animations"][anim]["cells"]
		var ms: Array = names.map(func(n: String) -> Dictionary: return Anchor.measure(frames["frames"][n]["img"], wh))
		var specs: Array = names.map(func(n: String) -> Dictionary: return (src[n] as Dictionary).get("root", {}))
		out.append({"name": anim, "names": names, "ms": ms, "roots": Anchor.roots(ms, wh, specs), "h": wh})
	return out


func test_every_frame_the_rig_plays_exists_inside_its_texture() -> void:
	var sheet := MomoSheet.shared()
	var seen := 0
	for anim: String in sheet.animations:
		var names: Array = sheet.frames(anim).duplicate()
		var blink := String(sheet.animations[anim].get("blink", ""))
		if blink != "":
			names.append(blink)
		for n: String in names:
			seen += 1
			assert_true(sheet.cells.has(n) or sheet.work_frames.has(n), "%s: %s exists" % [anim, n])
			var tex := sheet.texture_of(n)
			var r := sheet.region(n)
			assert_true(Rect2(Vector2.ZERO, tex.get_size()).encloses(r), "%s inside its texture %s" % [n, r])
			var pv := sheet.pivot_of(n)
			assert_true(pv.x >= 0.0 and pv.x <= r.size.x, "%s: its root inside its width (%s)" % [n, pv])
			assert_true(pv.y >= r.size.y * 0.5 and pv.y <= r.size.y + 6.0, "%s: its root near its bottom (%s of %s)" % [n, pv, r.size])
			assert_true(String(sheet.marks(n)["method"]) != "", "%s: the map says how its root was found" % n)
	assert_true(seen >= 65, "every frame of every animation (%d)" % seen)


## The pivot each map ships is the root measured from the drawing now --
## so a picture redrawn (a new generation, a hand edit) and not rebuilt, or
## rebuilt by a tool that measures differently, fails here.
func test_every_pivot_is_the_measured_root() -> void:
	var maps := _maps()
	var sheet: Dictionary = maps[0]
	var work_pivots := {}
	var methods := {}
	for f: Dictionary in maps[1]["frames"]:
		work_pivots[f["name"]] = Vector2(float(f["pivot"][0]), float(f["pivot"][1]))
		methods[f["name"]] = String(f["root"])
	for c: Dictionary in sheet["cells"]:
		methods[c["name"]] = String(c["root"])
	var pivot := Vector2(float(sheet["pivot"][0]), float(sheet["pivot"][1]))
	for g: Dictionary in _groups():
		for i in (g["names"] as Array).size():
			var n: String = g["names"][i]
			var r: Dictionary = g["roots"][i]
			assert_true(String(r["method"]) != "error", "%s: %s" % [n, r.get("error", "")])
			var shipped: Vector2 = work_pivots.get(n, pivot)
			assert_true(shipped.distance_to(r["root"]) <= ON_ROOT, "%s: the pivot %s on the measured root %s" % [n, shipped, r["root"]])
			assert_eq(methods[n], String(r["method"]), "%s: found the way the map says" % n)


## The drawing says where Momo stands when both feet are on the ground;
## anything else is written down, with a reason, and a frame with neither
## stops the build (the measure has no answer for it).
func test_a_root_the_feet_do_not_give_is_written_with_a_reason() -> void:
	var src := _sources()
	var authored := 0
	for g: Dictionary in _groups():
		for i in (g["names"] as Array).size():
			var n: String = g["names"][i]
			var m: Dictionary = g["ms"][i]
			var two := (m["contacts"] as Array).size() == 2 and not (m["lifted"] as Array).has(true)
			var spec: Dictionary = (src[n] as Dictionary).get("root", {})
			if String(g["name"]).begins_with("walk_"):
				continue
			if not two:
				assert_false(spec.is_empty(), "%s: no two planted feet -- its root is written down" % n)
				# And without it, the measure refuses to guess.
				var bare := Anchor.roots([m], float(g["h"]), [{}])
				assert_eq(String(bare[0]["method"]), "error", "%s: no guess without it" % n)
			if not spec.is_empty():
				authored += 1
				assert_true(String(spec.get("why", "")).length() > 20, "%s: why (%s)" % [n, spec.get("why", "")])
	assert_between(authored, 6, 12, "a few frames written down, the rest measured (%d)" % authored)


## Feet, not effects: the frames where Step 66 took rock dust, a jet of
## water, a spark or an axe's edge for the feet find two feet under the body.
func test_the_feet_are_feet_not_dust_water_or_sparks() -> void:
	for n: String in ["dig_2", "water_2", "chop_1", "chop_2", "hammer_3", "stoke_2"]:
		var f: Dictionary = frames["frames"][n]
		var m := Anchor.measure(f["img"], float(f["h"]))
		assert_eq((m["contacts"] as Array).size(), 2, "%s: two feet" % n)
		var torso: Vector2 = m["torso"]
		for c: Vector2 in m["contacts"]:
			assert_true(absf(c.x - torso.x) < float(f["h"]) * 0.45, "%s: a foot under the body (%s, torso %s)" % [n, c, torso])
			assert_true(c.y > torso.y + float(f["h"]) * 0.2, "%s: below the torso" % n)


func test_no_animation_moves_momo_as_a_whole() -> void:
	for g: Dictionary in _groups():
		for seq: Array in _sequences(g):
			var names: Array = seq[0]
			var ms: Array = seq[1]
			var roots: Array = seq[2]
			var label := "%s %s" % [g["name"], names if names.size() == 2 else ""]
			var pivots: Array = names.map(func(n: String) -> Vector2: return frames["frames"][n]["pivot"])
			var j := Report.jitter(names, ms, _specs_of(names), pivots, roots, frames["frames"])
			assert_true(float(j["slide"]) <= MAX_SLIDE, "%s: the planted foot stays (%.1f px)" % [label, j["slide"]])
			if bool(seq[3]):
				assert_true(float(j["torso"]) <= MAX_TORSO, "%s: the body does not jump (%.1f px)" % [label, j["torso"]])
			assert_true(float(j["float"]) <= MAX_FLOAT, "%s: on the ground in every frame (%.1f px)" % [label, j["float"]])
			assert_true(float(j["off"]) <= 0.5, "%s: drawn on its root (%.2f px)" % [label, j["off"]])


## What plays in a row: a job's or a walk's loop; for a view's still poses,
## each one after the standing pose and back (a blink, a mood, sitting down,
## lying down) -- [names, measures, roots, whether the torso keeps its place:
## not when Momo sits or lies down].
func _sequences(g: Dictionary) -> Array:
	var names: Array = g["names"]
	if String(g["name"]) not in ["front", "back", "side"]:
		return [[names, g["ms"], g["roots"], true]]
	var out: Array = []
	var a := names.find("%s_idle" % g["name"])
	for i in names.size():
		if i != a:
			out.append([[names[a], names[i]], [g["ms"][a], g["ms"][i]], [g["roots"][a], g["roots"][i]], not names[i] in ["sit", "sleep"]])
	return out


## These checks fail on the art as Step 66 anchored it: the root at the
## lowest cream pixels moves Momo tens of pixels at the strike of the
## pickaxe, the jet of water, the axe and the hammer.
func test_the_step_66_measure_fails_these_checks() -> void:
	var failing: Array[String] = []
	for g: Dictionary in _groups():
		var names: Array = g["names"]
		if not String(g["name"]).begins_with("work_"):
			continue
		var old: Array = names.map(func(n: String) -> Vector2: return _lowest_cream(frames["frames"][n]["img"]))
		var j := Report.jitter(names, g["ms"], _specs_of(names), old, g["roots"], frames["frames"])
		if float(j["torso"]) > MAX_TORSO or float(j["slide"]) > MAX_SLIDE:
			failing.append(String(g["name"]))
	for anim: String in ["work_dig", "work_water", "work_chop", "work_hammer"]:
		assert_true(failing.has(anim), "%s fails with the lowest cream pixels (%s)" % [anim, failing])


func _specs_of(names: Array) -> Array:
	var src := _sources()
	return names.map(func(n: String) -> Dictionary: return (src[n] as Dictionary).get("root", {}))


## Step 66's measure (build_momo_work.gd's `feet_point` until Step 76): the
## middle of the cream in the lowest 6% of the cream, on its bottom row.
static func _lowest_cream(img: Image) -> Vector2:
	var lo := Vector2i(img.get_width(), img.get_height())
	var hi := Vector2i(-1, -1)
	for y in img.get_height():
		for x in img.get_width():
			if Anchor.is_cream(img.get_pixel(x, y)):
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var y0 := hi.y + 1 - maxi(2, int((hi.y - lo.y + 1) * 0.06))
	var sx := 0.0
	var n := 0
	for y in range(y0, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if Anchor.is_cream(img.get_pixel(x, y)):
				sx += x + 0.5
				n += 1
	return Vector2(sx / maxi(n, 1), hi.y + 1)
