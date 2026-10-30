extends RefCounted

## Step 76: where Momo stands in a drawing (design/MOMO_ANCHORS.md).
##
## Every Momo picture -- a sheet cell, a work frame -- is drawn with its
## root on the node's origin: the point on the ground between the feet. The
## root is measured from the drawing, never from its bounding box: a raised
## pickaxe, a jet of water, rock dust or a basket on the ground change the
## box (and fooled the Step 66 measure, the lowest cream pixels, into a
## 45 px jump), but not where Momo stands.
##
## The measures, in the drawing's own pixels, `h` = its texels from feet to
## fur curl (the stand height at its density):
##   feet   Momo's round white feet: cream blobs of a foot's size and shape
##          (a foot is a filled oval; a blade's highlight is thin, a drop or
##          a seed is small, a cuff sits above its foot, the tail is high).
##          The pair side by side, a stance apart, that stands lowest and
##          most level; a foot's contact is the middle of its bottom edge,
##          under its outline.
##   body   the cream of Momo itself: blobs big and thick enough to be fur or
##          overalls; its lowest row is where a kneeling Momo meets the ground
##   torso  the middle of the body between a fifth and a half of its height
##          above the ground -- the overalls and the arms in front of them
##   eyes   the two dark filled blobs (the head), when they are open
##   head   the middle of the widest row of the head band (the head and the
##          ears hanging beside it), as Step 51 placed the sheet's cells
## The root of a frame (`roots`, per animation): with both feet on the ground,
## midway between their contacts, on the nearer one's line ("feet").
## Anything else -- one foot hidden, both feet hidden, one foot higher (set
## back, lifted for a step, or a hop?) -- the drawing alone cannot say: the
## frame's `root` in the source map does (with a `why`), and the build
## refuses a frame that has neither. Authored roots (`spec`):
##   {"feet": "both"}           the two feet, one set back rather than lifted
##   {"foot": "left"|"right"}   that foot planted, the other hidden or lifted:
##                              the root where it is from that foot in the
##                              animation's two-footed frames
##   {"foot": "only"}           one foot seen (a side view): its contact
##   {"torso": ...}             the feet hidden or off the ground (kneeling,
##                              sitting, a hop): the torso over the root as in
##                              the two-footed frames, on the body's lowest row
##   {"box": ...}               lying down: the middle of the drawing's
##                              bottom edge
##   {"head": dx}               a walk (the builder's): the head `dx` from the
##                              root, as the view's standing pose has it, on
##                              the lowest foot's line
##   {"at": [x, y]}             a point, in the source picture's pixels

## A foot: a filled oval this wide and tall (shares of `h`), at least this big.
const FOOT_W := Vector2(0.10, 0.25)
const FOOT_H := Vector2(0.045, 0.17)
const FOOT_FILL := 0.45
const FOOT_AREA := 0.004
## The partner foot: beside the first (centres this far apart, shares of h),
## its bottom no more than this much higher.
const STANCE := Vector2(0.12, 0.5)
const PARTNER_RISE := 0.12
## A foot this much (share of h) above the other is lifted, not planted.
const LIFTED := 0.035
## Body blobs: at least this big (share of h squared) and this thick (area
## over the longer side, share of h).
const BODY_AREA := 0.002
const BODY_THICK := 0.035
## The torso band, shares of h above the ground.
const TORSO := Vector2(0.22, 0.5)
## The head band, shares of the drawing's height from its top
## (build_momo_sheet.gd's).
const HEAD_BAND := Vector2(0.18, 0.45)


## Momo's fur and overalls: light, warm and unsaturated (r >= b). Steel is
## blue-grey (b > r), wood and wicker are saturated, outlines are dark.
static func is_cream(c: Color) -> bool:
	return c.a > 0.5 and c.r8 > 200 and c.g8 > 180 and c.b8 > 150 and c.r8 >= c.b8 and c.r8 - c.b8 < 70


## The cream blobs (4-connected): [{rect: Rect2i, area: int, sum: Vector2}].
static func cream_blobs(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var out: Array = []
	for start in w * h:
		if seen[start] == 1 or not is_cream(img.get_pixel(start % w, start / w)):
			continue
		seen[start] = 1
		var stack: Array[int] = [start]
		var lo := Vector2i(w, h)
		var hi := Vector2i(-1, -1)
		var area := 0
		var sum := Vector2.ZERO
		var pixels := PackedInt32Array()
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var x := i % w
			var y := i / w
			area += 1
			sum += Vector2(x + 0.5, y + 0.5)
			pixels.append(i)
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx := x + d.x
				var yy := y + d.y
				if xx < 0 or yy < 0 or xx >= w or yy >= h:
					continue
				var j := yy * w + xx
				if seen[j] == 0 and is_cream(img.get_pixel(xx, yy)):
					seen[j] = 1
					stack.append(j)
		out.append({"rect": Rect2i(lo, hi - lo + Vector2i.ONE), "area": area, "sum": sum, "pixels": pixels})
	return out


static func _is_foot(b: Dictionary, h: float) -> bool:
	var r: Rect2i = b["rect"]
	var fill := float(b["area"]) / float(r.size.x * r.size.y)
	return fill >= FOOT_FILL and float(b["area"]) >= FOOT_AREA * h * h \
		and r.size.x >= FOOT_W.x * h and r.size.x <= FOOT_W.y * h \
		and r.size.y >= FOOT_H.x * h and r.size.y <= FOOT_H.y * h


static func _is_body(b: Dictionary, h: float) -> bool:
	var r: Rect2i = b["rect"]
	return float(b["area"]) >= BODY_AREA * h * h and float(b["area"]) / maxf(r.size.x, r.size.y) >= BODY_THICK * h


## The middle of a foot's bottom edge (its cream; `measure` adds the outline
## under it).
static func contact(foot: Rect2i) -> Vector2:
	return Vector2(foot.position.x + foot.size.x / 2.0, foot.end.y)


## The outline under a point: opaque texels straight down from `at` (the
## row below the cream), at most 6.
static func outline_below(img: Image, at: Vector2) -> int:
	var x := clampi(int(at.x), 0, img.get_width() - 1)
	var n := 0
	while n < 6 and int(at.y) + n < img.get_height() and img.get_pixel(x, int(at.y) + n).a > 0.5 and not is_cream(img.get_pixel(x, int(at.y) + n)):
		n += 1
	return n


## One drawing's measures (see the top): {box, feet: [Rect2i] left to right
## (0, 1 or 2) with `contacts` (under the outline), lifted: [bool], bottom
## (the body's lowest row, under the outline), bottom_x, ground (the planted
## feet's line, else the bottom), torso, eyes (or none: x < 0)}.
static func measure(img: Image, h: float) -> Dictionary:
	var blobs := cream_blobs(img)
	var w := img.get_width()
	var feet: Array[Rect2i] = []
	var cands: Array = blobs.filter(func(b: Dictionary) -> bool: return _is_foot(b, h))
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["rect"] as Rect2i).end.y > (b["rect"] as Rect2i).end.y)
	# The pair that stands lowest and most level: two blobs side by side, a
	# stance apart; a cuff over its foot, a blade's edge low beside one foot
	# make a worse pair than the two feet.
	# Feet are at the bottom: a pair higher than the lowest blob by more
	# than a partner may rise (two paws, a cheek and a cuff) is not one.
	var floor_y := (cands[0]["rect"] as Rect2i).end.y - PARTNER_RISE * h if not cands.is_empty() else 0.0
	var best := -INF
	for i in cands.size():
		for j in range(i + 1, cands.size()):
			var a: Rect2i = cands[i]["rect"]
			var r: Rect2i = cands[j]["rect"]
			var dx := absf(contact(r).x - contact(a).x)
			var apart := r.position.x >= a.end.x or r.end.x <= a.position.x
			var rise := absf(r.end.y - a.end.y)
			if apart and dx >= STANCE.x * h and dx <= STANCE.y * h and rise <= PARTNER_RISE * h and mini(a.end.y, r.end.y) >= floor_y:
				var score := mini(a.end.y, r.end.y) - 0.5 * rise
				if score > best:
					best = score
					feet = [a, r]
	if feet.is_empty() and not cands.is_empty():
		feet.append(cands[0]["rect"])
	feet.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.position.x < b.position.x)
	var contacts: Array[Vector2] = []
	var lowest := 0
	for f: Rect2i in feet:
		lowest = maxi(lowest, f.end.y)
		var c := contact(f)
		contacts.append(c + Vector2(0, outline_below(img, c)))
	var lifted: Array[bool] = []
	for f: Rect2i in feet:
		lifted.append(f.end.y < lowest - LIFTED * h)
	var body: Array = blobs.filter(func(b: Dictionary) -> bool: return _is_body(b, h))
	var bottom := 0
	for b: Dictionary in body:
		bottom = maxi(bottom, (b["rect"] as Rect2i).end.y)
	var low_x := 0.0
	var low_n := 0
	for b: Dictionary in body:
		for i: int in b["pixels"]:
			if i / w >= bottom - 0.04 * h:
				low_x += i % w + 0.5
				low_n += 1
	low_x /= maxi(low_n, 1)
	# The outline under the body's lowest row, at its thickest.
	var under := 0
	for b: Dictionary in body:
		if (b["rect"] as Rect2i).end.y == bottom:
			for i: int in b["pixels"]:
				if i / w == bottom - 1:
					under = maxi(under, outline_below(img, Vector2(i % w, bottom)))
	var bottom_line := float(bottom + under)
	var ground := -1.0
	for i in feet.size():
		if not lifted[i]:
			ground = maxf(ground, contacts[i].y)
	if ground < 0.0:
		ground = bottom_line
	var torso := Vector2.ZERO
	var n := 0
	var y0 := ground - TORSO.y * h
	var y1 := ground - TORSO.x * h
	for b: Dictionary in body:
		for i: int in b["pixels"]:
			var y := i / w
			if y >= y0 and y < y1:
				torso += Vector2(i % w + 0.5, y + 0.5)
				n += 1
	return {"box": img.get_used_rect(), "feet": feet, "contacts": contacts, "lifted": lifted, "bottom": bottom_line,
		"bottom_x": low_x, "ground": ground, "torso": torso / maxi(n, 1), "eyes": eyes(img), "head_x": head_x(img)}


## The middle of the widest opaque row in the head band (a share of the
## drawing's height from its top: the head and the ears hanging beside it).
static func head_x(img: Image) -> float:
	var box := img.get_used_rect()
	var best := Vector2(0, box.position.x + box.size.x / 2.0)
	for y in range(box.position.y + int(box.size.y * HEAD_BAND.x), box.position.y + int(box.size.y * HEAD_BAND.y)):
		var lo := -1
		var hi := -1
		for x in range(box.position.x, box.end.x):
			if img.get_pixel(x, y).a > 0.5:
				if lo < 0:
					lo = x
				hi = x
		if lo >= 0 and hi - lo + 1 > best.x:
			best = Vector2(hi - lo + 1, (lo + hi + 1) / 2.0)
	return best.y


## The roots of an animation's frames, from their measures and each frame's
## authored spec (see the top; {} for none, "at" already in the frame's
## pixels): [{root: Vector2, method}] -- `method` "error" (with `error`)
## when the feet do not say and no spec does.
static func roots(ms: Array, h: float, specs: Array = []) -> Array:
	var spec_of := func(i: int) -> Dictionary: return specs[i] if i < specs.size() else {}
	var out: Array = []
	# The animation's two-footed frames say where each foot stands, and where
	# the torso is, from the root.
	var side_off: Array = [[], []]
	var torso_off: Array = []
	for i in ms.size():
		var m: Dictionary = ms[i]
		var c: Array = m["contacts"]
		var both := String((spec_of.call(i) as Dictionary).get("feet", "")) == "both"
		if c.size() == 2 and (both or not (m["lifted"] as Array).has(true)):
			var root := _between(c)
			(side_off[0] as Array).append(root.x - (c[0] as Vector2).x)
			(side_off[1] as Array).append(root.x - (c[1] as Vector2).x)
			torso_off.append(root.x - (m["torso"] as Vector2).x)
	for i in ms.size():
		var m: Dictionary = ms[i]
		var c: Array = m["contacts"]
		var lifted: Array = m["lifted"]
		var spec: Dictionary = spec_of.call(i)
		var foot := String(spec.get("foot", ""))
		if spec.has("at"):
			out.append({"root": Vector2(float(spec["at"][0]), float(spec["at"][1])), "method": "at"})
		elif spec.has("head"):
			out.append({"root": Vector2(float(m["head_x"]) + float(spec["head"]), float(m["ground"])), "method": "head"})
		elif spec.has("box"):
			var box: Rect2i = m["box"]
			out.append({"root": Vector2(box.position.x + box.size.x / 2.0, box.end.y), "method": "box"})
		elif spec.has("torso"):
			if torso_off.is_empty():
				out.append({"root": Vector2.ZERO, "method": "error", "error": "torso: no two-footed frame to measure the torso from"})
			else:
				out.append({"root": Vector2((m["torso"] as Vector2).x + median(torso_off), float(m["bottom"])), "method": "torso"})
		elif foot in ["left", "right", "only"]:
			if c.is_empty():
				out.append({"root": Vector2.ZERO, "method": "error", "error": "foot: no foot found"})
			elif foot == "only":
				out.append({"root": c[c.size() - 1] if c.size() == 1 else _lowest(c), "method": "foot"})
			else:
				var s := 0 if foot == "left" else 1
				# The one foot seen is that foot.
				var seen: Vector2 = c[0] if c.size() == 1 else c[s]
				if (side_off[s] as Array).is_empty():
					out.append({"root": Vector2.ZERO, "method": "error", "error": "foot: no two-footed frame to place it from"})
				else:
					out.append({"root": Vector2(seen.x + median(side_off[s]), seen.y), "method": "planted"})
		elif c.size() == 2 and (String(spec.get("feet", "")) == "both" or not lifted.has(true)):
			out.append({"root": _between(c), "method": "feet"})
		else:
			out.append({"root": Vector2(float(m["bottom_x"]), float(m["bottom"])), "method": "error",
				"error": "%d foot/feet found and no `root` says where it stands" % c.size()})
	return out


## Midway between two contacts, on the nearer (lower) one's line.
static func _between(c: Array) -> Vector2:
	var a: Vector2 = c[0]
	var b: Vector2 = c[1]
	return Vector2((a.x + b.x) / 2.0, maxf(a.y, b.y))


static func _lowest(c: Array) -> Vector2:
	return c[0] if (c[0] as Vector2).y >= (c[1] as Vector2).y else c[1]


static func median(list: Array) -> float:
	if list.is_empty():
		return 0.0
	var l := list.duplicate()
	l.sort()
	return float(l[(l.size() - 1) / 2]) if l.size() % 2 == 1 else (float(l[l.size() / 2 - 1]) + float(l[l.size() / 2])) / 2.0


## The middle of Momo's two eyes -- the two largest solid dark blobs side by
## side (the outline is a thin line, an eye is filled) -- or (-1, -1) when
## they are shut.
static func eyes(img: Image) -> Vector2:
	var pair := eye_pair(img)
	return ((pair[0]["c"] as Vector2) + (pair[1]["c"] as Vector2)) / 2.0 if not pair.is_empty() else Vector2(-1, -1)


## The two eye blobs [{n, size, c}], or [].
static func eye_pair(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var blobs: Array = []
	for start in w * h:
		if seen[start] == 1:
			continue
		var c := img.get_pixel(start % w, start / w)
		if not _dark(c):
			continue
		var lo := Vector2i(w, h)
		var hi := Vector2i(-1, -1)
		var n := 0
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var x := i % w
			var y := i / w
			n += 1
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx := x + d.x
				var yy := y + d.y
				if xx < 0 or yy < 0 or xx >= w or yy >= h:
					continue
				var j := yy * w + xx
				if seen[j] == 0 and _dark(img.get_pixel(xx, yy)):
					seen[j] = 1
					stack.append(j)
		var size := hi - lo + Vector2i.ONE
		var fill := float(n) / float(size.x * size.y)
		var aspect := float(size.y) / float(size.x)
		if n >= 60 and fill > 0.5 and aspect > 0.8 and aspect < 2.2:
			blobs.append({"n": n, "size": size, "c": (Vector2(lo) + Vector2(hi) + Vector2.ONE) / 2.0})
	blobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["n"]) > int(b["n"]))
	for i in blobs.size():
		for j in range(i + 1, mini(blobs.size(), 6)):
			var a: Dictionary = blobs[i]
			var b: Dictionary = blobs[j]
			var dy := absf((a["c"] as Vector2).y - (b["c"] as Vector2).y)
			var dx := absf((a["c"] as Vector2).x - (b["c"] as Vector2).x)
			var ha := float((a["size"] as Vector2i).y)
			var hb := float((b["size"] as Vector2i).y)
			if dy < maxf(ha, hb) * 1.2 and dx > maxf(ha, hb) * 0.7 and absf(ha - hb) < maxf(ha, hb) * 0.4:
				return [a, b]
	return []


static func _dark(c: Color) -> bool:
	return c.a > 0.5 and c.get_luminance() < 0.22
